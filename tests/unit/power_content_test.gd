extends TestCase
## Hero power shapes (C6.1a): a whole kit reports no problems and each broken part is caught; a
## scaling rule's multiplier with a factor and with a curve, never below 0; a power's active hours,
## including a window across midnight; finding a power by id; and `cost_mult_<pool>` making a
## skill cheaper through `SkillUse.cost_of`, `affordable` and `pay`.
##
## OWNS: assertions about `PowerKit`, `Power`, `PowerScaling`, `PowerMechanism` and
## `SkillUse.cost_of`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

var _actors: Array[Node] = []


func run() -> void:
	plan(20)
	SaveFixture.activate()
	Flags.clear_all()
	_problems()
	_scaling()
	_hours()
	_costs()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _skill() -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture_power"
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 10
	return skill


func _power(id: StringName) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.skill = _skill()
	return power


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture"
	kit.name_key = "fixture.kit"
	kit.powers = [_power(&"power/fixture_a"), _power(&"power/fixture_b")]
	kit.stat_bonuses = [StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, -0.5, &"kit/fixture")]
	return kit


func _problems() -> void:
	var kit := _kit()
	equal("a whole kit has no problems", kit.problems("fixture"), PackedStringArray())
	equal("a power is found by its id", kit.power(&"power/fixture_b"), kit.powers[1])
	equal("an unknown id finds nothing", kit.power(&"power/fixture_none"), null)
	kit.powers.append(_power(&"power/fixture_a"))
	equal("a power listed twice is caught", kit.problems("fixture").size(), 1)
	var idle := _power(&"power/fixture_idle")
	idle.skill = null
	equal("a power with no skill and no mechanism is caught", idle.problems("fixture").size(), 1)
	idle.passive = true
	equal("unless it is passive", idle.problems("fixture").size(), 0)
	var odd := _power(&"power/fixture_odd")
	odd.cooldown = -1.0
	odd.requires_fraction = 0.5
	odd.active_hours = Vector2(-2.0, 30.0)
	equal("a negative cooldown, a fraction of no pool and bad hours are caught",
		odd.problems("fixture").size(), 3)
	var blank := PowerMechanism.new()
	equal("a mechanism with no kind is caught", blank.problems("fixture").size(), 1)


func _scaling() -> void:
	var rule := PowerScaling.new()
	rule.factor = 1.0
	equal("a factor of 1 doubles at a full reading", rule.multiplier(1.0), 2.0)
	equal("and is 1.5 at half", rule.multiplier(0.5), 1.5)
	rule.factor = -3.0
	equal("it never goes below 0", rule.multiplier(1.0), 0.0)
	var noon := Curve.new()
	# A Curve clamps its points to max_value, which starts at 1: raise it before adding a 3.
	noon.max_value = 4.0
	noon.add_point(Vector2(0.0, 0.5))
	noon.add_point(Vector2(0.5, 3.0))
	noon.add_point(Vector2(1.0, 0.5))
	var sun := PowerScaling.new()
	sun.source = PowerScaling.Source.CLOCK_CURVE
	sun.curve = noon
	equal("a curve gives its value: 3 at midday", is_equal_approx(sun.multiplier(0.5), 3.0), true)
	sun.curve = null
	equal("a clock rule with no curve is caught", sun.problems("fixture").size(), 1)


func _hours() -> void:
	var power := _power(&"power/fixture_timed")
	equal("(0, 24) works at any hour", power.active_at(3.0) and power.active_at(23.5), true)
	power.active_hours = Vector2(11.0, 13.0)
	equal("a noon window: 12 yes, 14 no", [power.active_at(12.0), power.active_at(14.0)], [true, false])
	power.active_hours = Vector2(20.0, 4.0)
	equal("a night window wraps midnight: 22 and 2 yes, 12 no",
		[power.active_at(22.0), power.active_at(2.0), power.active_at(12.0)], [true, true, false])


func _costs() -> void:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var user := Combatant.new()
	user.combatant_id = &"fixture_caster"
	user.base_stats = {&"max_hp": 30.0, &"max_mp": 12.0}
	actor.add_child(user)
	attach(actor)
	_actors.append(actor)
	var skill := _skill()
	equal("with no cost stat, a skill costs its cost", SkillUse.cost_of(user, skill), 10)
	user.sheet.add(_kit().stat_bonuses[0])
	equal("cost_mult_mp -0.5 halves it", SkillUse.cost_of(user, skill), 5)
	Vitals.of(actor).set_to(&"mp", 6)
	equal("so 6 mp is enough for a 10-mp skill", SkillUse.affordable(user, skill), true)
	SkillUse.pay(user, skill)
	equal("and paying takes 5, not 10", Vitals.of(actor).current(&"mp"), 1)
