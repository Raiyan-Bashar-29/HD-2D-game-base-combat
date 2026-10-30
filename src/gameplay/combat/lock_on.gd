class_name LockOn
extends Node
## Lock-on for a real-time fighter (C3.5). Put it under the body, beside its `Combatant`.
##
## IN PLAIN WORDS: pressing lock-on picks the nearest hostile fighter within `reach` metres and
## in front (within `cone` degrees either side of where the fighter faces). Pressing it again
## lets go. Cycling moves to the next hostile in reach, nearest first, wrapping round, and may
## pick one behind. A target that falls, or that gets further than `reach * leash` away, is
## dropped on the next `refresh`. Every change is announced by `Events.lock_on_changed`.
##
## While locked, `ActionFighter` turns the fighter to face the target, so every swing aims at it.
##
## TARGETS ARE FOUND THROUGH THE `Hurtbox.GROUP` GROUP, not the physics engine: a lock-on is a
## choice among fighters, not a collision, and a test can place fixture nodes and ask.
##
## OWNS: which fighter is locked, and when to let go.
## MUST NOT: turn or move the body (the fighter does), or decide what counts as hostile (the
## faction table, through `Combatant.can_target`).

## Metres within which a target may be picked.
var reach: float = 10.0
## How much further than `reach` a held target may go before it is dropped. Above 1, so a target
## stepping back and forth across the edge does not flicker.
var leash: float = 1.3
## Degrees either side of the fighter's facing that count as "in front", for the first pick.
var cone: float = 70.0

var target: Hurtbox


func _physics_process(_delta: float) -> void:
	var fighter: ActionFighter = _fighter()
	var facing: Vector3 = fighter.facing if fighter != null else Vector3.FORWARD
	if Input.is_action_just_pressed(CombatActions.LOCK_ON):
		toggle(facing)
	elif Input.is_action_just_pressed(CombatActions.LOCK_CYCLE):
		cycle()
	refresh()


## Locks the nearest hostile in front when nothing is held; lets go when something is.
func toggle(facing: Vector3) -> void:
	if target != null:
		_hold(null)
		return
	var best: Hurtbox = null
	var best_distance: float = INF
	var flat_facing: Vector3 = _flat(facing).normalized()
	for hurtbox: Hurtbox in candidates():
		var to: Vector3 = _flat(hurtbox.global_position - _origin())
		var inside: bool = to.length() < 0.001 or flat_facing.dot(to.normalized()) >= cos(deg_to_rad(cone))
		if inside and to.length() < best_distance:
			best = hurtbox
			best_distance = to.length()
	_hold(best)


## Moves to the next hostile in reach, nearest first, wrapping round. Locks the nearest when
## nothing is held. A lone target stays locked.
func cycle() -> void:
	var found: Array[Hurtbox] = candidates()
	if found.is_empty():
		return
	var at: int = found.find(target)
	_hold(found[(at + 1) % found.size()])


## Drops a target that has fallen, left the tree, or gone beyond the leash.
func refresh() -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_inside_tree() or not _standing(target) \
			or _flat(target.global_position - _origin()).length() > reach * leash:
		_hold(null)


## The hostile, standing hurtboxes within `reach`, nearest first.
func candidates() -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	var me: Combatant = Combatant.of(get_parent())
	if me == null or not is_inside_tree():
		return found
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox == null or not me.can_target(hurtbox.fighter(), FactionTable.Target.ENEMY):
			continue
		if _standing(hurtbox) and _flat(hurtbox.global_position - _origin()).length() <= reach:
			found.append(hurtbox)
	var origin: Vector3 = _origin()
	found.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return found


## The flat direction from the fighter to its target, or zero when nothing is locked.
func direction() -> Vector3:
	if target == null:
		return Vector3.ZERO
	return _flat(target.global_position - _origin()).normalized()


func _hold(next: Hurtbox) -> void:
	if next == target:
		return
	target = next
	var me: Combatant = Combatant.of(get_parent())
	var them: StringName = next.fighter().combatant_id if next != null and next.fighter() != null else &""
	Events.lock_on_changed.emit(me.combatant_id if me != null else &"", them)


func _origin() -> Vector3:
	var body: Node3D = get_parent() as Node3D
	return body.global_position if body != null else Vector3.ZERO


func _fighter() -> ActionFighter:
	for child: Node in get_parent().get_children():
		if child is ActionFighter:
			return child as ActionFighter
	return null


static func _standing(hurtbox: Hurtbox) -> bool:
	var vitals: Vitals = Vitals.of(hurtbox.get_parent())
	return hurtbox.fighter() != null and (vitals == null or not vitals.is_defeated())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
