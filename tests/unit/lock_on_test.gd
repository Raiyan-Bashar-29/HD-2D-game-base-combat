extends TestCase
## Lock-on (C3.5): it picks the nearest hostile in reach and in front, skipping allies, the
## fallen, anything behind and anything too far; pressing again lets go; cycling walks through
## every hostile in reach, nearest first, wrapping round; a target that falls or walks past the
## leash is dropped; every change is announced; and a fighter that holds a lock faces it.
##
## OWNS: assertions about `LockOn` and the facing it gives `ActionFighter`.
## MUST NOT: name a game's fighters, or ask the physics engine anything: targets are placed
## fixture nodes, found through `Hurtbox.GROUP`.

var _actors: Array[Node] = []
var _changes: Array[StringName] = []


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	Events.lock_on_changed.connect(_on_changed)
	var me := _actor(&"fixture_me", &"side_a", Vector3.ZERO)
	var lock := LockOn.new()
	me.add_child(lock)
	var near := _actor(&"fixture_near", &"side_b", Vector3(0, 0, -3))
	var far := _actor(&"fixture_far", &"side_b", Vector3(1, 0, -6))
	_actor(&"fixture_behind", &"side_b", Vector3(0, 0, 2))
	_actor(&"fixture_friend", &"side_a", Vector3(0, 0, -1))
	_actor(&"fixture_distant", &"side_b", Vector3(0, 0, -40))
	_picking(lock, near, far)
	_cycling(lock)
	_dropping(lock, near, far)
	_facing(me, lock, far)
	Events.lock_on_changed.disconnect(_on_changed)
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _actor(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 10.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _id(lock: LockOn) -> StringName:
	return lock.target.fighter().combatant_id if lock.target != null else &""


func _picking(lock: LockOn, near: Node3D, far: Node3D) -> void:
	equal("in reach and hostile: the two ahead and the one behind, nearest first",
		lock.candidates().map(func(h: Hurtbox) -> StringName: return h.fighter().combatant_id),
		[&"fixture_behind", &"fixture_near", &"fixture_far"])
	lock.toggle(Vector3.FORWARD)
	equal("lock-on picks the nearest hostile IN FRONT, not the nearer one behind", _id(lock), &"fixture_near")
	equal("and says so", _changes, [&"fixture_near"])
	lock.toggle(Vector3.FORWARD)
	equal("pressing again lets go", [lock.target, _changes.back()], [null, &""])
	lock.toggle(Vector3.LEFT)
	equal("with nothing in front, nothing is locked", lock.target, null)


func _cycling(lock: LockOn) -> void:
	lock.cycle()
	equal("cycling with nothing held locks the nearest, behind or not", _id(lock), &"fixture_behind")
	lock.cycle()
	lock.cycle()
	equal("then walks outward", _id(lock), &"fixture_far")
	lock.cycle()
	equal("and wraps round", _id(lock), &"fixture_behind")


func _dropping(lock: LockOn, near: Node3D, far: Node3D) -> void:
	lock.cycle()
	Vitals.of(near).change(&"hp", -10)
	lock.refresh()
	equal("a target that falls is dropped", [lock.target, _changes.back()], [null, &""])
	lock.toggle(Vector3.FORWARD)
	equal("lock-on skips the fallen", _id(lock), &"fixture_far")
	far.position = Vector3(0, 0, -12)
	lock.refresh()
	equal("past reach but inside the leash, it holds on", _id(lock), &"fixture_far")
	far.position = Vector3(0, 0, -20)
	lock.refresh()
	equal("past the leash, it lets go", lock.target, null)
	far.position = Vector3(1, 0, 0)


func _facing(me: Node3D, lock: LockOn, far: Node3D) -> void:
	var fighter := ActionFighter.new()
	me.add_child(fighter)
	lock.cycle()
	fighter.drive(0.02, false, false)
	equal("a fighter that holds a lock faces its target", fighter.facing, Vector3.RIGHT)


func _on_changed(_who: StringName, target: StringName) -> void:
	_changes.append(target)
