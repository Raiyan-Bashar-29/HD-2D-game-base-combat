extends TestCase
## Hero powers in play (C6.1b): equipping a kit puts its stat bonuses and passives on and
## unequipping takes exactly them off; each reason a power is refused (passive, not equipped,
## cooldown, hours, a needed status, a pool not full enough, a silence, the cost) is the one
## the menu reads; a use pays, lands its skill, starts its cooldown and uses up its statuses;
## cooldowns count down in seconds and in turns; each scaling source changes a copy of the
## skill, never the data; and a mechanism's executor is made, used, ticked and ended.
##
## OWNS: assertions about `PowerSet`, `PowerUse`, `PowerMechanisms` and `PowerExecutor`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const FAKE_KIND: StringName = &"fixture_fake"
const NOON: float = 12.0


## A mechanism only this test runs.
class FakeMechanism:
	extends PowerMechanism

	func kind() -> StringName:
		return FAKE_KIND


## Counts what it was asked to do.
class FakeExecutor:
	extends PowerExecutor
	var used: int = 0
	var ticked: float = 0.0
	var ended: int = 0
	var last_targets: int = -1

	func use(_user: Combatant, aimed: Array[Combatant], _rng: RandomNumberGenerator) -> void:
		used += 1
		last_targets = aimed.size()

	func tick(amount: float) -> void:
		ticked += amount

	func end() -> void:
		ended += 1


var _actors: Array[Node] = []
var _hero: Combatant
var _foe: Combatant
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(34)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	PowerMechanisms.register(FAKE_KIND, FakeExecutor)
	_hero = _fighter(&"fixture_hero", &"player", Vector3.ZERO)
	_foe = _fighter(&"fixture_foe", &"enemy", Vector3(0, 0, -2))
	_equipping()
	_refusing()
	_using()
	_scaling()
	_mechanism()
	PowerMechanisms.unregister(FAKE_KIND)
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _equipping() -> void:
	var powers: PowerSet = PowerSet.of(_hero.get_parent())
	var statuses: StatusSet = StatusSet.of(_hero.get_parent())
	_hero.sheet.add(StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, -0.25, &"fixture_ring"))
	powers.equip(_kit())
	equal("equipping puts the kit's stat bonus on the sheet",
		_hero.sheet.value(&"cost_mult_mp"), -0.75)
	equal("and its passive on as a status", statuses.stacks(&"status/fixture_aura"), 1)
	powers.unequip()
	equal("unequipping takes off only the kit's bonus", _hero.sheet.value(&"cost_mult_mp"), -0.25)
	equal("and its passive", statuses.stacks(&"status/fixture_aura"), 0)
	_hero.sheet.remove_from(&"fixture_ring")
	powers.equip(_kit())


func _refusing() -> void:
	var powers: PowerSet = PowerSet.of(_hero.get_parent())
	var bolt: Power = powers.kit.power(&"power/fixture_bolt")
	equal("a ready power is not refused", PowerUse.refusal(_hero, bolt, NOON), PowerUse.Reason.NONE)
	var passive := _power(&"power/fixture_held")
	passive.passive = true
	powers.kit.powers.append(passive)
	equal("a passive power is never used", PowerUse.refusal(_hero, passive, NOON), PowerUse.Reason.PASSIVE)
	equal("a power from another kit is not equipped",
		PowerUse.refusal(_hero, _power(&"power/fixture_stray"), NOON), PowerUse.Reason.NOT_EQUIPPED)
	var sun: Power = powers.kit.power(&"power/fixture_noon")
	equal("a noon power at 22:00 is out of hours", PowerUse.refusal(_hero, sun, 22.0), PowerUse.Reason.HOURS)
	equal("and fine at noon", PowerUse.refusal(_hero, sun, NOON), PowerUse.Reason.NONE)
	var finisher: Power = powers.kit.power(&"power/fixture_finisher")
	equal("a finisher without its primer is refused",
		PowerUse.refusal(_hero, finisher, NOON), PowerUse.Reason.STATUS)
	var limit: Power = powers.kit.power(&"power/fixture_limit")
	Vitals.of(_hero.get_parent()).set_to(&"mp", 10)
	equal("a power needing full mp, at 10 of 20, is refused",
		PowerUse.refusal(_hero, limit, NOON), PowerUse.Reason.POOL)
	var statuses: StatusSet = StatusSet.of(_hero.get_parent())
	statuses.apply(_status(&"status/fixture_hush", [StatusEffect.Block.NO_SKILLS]))
	equal("a silence blocks a power", PowerUse.refusal(_hero, bolt, NOON), PowerUse.Reason.BLOCKED)
	statuses.cure(&"status/fixture_hush")
	Vitals.of(_hero.get_parent()).set_to(&"mp", 1)
	equal("1 mp is short of the kit-halved 4-mp cost",
		PowerUse.refusal(_hero, bolt, NOON), PowerUse.Reason.COST)
	equal("and a refused use changes nothing",
		[PowerUse.use(_hero, bolt, [_foe], _rng, NOON), Vitals.of(_foe.get_parent()).current(&"hp")],
		[false, 60])


