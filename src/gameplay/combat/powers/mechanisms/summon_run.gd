class_name SummonRun
extends PowerExecutor
## Runs a summon (C8.10a) on one fighter. Its settings are a `SummonMechanism`; read its header
## for what the fields mean.
##
## IN PLAIN WORDS: in the field, using the power makes one `OwnedFighter` per entry, beside the
## user and never past a wall, as a sibling of the user's body. It keeps the list of those still out and, for each, the seconds left. While any is
## out the user holds `owner_status`, and this listens for the user falling and the area
## unloading (the player's body lives above the area, so its siblings outlive it). One leaves when:
## - its seconds run out (`tick`);
## - it has finished `moves_each` moves (`tick`);
## - a use goes over `cap` (the oldest goes);
## - the user falls (all go);
## - the kit comes off (`end`, all go);
## - the area is left (all go);
## - it is freed by anything else: it fell and lingered.
## Those out already join a battle as guests (`BattleSetup`). A use DURING a battle (C8.10e)
## calls one fighter per entry onto the user's side of it (`BattleSetup.summon`); each counts
## down `turns` of the user's own turns (`tick` comes once a turn there), is sent away at 0 or
## once it has fallen, and goes with the battle. `cap`, the owner status, the user falling and
## the kit coming off treat them as they treat the field's.
##
## OWNS: the list of fighters this power has out, and their clocks.
## MUST NOT: steer a fighter (its brain does), or name a character.

const SCENE: PackedScene = preload("res://scenes/objects/owned_fighter.tscn")

static var _made: int = 0

var _out: Array[OwnedFighter] = []
var _left: Array[float] = []
var _called: Array[Combatant] = []
var _turns: Array[float] = []


func use(user: Combatant, _targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var summon: SummonMechanism = mechanism as SummonMechanism
	var count: int = mini(summon.fighters.size(), summon.brains.size())
	if not user.real_time:
		_call(user, summon, count)
		_settle(rng)
		return
	var body: Node3D = user.get_parent() as Node3D
	if body == null or not body.is_inside_tree():
		return
	for index: int in count:
		_bring(body, summon, index, count)
	while summon.cap > 0 and _out.size() > summon.cap:
		_send(0)
	_settle(rng)


## Time passed: in the field, seconds; in a battle, one of the user's turns. Each fighter with a
## lifetime (in a battle, `turns`) loses `amount`.
func tick(amount: float) -> void:
	for index: int in range(_called.size() - 1, -1, -1):
		_turns[index] -= amount
		var one: Combatant = _called[index]
		if _turns[index] <= 0.0 or not is_instance_valid(one) or Vitals.of(one.get_parent()).is_defeated():
			_dismiss(index)
	var limit: int = (mechanism as SummonMechanism).moves_each
	for index: int in range(_out.size() - 1, -1, -1):
		_left[index] -= amount
		var one: OwnedFighter = _out[index]
		var spent: bool = limit > 0 and is_instance_valid(one) and one.moves_done >= limit and one.idle()
		if _left[index] <= 0.0 or spent:
			_send(index)


## The kit came off: everyone it has out leaves.
func end() -> void:
	_send_all()


# A use in a running battle the user is in: one called fighter per entry on its side.
func _call(user: Combatant, summon: SummonMechanism, count: int) -> void:
	var battle: Battle = Battle.running
	if battle == null or not (battle.party.has(user) or battle.enemies.has(user)):
		return
	for index: int in count:
		var def: CombatantDef = summon.fighters[index]
		_made += 1
		var id: StringName = StringName("%s/called%d" % [def.combatant_id, _made])
		var one: Combatant = BattleSetup.summon(battle, def, def.brain, id, user, summon.untouchable)
		one.get_parent().tree_exiting.connect(_forget.bind(one))
		_called.append(one)
		_turns.append(float(summon.turns) if summon.turns > 0 else INF)
	while summon.cap > 0 and _called.size() > summon.cap:
		_dismiss(0)


func _bring(body: Node3D, summon: SummonMechanism, index: int, count: int) -> void:
	var one: OwnedFighter = SCENE.instantiate() as OwnedFighter
	one.fighter = summon.fighters[index]
	one.brain = summon.brains[index]
	one.owner_body = body
	one.power_id = power.power_id if power != null else &""
	one.untouchable = summon.untouchable
	_made += 1
	one.name = "Owned%d" % _made
	var spot: Vector3 = _spot(body, summon.spread, index, count)
	body.get_parent().add_child(one)
	one.global_position = spot
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
	for index: int in range(_called.size() - 1, -1, -1):
		_dismiss(index)


# Sends the `index`th called fighter out of its battle now.
func _dismiss(index: int) -> void:
	var one: Combatant = _called[index]
	_called.remove_at(index)
	_turns.remove_at(index)
	if is_instance_valid(one):
		BattleSetup.dismiss(Battle.running, one)
	_settle(null)


# A called fighter freed with its battle: forget it.
func _forget(one: Combatant) -> void:
	var index: int = _called.find(one)
	if index >= 0:
		_called.remove_at(index)
		_turns.remove_at(index)
		_settle(null)


# Freed by anything else (fell and lingered, the area was left): forget it.
func _gone(one: OwnedFighter) -> void:
	var index: int = _out.find(one)
	if index >= 0:
		_out.remove_at(index)
		_left.remove_at(index)
		_settle(null)


# The user holds `owner_status` exactly while any is out, and is watched for falling meanwhile.
func _settle(rng: RandomNumberGenerator) -> void:
	var none: bool = _out.is_empty() and _called.is_empty()
	var listening: bool = Events.combatant_defeated.is_connected(_on_defeated)
	if none and listening:
		Events.combatant_defeated.disconnect(_on_defeated)
		Events.area_unloading.disconnect(_on_area_left)
	elif not none and not listening:
		Events.combatant_defeated.connect(_on_defeated)
		Events.area_unloading.connect(_on_area_left)
	var status: StatusEffect = (mechanism as SummonMechanism).owner_status
	var body: Node = holder.get_parent() if is_instance_valid(holder) else null
	var statuses: StatusSet = StatusSet.of(body) if body != null else null
	if status == null or statuses == null:
		return
	var held: bool = statuses.stacks(status.id) > 0
	if none and held:
		statuses.cure(status.id)
	elif not none and not held:
		statuses.apply(status, rng)


func _on_area_left(_area_id: StringName) -> void:
	_send_all()


func _on_defeated(who: StringName) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me != null and who == me.combatant_id:
		_send_all()
