extends TestCase
## The hybrid's defence prompt (C8.20): `DefenceWatch` warns of a foe's swing winding up in reach
## or a foe's shot about to arrive, once per threat, as EVADE, or BLOCK for a timed-block guard;
## `DefenceCue` shows the words and clears.
##
## OWNS: assertions about `DefenceWatch` and `DefenceCue`.
## MUST NOT: name a game's fighters, moves or kits, or wait for frames.

var _actors: Array[Node] = []
var _kinds: Array[StringName] = []


func run() -> void:
	plan(6)
	Events.defence_prompt.connect(_on_prompt)
	var me: Node3D = _actor(&"fixture_me", &"side_a", Vector3.ZERO)
	var watch := DefenceWatch.new()
	me.add_child(watch)
	var foe: Node3D = _actor(&"fixture_foe", &"side_b", Vector3(0, 0, -1.5))
	var clock: MoveTimeline = _swinging(foe)
	watch.watch()
	watch.watch()
	equal("a foe winding up in reach is one EVADE, however many frames it lasts", [watch.shown, _kinds], [1, [&"evade"]])
	clock.step(0.25)
	watch.watch()
	equal("once the swing is live nothing new is asked, and the prompt clears", [watch.shown, _kinds.back()], [1, &""])
	foe.position = Vector3(0, 0, -6)
	clock.start(clock.move)
	watch.watch()
	equal("a foe winding up out of reach is no threat", watch.shown, 1)
	var shot: Projectile = _shot(foe, Vector3(0, 0, -2), Vector3.BACK)
	watch.watch()
	equal("a shot heading in and close is one prompt", watch.shown, 2)
	shot.direction = Vector3.FORWARD
	_actor_shots_clear(watch)
	watch.watch()
	equal("a shot flying away is none", watch.shown, 2)
	_guarded(me)
	foe.position = Vector3(0, 0, -1.5)
	clock.start(clock.move)
	watch.watch()
	var cue := DefenceCue.new()
	attach(cue)
	cue.show_prompt(&"block", 0.1)
	var shown: Array = [cue.visible, cue.text]
	cue.show_prompt(&"", 0.0)
	equal("a player with a timed-block guard is asked to BLOCK; the cue shows it and clears",
		[_kinds.back(), shown, cue.visible], [&"block", [true, tr("ui.combat.defence.block")], false])
	Events.defence_prompt.disconnect(_on_prompt)
	cue.free()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _on_prompt(kind: StringName, _seconds: float) -> void:
	_kinds.append(kind)


# Lets the watch forget the shot it already warned of, as it does when threats end.
func _actor_shots_clear(watch: DefenceWatch) -> void:
	for node: Node in watch.get_tree().get_nodes_in_group(Projectile.GROUP):
		(node as Projectile).position = Vector3(0, 0, -50)
	watch.watch()
	for node: Node in watch.get_tree().get_nodes_in_group(Projectile.GROUP):
		(node as Projectile).position = Vector3(0, 0, -2)


func _actor(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.real_time = true
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _swinging(foe: Node3D) -> MoveTimeline:
	var swing := ActionMove.new()
	swing.startup = 0.2
	swing.active = 0.1
	swing.recovery = 0.2
	swing.hitbox_offset = Vector3(0, 0, -1)
	swing.hitbox_size = Vector3.ONE
	var clock := MoveTimeline.new()
	clock.start(swing)
	clock.step(0.05)
	for child: Node in foe.get_children():
		if child is Hurtbox:
			(child as Hurtbox).timeline = clock
	return clock


func _shot(foe: Node3D, at: Vector3, way: Vector3) -> Projectile:
	var shot := Projectile.new()
	shot.attacker = Combatant.of(foe)
	shot.speed = 10.0
	shot.direction = way
	shot.position = at
	shot.set_physics_process(false)
	attach(shot)
	_actors.append(shot)
	return shot


func _guarded(me: Node3D) -> void:
	var guard := BarrierMechanism.new()
	guard.mode = BarrierMechanism.Mode.TIMED_BLOCK
	var power := Power.new()
	power.power_id = &"power/fixture_guard"
	power.mechanism = guard
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_guard"
	kit.powers = [power]
	var powers := PowerSet.new()
	me.add_child(powers)
	powers.equip(kit)
