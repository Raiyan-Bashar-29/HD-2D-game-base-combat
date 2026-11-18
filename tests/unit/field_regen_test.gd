extends TestCase
## Pools that fill in the field (C10.9): a `regen_<pool>` stat adds that much a second of fight
## time, its fractions carried, and a negative one drains; a stopped fight adds nothing; a
## kit's gauge pool is not regenerated a second time; the ATB gauge fills for a blocked hit,
## and with `per_swing` one swing over two foes pays once.
##
## OWNS: assertions about `Meters.regen_seconds`, `AtbRules.on_block` and `per_swing`.
## MUST NOT: name a game's pools or fighters, or wait for frames.

var _bodies: Array[Node] = []


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	_regen()
	_a_field_foe()
	_atb()
	for body: Node in _bodies:
		body.free()
	CombatClock.reset()
	Flags.clear_all()


func _body(id: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var body := CharacterBody3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = &"side_a"
	fighter.real_time = true
	fighter.base_stats = stats
	body.add_child(fighter)
	attach(body)
	_bodies.append(body)
	return fighter


func _mp(fighter: Combatant, pool: StringName = &"mp") -> int:
	return Vitals.of(fighter.get_parent()).current(pool)


func _regen() -> void:
	var filler: Combatant = _body(&"fixture_regen_filler", {&"max_hp": 10.0, &"max_mp": 50.0, &"regen_mp": 3.0})
	Vitals.of(filler.get_parent()).set_to(&"mp", 0)
	Meters.regen_seconds(filler, 0.5)
	Meters.regen_seconds(filler, 0.5)
	var whole: int = _mp(filler)
	for i: int in 4:
		Meters.regen_seconds(filler, 0.1)
	equal("regen_mp 3 adds 3 a second, and tenths carry until a point is whole", [whole, _mp(filler)], [3, 4])
	var drained: Combatant = _body(&"fixture_regen_drained", {&"max_hp": 10.0, &"max_mp": 50.0, &"regen_mp": -2.0})
	Meters.regen_seconds(drained, 1.5)
	equal("a negative regen drains, its fraction carried too", _mp(drained), 47)
	var gauged: Combatant = _body(&"fixture_regen_gauged", {&"max_hp": 10.0, &"max_focus": 100.0, &"regen_focus": 5.0})
	var powers := PowerSet.new()
	gauged.get_parent().add_child(powers)
	var rule := GaugeRule.new()
	rule.pool = &"focus"
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_regen"
	kit.name_key = "fixture.kit"
	kit.gauges = [rule]
	powers.equip(kit)
	Vitals.of(gauged.get_parent()).set_to(&"focus", 0)
	Meters.regen_seconds(gauged, 1.0)
	equal("a kit's gauge pool is left to the kit", _mp(gauged, &"focus"), 0)


func _a_field_foe() -> void:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_regen_foe"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0, &"max_mp": 30.0, &"regen_mp": 2.0}
	var foe := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	foe.fighter = def
	foe.brain = ActionBrain.new()
	attach(foe)
	_bodies.append(foe)
	Vitals.of(foe).set_to(&"mp", 0)
	foe.act(1.0)
	CombatClock.set_scale(0.0)
	foe.act(1.0)
	CombatClock.reset()
	equal("a field foe regenerates on its own clock, and not while the fight is stopped", Vitals.of(foe).current(&"mp"), 2)


func _atb() -> void:
	var hero: Combatant = _body(&"fixture_regen_atb", {&"max_hp": 10.0})
	var meter := AtbMeter.new()
	meter.gauge.rules = AtbRules.new()
	meter.gauge.rules.per_second = 0.0
	meter.gauge.rules.on_block = 15.0
	meter.gauge.rules.per_swing = true
	hero.get_parent().add_child(meter)
	Events.attack_blocked.emit(hero.combatant_id, &"fixture_regen_other")
	var blocked: float = meter.gauge.value
	Events.combatant_damaged.emit(&"fixture_regen_one", hero.combatant_id, 5, false)
	Events.combatant_damaged.emit(&"fixture_regen_two", hero.combatant_id, 5, false)
	var swing: float = meter.gauge.value
	meter.tick(0.0)
	Events.combatant_damaged.emit(&"fixture_regen_one", hero.combatant_id, 5, false)
	equal("a blocked hit adds on_block", blocked, 15.0)
	equal("with per_swing, one swing over two foes pays once, and the next swing pays again",
		[swing, meter.gauge.value], [27.0, 39.0])
