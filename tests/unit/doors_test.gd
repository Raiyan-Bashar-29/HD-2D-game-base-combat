extends TestCase
## Linked doors (C8.14c). Two uses place two linked doors; the user (or an ally) stepping into one
## comes out of the other, and is not sent straight back; a foe may not pass; a third use takes
## the oldest away; their lifetime takes them down.
##
## OWNS: assertions about `DoorsMechanism`, `DoorsRun` and `LinkedDoor`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics: `pass_through` is
## called by hand.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	var world := Node3D.new()
	attach(world)
	var doors := DoorsMechanism.new()
	doors.lifetime = 10.0
	var power := Power.new()
	power.power_id = &"power/fixture_doors"
	power.name_key = "fixture.power"
	power.mechanism = doors
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_doors"
	kit.powers = [power]
	var me: Combatant = _fighter(world, &"fixture_door_maker", &"side_a", kit)
	var foe: Combatant = _fighter(world, &"fixture_door_foe", &"side_b", null)
	var body: Node3D = me.get_parent() as Node3D
	var run: DoorsRun = PowerSet.of(body).executor(power.power_id) as DoorsRun
	PowerUse.use(me, power, [], _rng)
	body.global_position = Vector3(5, 0, 0)
	PowerUse.use(me, power, [], _rng)
	var placed: Array[LinkedDoor] = run.doors()
	equal("two uses place two linked doors in front of the user",
		[placed.size(), placed[0].other == placed[1], placed[1].global_position.is_equal_approx(Vector3(5, 0, -1))],
		[2, true, true])
	body.global_position = Vector3.ZERO
	var went: bool = placed[0].pass_through(body)
	equal("the user steps in one and comes out of the other",
		[went, body.global_position.is_equal_approx(Vector3(5, 0, -2))], [true, true])
	equal("it is not sent straight back, and a foe may not pass",
		[placed[1].pass_through(body), placed[0].pass_through(foe.get_parent() as Node3D)], [false, false])
	PowerUse.use(me, power, [], _rng)
	var now: Array[LinkedDoor] = run.doors()
	equal("a third use takes the oldest away", [now.size(), placed[0].is_queued_for_deletion()], [2, true])
	run.tick(11.0)
	equal("their lifetime takes them down", run.doors().size(), 0)
	world.free()
	Flags.clear_all()


func _fighter(world: Node3D, id: StringName, faction: StringName, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0}
	actor.add_child(fighter)
	var powers := PowerSet.new()
	powers.set_physics_process(false)
	actor.add_child(powers)
	world.add_child(actor)
	if kit != null:
		powers.equip(kit)
	return fighter
