extends TestCase
## A copy (C8.13b). The copier remembers the last power another fighter used; a use lends it that
## power, usable as its own, for `lasts`; then it goes. A `suffered_only` copier remembers only a
## power used on it. Its own uses and a copy power are never remembered.
##
## OWNS: assertions about `CopyMechanism`, `CopyRun` and `Events.power_used`.
## MUST NOT: name a game's kits, powers or characters.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	var world := Node3D.new()
	attach(world)
	var copy: Power = _power(&"power/fixture_copy", _copy(false))
	var picky: Power = _power(&"power/fixture_copy_picky", _copy(true))
	var trick: Power = _power(&"power/fixture_copy_trick", RefreshMechanism.new())
	var copier: Combatant = _fighter(world, &"fixture_copier", [copy])
	var sufferer: Combatant = _fighter(world, &"fixture_sufferer", [picky])
	var other: Combatant = _fighter(world, &"fixture_trickster", [trick])
	var run: CopyRun = _run(copier, copy)
	var picky_run: CopyRun = _run(sufferer, picky)
	run.tick(0.1)
	picky_run.tick(0.1)
	PowerUse.use(copier, copy, [], _rng)
	equal("nothing seen, a use lends nothing; its own use is not remembered",
		[PowerSet.of(copier.get_parent()).has(trick), run.seen()], [false, null])
	PowerUse.use(other, trick, [], _rng)
	equal("another's power is remembered by a copier, not by one that copies only what it suffers",
		[run.seen() == trick, picky_run.seen()], [true, null])
	PowerSet.of(copier.get_parent()).start_cooldown(copy)
	PowerSet.of(copier.get_parent()).cut_cooldowns(999.0, 1.0)
	PowerUse.use(copier, copy, [], _rng)
	equal("a use lends it, and it is used as the copier's own",
		[PowerSet.of(copier.get_parent()).has(trick), PowerUse.use(copier, trick, [], _rng)], [true, true])
	run.tick(11.0)
	equal("after `lasts` it is gone", PowerSet.of(copier.get_parent()).has(trick), false)
	PowerSet.of(other.get_parent()).cut_cooldowns(999.0, 1.0)
	PowerUse.use(other, trick, [sufferer], _rng)
	equal("a power used on it is remembered by the one that copies what it suffers", picky_run.seen() == trick, true)
	run.end()
	picky_run.end()
	world.free()
	Flags.clear_all()


func _copy(suffered_only: bool) -> CopyMechanism:
	var made := CopyMechanism.new()
	made.lasts = 10.0
	made.suffered_only = suffered_only
	return made


func _power(id: StringName, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _run(who: Combatant, power: Power) -> CopyRun:
	return PowerSet.of(who.get_parent()).executor(power.power_id) as CopyRun


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
	var set := PowerSet.new()
	set.set_physics_process(false)
	actor.add_child(set)
	world.add_child(actor)
	set.equip(kit)
	return fighter
