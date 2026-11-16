class_name DoorsRun
extends PowerExecutor
## Runs linked doors (C8.14c) on one fighter. Its settings are a `DoorsMechanism`; read its
## header for what the fields mean.
##
## IN PLAIN WORDS: a use in the field places a `LinkedDoor` in front of the user, turned the way it
## faces and placed before it enters the tree, and links the newest two. `tick` runs their clock.
## Who may pass is the user's side (`Combatant.can_target` with ALLY), or anyone.
##
## OWNS: the doors this power has standing and their clock.
## MUST NOT: move anyone itself (a door does), or name a character.

var _doors: Array[LinkedDoor] = []
var _left: float = 0.0


func use(user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	var body: Node3D = user.get_parent() as Node3D
	if not user.real_time or body == null or not body.is_inside_tree():
		return
	var doors: DoorsMechanism = mechanism as DoorsMechanism
	var facing: Vector3 = BarrageRun.facing_of(body)
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var door := LinkedDoor.new()
	door.exit = doors.exit
	door.shape(doors.radius)
	door.may_pass = _may_pass
	var parent: Node3D = body.get_parent() as Node3D
	var spot: Vector3 = body.global_position + facing * doors.ahead
	door.position = parent.to_local(spot) if parent != null else spot
	door.rotation.y = atan2(-facing.x, -facing.z)
	body.get_parent().add_child(door)
	_doors.append(door)
	while _doors.size() > 2:
		var old: LinkedDoor = _doors.pop_front() as LinkedDoor
		if is_instance_valid(old):
			old.queue_free()
	if _doors.size() == 2:
		_doors[0].other = _doors[1]
		_doors[1].other = _doors[0]
	_left = doors.lifetime if doors.lifetime > 0.0 else INF
	if not Events.combatant_defeated.is_connected(_on_defeated):
		Events.combatant_defeated.connect(_on_defeated)
		Events.area_unloading.connect(_on_area_left)


## Seconds passed: at the end of their time the doors go.
func tick(amount: float) -> void:
	if _doors.is_empty():
		return
	_left -= amount
	if _left <= 0.0:
		_close()


## The kit came off: the doors go.
func end() -> void:
	_close()


## The doors standing, oldest first: for a test or a map marker.
func doors() -> Array[LinkedDoor]:
	return _doors.duplicate()


func _may_pass(body: Node3D) -> bool:
	if (mechanism as DoorsMechanism).anyone:
		return true
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	var them: Combatant = Combatant.of(body)
	return me != null and them != null and (them == me or me.can_target(them, FactionTable.Target.ALLY))


func _close() -> void:
	for door: LinkedDoor in _doors:
		if is_instance_valid(door):
			door.queue_free()
	_doors.clear()


func _on_area_left(_area_id: StringName) -> void:
	_close()


func _on_defeated(who: StringName) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me != null and who == me.combatant_id:
		_close()
