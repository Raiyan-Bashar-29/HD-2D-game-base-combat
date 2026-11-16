extends TestCase
## The clone (C6.13a). Its shape and problems; a use puts one ghost out for the user; the ghost
## stands where the user stood `delay` ago; a move the user starts is played that much later, at
## `power_fraction` of its power, and hurts a foe; a second use replaces it; its lifetime, the kit
## coming off and the user falling each send it away.
##
## OWNS: assertions about `CloneMechanism`, `CloneRun` and `CloneGhost`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics: `step` is called by
## hand.

const DT: float = 0.1

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _clone := CloneMechanism.new()
var _call: Power


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_clone.delay = 0.5
	_clone.lifetime = 3.0
	_clone.power_fraction = 0.5
	_call = Power.new()
	_call.power_id = &"power/fixture_clone_call"
	_call.name_key = "fixture.power"
	_call.mechanism = _clone
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_clone"
	kit.powers = [_call]
	var bad := CloneMechanism.new()
	bad.lifetime = 0.0
	equal("a clone's kind, its executor, and no lifetime is a problem",
		[_clone.kind(), PowerMechanisms.make(_clone) is CloneRun, bad.problems("x").is_empty()],
		[&"clone", true, false])
	var me: Combatant = _fighter(&"fixture_cloner", &"side_a", Vector3.ZERO, kit)
	var foe: Combatant = _fighter(&"fixture_clone_foe", &"side_b", Vector3(3, 0, -1), null)
	_replay(me, foe)
	_leaving(me)
	_world.free()
	Flags.clear_all()


func _replay(me: Combatant, foe: Combatant) -> void:
	PowerUse.use(me, _call, [], _rng, 12.0)
	var ghosts: Array[CloneGhost] = _ghosts()
	equal("a use puts one ghost out, striking for the user", [ghosts.size(), ghosts[0].attacker == me], [1, true])
	var ghost: CloneGhost = ghosts[0]
	var body: Node3D = me.get_parent() as Node3D
	ghost.step(DT)
	body.global_position = Vector3(3, 0, 0)
	for _i: int in 5:
		ghost.step(DT)
	var early: Vector3 = ghost.global_position
	ghost.step(DT)
	equal("the ghost stands where the user stood half a second ago",
		[early.is_equal_approx(Vector3.ZERO), ghost.global_position.is_equal_approx(Vector3(3, 0, 0))], [true, true])
	var run: CloneRun = PowerSet.of(body).executor(_call.power_id) as CloneRun
	run.moved(_jab())
	var hurtbox: Hurtbox = _hurtbox(foe.get_parent())
	for _i: int in 4:
		ghost.step(DT)
	equal("before its delay the move has not started", ghost.timeline.busy(), false)
	for _i: int in 3:
		ghost.step(DT)
	var struck: bool = ghost.strike(hurtbox)
	equal("after it the ghost plays it at half power and hurts the foe",
		[ghost.timeline.move.power, struck, Vitals.of(foe.get_parent()).current(&"hp") < 100], [5.0, true, true])
	PowerUse.use(me, _call, [], _rng, 12.0)
	var again: Array[CloneGhost] = _ghosts()
	equal("a second use replaces the first", [again.size(), again[0] != ghost], [1, true])
	for _i: int in 31:
		again[0].step(DT)
	equal("its lifetime sends it away", _ghosts().size(), 0)


func _leaving(me: Combatant) -> void:
	PowerUse.use(me, _call, [], _rng, 12.0)
	PowerSet.of(me.get_parent()).executor(_call.power_id).end()
	var after_end: int = _ghosts().size()
	PowerUse.use(me, _call, [], _rng, 12.0)
	Events.combatant_defeated.emit(me.combatant_id)
	equal("the kit coming off and the user falling send it away", [after_end, _ghosts().size()], [0, 0])


func _jab() -> ActionMove:
	var jab := ActionMove.new()
	jab.id = &"move/fixture_clone_jab"
	jab.power = 10.0
	jab.startup = 0.05
	jab.active = 0.3
	jab.recovery = 0.1
	jab.hitbox_offset = Vector3(0, 1, -1)
	jab.hitbox_size = Vector3(1.5, 2, 1.5)
	return jab


func _ghosts() -> Array[CloneGhost]:
	var out: Array[CloneGhost] = []
	for node: Node in _world.get_tree().get_nodes_in_group(CloneGhost.GROUP):
		if not node.is_queued_for_deletion():
			out.append(node as CloneGhost)
	return out


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	var hurtbox := Hurtbox.new()
	hurtbox.timeline = MoveTimeline.new()
	actor.add_child(hurtbox)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
