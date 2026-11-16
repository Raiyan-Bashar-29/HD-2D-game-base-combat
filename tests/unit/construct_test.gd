extends TestCase
## A construct (C8.14a). A use raises a solid wall in front of the user that stops a ray through
## it, while a ray aimed at the wall itself (ignoring its own body) still reaches it; `cap` keeps
## the newest; the upkeep is paid each second and the wall comes down when it cannot be; its
## lifetime and the user falling bring it down.
##
## OWNS: assertions about `ConstructMechanism`, `ConstructRun` and `ArenaThing.solid`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics: a wall is placed
## before it enters the tree, so the physics space sees it at once.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	var world := Node3D.new()
	attach(world)
	var build := ConstructMechanism.new()
	build.lifetime = 5.0
	build.cap = 1
	var power := Power.new()
	power.power_id = &"power/fixture_construct"
	power.name_key = "fixture.power"
	power.mechanism = build
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_construct"
	kit.powers = [power]
	var me: Combatant = _fighter(world, kit)
	var run: ConstructRun = PowerSet.of(me.get_parent()).executor(power.power_id) as ConstructRun
	PowerUse.use(me, power, [], _rng)
	var wall: ArenaThing = _walls(world)[0]
	var through: Vector3 = CombatSight.wall_between(world, Vector3(0, 1, 0), Vector3(0, 1, -4))
	var at_it: Vector3 = CombatSight.wall_between(world, Vector3(0, 1, 0), wall.global_position + Vector3.UP,
		CombatSight.solids(wall))
	equal("a wall rises in front of the user and stops a line through it, but not one aimed at it",
		[wall.global_position.is_equal_approx(Vector3(0, 0, -1.5)), through.is_finite(), at_it.is_finite()],
		[true, true, false])
	PowerUse.use(me, power, [], _rng)
	equal("a use over the cap takes the oldest down", [run.standing(), wall.is_queued_for_deletion()], [1, true])
	run.tick(6.0)
	equal("its lifetime takes it down", run.standing(), 0)
	build.lifetime = 0.0
	build.upkeep_pool = &"mp"
	build.upkeep = 2.0
	PowerUse.use(me, power, [], _rng)
	run.tick(1.0)
	var paid: int = Vitals.of(me.get_parent()).current(&"mp")
	run.tick(1.0)
	equal("the upkeep is paid each second, and the wall comes down when it cannot be", [paid, run.standing()], [1, 0])
	build.upkeep = 0.0
	PowerUse.use(me, power, [], _rng)
	Events.combatant_defeated.emit(me.combatant_id)
	equal("the user falling takes it down", run.standing(), 0)
	world.free()
	Flags.clear_all()


func _walls(world: Node3D) -> Array[ArenaThing]:
	var out: Array[ArenaThing] = []
	for child: Node in world.get_children():
		if child is ArenaThing and not child.is_queued_for_deletion():
			out.append(child as ArenaThing)
	return out


func _fighter(world: Node3D, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_builder"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 3.0}
	actor.add_child(fighter)
	var powers := PowerSet.new()
	powers.set_physics_process(false)
	actor.add_child(powers)
	world.add_child(actor)
	powers.equip(kit)
	return fighter
