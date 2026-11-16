extends TestCase
## Steal and a random power (C8.13c). A steal moves the target's statuses carrying its tag to the
## user, no more than `most`, and leaves the others; a random power runs one of its list each
## use, and a lasting pick is ended by the kit coming off.
##
## OWNS: assertions about `StealMechanism`, `StealRun`, `RandomMechanism` and `RandomRun`.
## MUST NOT: name a game's kits, powers or characters.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	var world := Node3D.new()
	attach(world)
	var steal := StealMechanism.new()
	steal.most = 1
	var take: Power = _power(&"power/fixture_steal", steal)
	var clone := CloneMechanism.new()
	clone.lifetime = 5.0
	var random := RandomMechanism.new()
	random.powers = [_power(&"power/fixture_random_clone", clone)]
	var roll: Power = _power(&"power/fixture_random", random)
	var me: Combatant = _fighter(world, &"fixture_thief", [take, roll])
	var foe: Combatant = _fighter(world, &"fixture_mark", [])
	var theirs: StatusSet = StatusSet.of(foe.get_parent())
	theirs.apply(_status(&"status/fixture_boon_a", [&"buff"]), _rng)
	theirs.apply(_status(&"status/fixture_boon_b", [&"buff"]), _rng)
	theirs.apply(_status(&"status/fixture_bane", [&"debuff"]), _rng)
	PowerUse.use(me, take, [foe], _rng)
	var mine: StatusSet = StatusSet.of(me.get_parent())
	var held: int = mine.stacks(&"status/fixture_boon_a") + mine.stacks(&"status/fixture_boon_b")
	equal("a steal of at most one takes one buff and leaves the other and the debuff",
		[held, theirs.held().size(), theirs.stacks(&"status/fixture_bane")], [1, 2, 1])
	equal("a bad steal or random is a problem",
		[StealMechanism.new().problems("x").is_empty(), RandomMechanism.new().problems("x").is_empty()], [true, false])
	PowerUse.use(me, roll, [], _rng)
	var run: RandomRun = PowerSet.of(me.get_parent()).executor(roll.power_id) as RandomRun
	equal("a random power runs its pick: the clone's ghost is out",
		[run.picked() == random.powers[0], world.get_tree().get_nodes_in_group(CloneGhost.GROUP).size()], [true, 1])
	run.end()
	var left: int = 0
	for node: Node in world.get_tree().get_nodes_in_group(CloneGhost.GROUP):
		if not node.is_queued_for_deletion():
			left += 1
	equal("the kit coming off ends a lasting pick", left, 0)
	world.free()
	Flags.clear_all()


func _status(id: StringName, tags: Array[StringName]) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = id
	effect.unit = StatusEffect.Unit.SECONDS
	effect.duration = 10.0
	effect.tags = tags
	return effect


func _power(id: StringName, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _fighter(world: Node3D, id: StringName, powers: Array[Power]) -> Combatant:
	var kit := PowerKit.new()
	kit.kit_id = StringName("kit/" + String(id))
	kit.powers = powers
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0}
	actor.add_child(fighter)
	var powers_node := PowerSet.new()
	powers_node.set_physics_process(false)
	actor.add_child(powers_node)
	world.add_child(actor)
	powers_node.equip(kit)
	return fighter