func _using() -> void:
	var powers: PowerSet = PowerSet.of(_hero.get_parent())
	var vitals: Vitals = Vitals.of(_hero.get_parent())
	var bolt: Power = powers.kit.power(&"power/fixture_bolt")
	vitals.set_to(&"mp", 20)
	var aimed: Array[Combatant] = PowerUse.targets(_hero, bolt)
	equal("the field aims a power at the nearest foe", aimed.size() == 1 and aimed[0] == _foe, true)
	equal("a use succeeds", PowerUse.use(_hero, bolt, aimed, _rng, NOON), true)
	equal("it lands its skill on the foe", Vitals.of(_foe.get_parent()).current(&"hp") < 60, true)
	equal("it pays the cost after the kit's -50%", vitals.current(&"mp"), 16)
	equal("it starts the cooldown", [powers.cooldown_left(&"power/fixture_bolt"),
		PowerUse.refusal(_hero, bolt, NOON)], [3.0, PowerUse.Reason.COOLDOWN])
	powers.tick_seconds(2.0)
	powers.tick_turn()
	equal("two seconds and a turn cool it down", PowerUse.refusal(_hero, bolt, NOON), PowerUse.Reason.NONE)
	var statuses: StatusSet = StatusSet.of(_hero.get_parent())
	statuses.apply(_status(&"status/fixture_primer", []))
	var finisher: Power = powers.kit.power(&"power/fixture_finisher")
	PowerUse.use(_hero, finisher, [_foe], _rng, NOON)
	equal("a finisher uses up its primer", statuses.stacks(&"status/fixture_primer"), 0)


func _scaling() -> void:
	var vitals: Vitals = Vitals.of(_hero.get_parent())
	var power := _power(&"power/fixture_scaled")
	power.skill.hits = 2
	power.skill.statuses = [_status(&"status/fixture_burn", [])]
	power.scaling = [_rule(PowerScaling.Source.USER_HP_FRACTION, PowerScaling.Affects.POWER)]
	vitals.set_to(&"hp", vitals.maximum(&"hp"))
	equal("full hp doubles the power", PowerUse.scaled_skill(_hero, power, [_foe], NOON).power, 8.0)
	power.scaling = [_rule(PowerScaling.Source.USER_MISSING_HP, PowerScaling.Affects.HITS)]
	vitals.set_to(&"hp", vitals.maximum(&"hp") / 2)
	equal("half the hp missing makes 2 hits 3", PowerUse.scaled_skill(_hero, power, [_foe], NOON).hits, 3)
	var pool := _rule(PowerScaling.Source.POOL_FRACTION, PowerScaling.Affects.DURATION)
	pool.pool = &"mp"
	power.scaling = [pool]
	vitals.set_to(&"mp", 20)
	var longer: Skill = PowerUse.scaled_skill(_hero, power, [_foe], NOON)
	equal("a full pool doubles its statuses' duration, on a copy",
		[longer.statuses[0].duration, power.skill.statuses[0].duration], [6.0, 3.0])
	var sun := _rule(PowerScaling.Source.CLOCK_CURVE, PowerScaling.Affects.POWER)
	sun.curve = _noon_curve()
	power.scaling = [sun]
	equal("the clock's curve triples it at noon",
		is_equal_approx(PowerUse.scaled_skill(_hero, power, [_foe], NOON).power, 12.0), true)
	var tagged := _rule(PowerScaling.Source.TARGET_HAS_TAG, PowerScaling.Affects.POWER)
	tagged.tag = &"fixture_mark"
	power.scaling = [tagged]
	var plain: float = PowerUse.scaled_skill(_hero, power, [_foe], NOON).power
	StatusSet.of(_foe.get_parent()).apply(_status(&"status/fixture_marked", [], [&"fixture_mark"]))
	equal("a marked target doubles it, an unmarked one does not",
		[plain, PowerUse.scaled_skill(_hero, power, [_foe], NOON).power], [4.0, 8.0])
	equal("scaling never changes the data", [power.skill.power, power.skill.hits], [4.0, 2])
	var count := _rule(PowerScaling.Source.TARGET_HAS_TAG, PowerScaling.Affects.COUNT)
	count.tag = &"fixture_mark"
	count.factor = 2.0
	power.scaling = [count]
	equal("a mechanism reads its count as a multiplier",
		PowerUse.multiplier(_hero, power, PowerScaling.Affects.COUNT, _foe, NOON), 3.0)


