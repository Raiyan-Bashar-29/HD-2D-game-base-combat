extends TestCase
## A made weapon (C8.14b). A use lends its chain, its element and its bonuses; a second use does
## not stack the bonuses; at the end of `lasts` all of it goes and what the user had is back;
## gear worn meanwhile is not undone; a weapon that changes nothing is a problem.
##
## OWNS: assertions about `WieldMechanism` and `WieldRun`.
## MUST NOT: name a game's kits, powers or characters.

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	var world := Node3D.new()
	attach(world)
	var wield := WieldMechanism.new()
	wield.moves = MoveSet.new()
	wield.element = &"fixture_light"
	wield.bonuses = [StatModifier.of(&"attack", StatModifier.Op.ADD, 5.0, &"")]
	wield.lasts = 3.0
	var power := Power.new()
	power.power_id = &"power/fixture_wield"
	power.name_key = "fixture.power"
	power.mechanism = wield
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_wield"
	kit.powers = [power]
	var me: Combatant = _fighter(world, kit)
	var run: WieldRun = PowerSet.of(me.get_parent()).executor(power.power_id) as WieldRun
	equal("a weapon that changes nothing is a problem", WieldMechanism.new().problems("x").is_empty(), false)
	PowerUse.use(me, power, [], _rng)
	PowerUse.use(me, power, [], _rng)
	equal("a use lends the chain, the element and the bonus, once however often it is used",
		[me.lent_moves == wield.moves, me.lent_element, me.sheet.value(&"attack")], [true, &"fixture_light", 11.0])
	run.tick(2.0)
	equal("a second use started the time again", run.holding(), true)
	run.tick(1.5)
	equal("at the end all of it goes", [me.lent_moves, me.lent_element, me.sheet.value(&"attack")], [null, &"", 6.0])
	PowerUse.use(me, power, [], _rng)
	var gear_moves := MoveSet.new()
	me.lent_moves = gear_moves
	run.end()
	equal("gear worn meanwhile is not undone", me.lent_moves == gear_moves, true)
	world.free()
	Flags.clear_all()


func _fighter(world: Node3D, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_wielder"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0}
	actor.add_child(fighter)
	var powers := PowerSet.new()
	powers.set_physics_process(false)
	actor.add_child(powers)
	world.add_child(actor)
	powers.equip(kit)
	return fighter
