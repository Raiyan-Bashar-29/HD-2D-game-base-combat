class_name SummonRun
extends PowerExecutor
## Runs a summon (C8.10a) on one fighter. Its settings are a `SummonMechanism`; read its header
## for what the fields mean.
##
## IN PLAIN WORDS: in the field, using the power makes one `OwnedFighter` per entry, beside the
## user and never past a wall, as a sibling of the user's body (so leaving the area takes them
## with it). It keeps the list of those still out and, for each, the seconds left. While any is
## out the user holds `owner_status`, and this listens for the user falling. One leaves when:
## - its seconds run out (`tick`);
## - a use goes over `cap` (the oldest goes);
## - the user falls (all go);
## - the kit comes off (`end`, all go);
## - it is freed by anything else: it fell and lingered, or the area was left.
## In a battle a use makes nobody yet (C8.10c).
##
## OWNS: the list of fighters this power has out, and their clocks.
## MUST NOT: steer a fighter (its brain does), or name a character.

const SCENE: PackedScene = preload("res://scenes/objects/owned_fighter.tscn")

static var _made: int = 0

var _out: Array[OwnedFighter] = []
var _left: Array[float] = []


func use(user: Combatant, _targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var summon: SummonMechanism = mechanism as SummonMechanism
	var body: Node3D = user.get_parent() as Node3D
	if not user.real_time or body == null or not body.is_inside_tree() or not body.get_parent() is Node3D:
		return
	var count: int = mini(summon.fighters.size(), summon.brains.size())
	for index: int in count:
		_bring(body, summon, index, count)
	while summon.cap > 0 and _out.size() > summon.cap:
		_send(0)
	_settle(rng)


## Time passed: in the field, seconds. Each fighter with a lifetime loses `amount`.
func tick(amount: float) -> void:
	for index: int in range(_out.size() - 1, -1, -1):
		_left[index] -= amount
		if _left[index] <= 0.0:
			_send(index)


## The kit came off: everyone it has out leaves.
func end() -> void:
	_send_all()


func _bring(body: Node3D, summon: SummonMechanism, index: int, count: int) -> void:
	var one: OwnedFighter = SCENE.instantiate() as OwnedFighter
	one.fighter = summon.fighters[index]
	one.brain = summon.brains[index]
	one.owner_body = body
	one.power_id = power.power_id if power != null else &""
	_made += 1
	one.name = "Owned%d" % _made
	var area: Node3D = body.get_parent() as Node3D
	one.position = area.to_local(_spot(body, summon.spread, index, count))
	area.add_child(one)
	one.tree_exiting.connect(_gone.bind(one))
	_out.append(one)
	_left.append(summon.lifetime if summon.lifetime > 0.0 else INF)


# Where the `index`th of `count` appears: in a fan behind and beside the user, `spread` away,
# stopped short of any wall.
static func _spot(body: Node3D, spread: float, index: int, count: int) -> Vector3:
	var facing: Vector3 = BarrageRun.facing_of(body)
	var angle: float = PI * (float(index) + 1.0) / (float(count) + 1.0)
	var way: Vector3 = facing.rotated(Vector3.UP, PI * 0.5 + angle)
	var lift: Vector3 = Vector3.UP * CombatSight.EYE
	var from: Vector3 = body.global_position + lift
	return CombatSight.short_of(body, from, from + way * spread) - lift


# Sends the `index`th away now.
func _send(index: int) -> void:
	var one: OwnedFighter = _out[index]
	_out.remove_at(index)
	_left.remove_at(index)
	# Its `tree_exiting` still reaches `_gone` later, which then finds nothing to forget.
	if is_instance_valid(one):
		one.dismiss()
	_settle(null)


func _send_all() -> void:
	for index: int in range(_out.size() - 1, -1, -1):
		_send(index)


# Freed by anything else (fell and lingered, the area was left): forget it.
func _gone(one: OwnedFighter) -> void:
	var index: int = _out.find(one)
	if index >= 0:
		_out.remove_at(index)
		_left.remove_at(index)
		_settle(null)


# The user holds `owner_status` exactly while any is out, and is watched for falling meanwhile.
func _settle(rng: RandomNumberGenerator) -> void:
	var listening: bool = Events.combatant_defeated.is_connected(_on_defeated)
	if _out.is_empty() and listening:
		Events.combatant_defeated.disconnect(_on_defeated)
	elif not _out.is_empty() and not listening:
		Events.combatant_defeated.connect(_on_defeated)
	var status: StatusEffect = (mechanism as SummonMechanism).owner_status
	var body: Node = holder.get_parent() if is_instance_valid(holder) else null
	var statuses: StatusSet = StatusSet.of(body) if body != null else null
	if status == null or statuses == null:
		return
	var held: bool = statuses.stacks(status.id) > 0
	if _out.is_empty() and held:
		statuses.cure(status.id)
	elif not _out.is_empty() and not held:
		statuses.apply(status, rng)


func _on_defeated(who: StringName) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me != null and who == me.combatant_id:
		_send_all()
