extends TestCase
## A rewind (C8.11b). Its shape and problems; in the field a use puts the user's place and hp back
## to `back` seconds ago; a fallen user is not raised; counted in turns (a battle) only the hp
## comes back.
##
## OWNS: assertions about `RewindMechanism` and `RewindRun`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics.

const DT: float = 0.1

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	var bad := RewindMechanism.new()
	bad.back = 0.0
	bad.restore_place = false
	bad.restore_hp = false
	equal("a rewind's kind, its executor, and nothing to put back is a problem",
		[RewindMechanism.new().kind(), PowerMechanisms.make(bad) is RewindRun, bad.problems("x").size()],
		[&"rewind", true, 2])
	var world := Node3D.new()
	attach(world)
	var me: Combatant = _fighter(world, &"fixture_rewinder", true)
	var body: Node3D = me.get_parent() as Node3D
	var run: RewindRun = PowerSet.of(body).executor(&"power/fixture_rewind") as RewindRun
	_steps(run, body, Vector3.ZERO, 100, 10)
	_steps(run, body, Vector3(2, 0, 0), 60, 10)
	_steps(run, body, Vector3(5, 0, 0), 30, 30)
	run.use(me, [], _rng)
	equal("in the field it puts the place and hp back three seconds",
		[body.global_position.is_equal_approx(Vector3(2, 0, 0)), Vitals.of(body).current(&"hp")], [true, 60])
	Vitals.of(body).set_to(&"hp", 0)
	run.use(me, [], _rng)
	equal("a fallen user is not raised", Vitals.of(body).current(&"hp"), 0)
	var turns: Combatant = _fighter(world, &"fixture_rewinder_turns", false)
	var turn_body: Node3D = turns.get_parent() as Node3D
	var turn_run: RewindRun = PowerSet.of(turn_body).executor(&"power/fixture_rewind") as RewindRun
	for hp: int in [100, 50, 20]:
		Vitals.of(turn_body).set_to(&"hp", hp)
		turn_run.tick(1.0)
	turn_body.global_position = Vector3(9, 0, 0)
	turn_run.use(turns, [], _rng)
	equal("counted in turns, the hp comes back and the place stays",
		[Vitals.of(turn_body).current(&"hp"), turn_body.global_position.is_equal_approx(Vector3(9, 0, 0))], [100, true])
	world.free()
	Flags.clear_all()


func _steps(run: RewindRun, body: Node3D, at: Vector3, hp: int, count: int) -> void:
	body.global_position = at
	Vitals.of(body).set_to(&"hp", hp)
	for _i: int in count:
		run.tick(DT)


func _fighter(world: Node3D, id: StringName, real_time: bool) -> Combatant:
	var rewind := RewindMechanism.new()
	rewind.back = 2.0 if not real_time else 3.0
	var power := Power.new()
	power.power_id = &"power/fixture_rewind"
	power.name_key = "fixture.power"
	power.mechanism = rewind
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_rewind"
	kit.powers = [power]
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.real_time = real_time
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	world.add_child(actor)
	(actor.get_child(3) as Node).set_physics_process(false)
	PowerSet.of(actor).equip(kit)
	return fighter