func _mechanism() -> void:
	var powers: PowerSet = PowerSet.of(_hero.get_parent())
	var gate: Power = powers.kit.power(&"power/fixture_gate")
	var fake: FakeExecutor = powers.executor(&"power/fixture_gate") as FakeExecutor
	equal("equipping makes the mechanism's executor", fake != null, true)
	equal("a power with only a mechanism needs no targets",
		PowerUse.use(_hero, gate, [], _rng, NOON), true)
	equal("and its executor runs", [fake.used, fake.last_targets], [1, 0])
	var before: float = fake.ticked
	powers.tick_seconds(0.5)
	equal("time passing ticks it", fake.ticked - before, 0.5)
	powers.unequip()
	equal("unequipping ends it", fake.ended, 1)
	var odd := FakeMechanism.new()
	PowerMechanisms.unregister(FAKE_KIND)
	equal("a kind nothing runs makes no executor", PowerMechanisms.make(odd), null)


func _fighter(id: StringName, faction: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.base_stats = {&"max_hp": 60.0, &"max_mp": 20.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	attach(actor)
	_actors.append(actor)
	return fighter


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, -0.5, &"anything")]
	var aura := _status(&"status/fixture_aura", [])
	aura.duration = 0.0
	kit.passives = [aura]
	var bolt := _power(&"power/fixture_bolt")
	bolt.cooldown = 3.0
	var sun := _power(&"power/fixture_noon")
	sun.active_hours = Vector2(11.0, 13.0)
	var finisher := _power(&"power/fixture_finisher")
	finisher.requires_statuses = [&"status/fixture_primer"]
	finisher.consumes_statuses = [&"status/fixture_primer"]
	var limit := _power(&"power/fixture_limit")
	limit.requires_pool = &"mp"
	limit.requires_fraction = 1.0
	var gate := _power(&"power/fixture_gate")
	gate.skill = null
	gate.mechanism = FakeMechanism.new()
	kit.powers = [bolt, sun, finisher, limit, gate]
	return kit


func _power(id: StringName) -> Power:
	var skill := Skill.new()
	skill.id = StringName(String(id).replace("power/", "skill/"))
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 8
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.skill = skill
	return power


func _status(id: StringName, blocks: Array[StatusEffect.Block],
		tags: Array[StringName] = []) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = 3.0
	status.blocks = blocks
	status.tags = tags
	return status


func _rule(source: PowerScaling.Source, affects: PowerScaling.Affects) -> PowerScaling:
	var rule := PowerScaling.new()
	rule.source = source
	rule.affects = affects
	return rule


func _noon_curve() -> Curve:
	var curve := Curve.new()
	# A Curve clamps its points to max_value, which starts at 1: raise it before adding a 3.
	curve.max_value = 4.0
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.5, 3.0))
	curve.add_point(Vector2(1.0, 0.5))
	return curve
