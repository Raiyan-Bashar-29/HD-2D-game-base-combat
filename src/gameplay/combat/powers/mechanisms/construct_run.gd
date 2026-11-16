class_name ConstructRun
extends PowerExecutor
## Runs a construct (C8.14a) on one fighter. Its settings are a `ConstructMechanism`; read its
## header for what the fields mean.
##
## IN PLAIN WORDS: a use in the field adds a solid `ArenaThing` beside the user's body, placed and
## turned before it enters the tree (a moved body is only seen by the physics after a step). It
## keeps the list of those standing and their clocks; `tick` runs the clocks and the upkeep;
## a broken one leaves the list as it is freed.
##
## OWNS: the constructs this power has standing, their clocks and the upkeep owed.
## MUST NOT: decide what a hit on one does (`ArenaThing` does), or name a character.

static var _made: int = 0

var _up: Array[ArenaThing] = []
var _left: Array[float] = []
var _owed: float = 0.0


func use(user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	var body: Node3D = user.get_parent() as Node3D
	if not user.real_time or body == null or not body.is_inside_tree():
		return
	var build: ConstructMechanism = mechanism as ConstructMechanism
	var facing: Vector3 = BarrageRun.facing_of(body)
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var wall := ArenaThing.new()
	_made += 1
	wall.name = "Construct%d" % _made
	wall.thing_id = StringName("construct/%s/%d" % [user.combatant_id, _made])
	wall.hp = build.hp
	wall.size = build.size
	wall.solid = true
	var parent: Node3D = body.get_parent() as Node3D
	var spot: Vector3 = body.global_position + facing * build.distance
	wall.position = parent.to_local(spot) if parent != null else spot
	wall.rotation.y = atan2(-facing.x, -facing.z)
	body.get_parent().add_child(wall)
	wall.tree_exiting.connect(_gone.bind(wall))
	_up.append(wall)
	_left.append(build.lifetime if build.lifetime > 0.0 else INF)
	while build.cap > 0 and _up.size() > build.cap:
		_take_down(0)
	_listen(true)


## Seconds passed: each clock runs down, and the upkeep is paid in whole points.
func tick(amount: float) -> void:
	for index: int in range(_up.size() - 1, -1, -1):
		_left[index] -= amount
		if _left[index] <= 0.0:
			_take_down(index)
	var build: ConstructMechanism = mechanism as ConstructMechanism
	if _up.is_empty() or build.upkeep_pool == &"" or build.upkeep <= 0.0:
		return
	_owed += build.upkeep * amount
	var due: int = floori(_owed)
	if due <= 0:
		return
	_owed -= due
	var vitals: Vitals = Vitals.of(holder.get_parent()) if is_instance_valid(holder) else null
	if vitals == null or vitals.current(build.upkeep_pool) < due:
		_all_down()
	else:
		vitals.change(build.upkeep_pool, -due)


## The kit came off: everything it built comes down.
func end() -> void:
	_all_down()


## How many it has standing: for a HUD, or a test.
func standing() -> int:
	return _up.size()


func _take_down(index: int) -> void:
	var wall: ArenaThing = _up[index]
	_up.remove_at(index)
	_left.remove_at(index)
	if is_instance_valid(wall):
		wall.queue_free()
	if _up.is_empty():
		_listen(false)


func _all_down() -> void:
	for index: int in range(_up.size() - 1, -1, -1):
		_take_down(index)
	_owed = 0.0


func _gone(wall: ArenaThing) -> void:
	var index: int = _up.find(wall)
	if index >= 0:
		_up.remove_at(index)
		_left.remove_at(index)
		if _up.is_empty():
			_listen(false)


func _listen(on: bool) -> void:
	var listening: bool = Events.combatant_defeated.is_connected(_on_defeated)
	if on and not listening:
		Events.combatant_defeated.connect(_on_defeated)
		Events.area_unloading.connect(_on_area_left)
	elif not on and listening:
		Events.combatant_defeated.disconnect(_on_defeated)
		Events.area_unloading.disconnect(_on_area_left)


func _on_area_left(_area_id: StringName) -> void:
	_all_down()


func _on_defeated(who: StringName) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me != null and who == me.combatant_id:
		_all_down()
