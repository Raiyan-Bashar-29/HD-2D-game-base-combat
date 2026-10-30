extends TestCase
## Meters, stances and Boost (C2.16): a pool that regenerates each turn from `regen_<pool>`, one
## that fills from damage taken through `fill_on_hit_<pool>`, a limit special that waits for its
## gauge, a stance skill that toggles on and off, and Boost spending points for more hits or more
## power.
##
## OWNS: assertions about pools that move on their own, toggled skills, and Boost.
## MUST NOT: name a game's skills, statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []


func run() -> void:
	plan(23)
	SaveFixture.activate()
	Flags.clear_all()
	_regeneration()
	_filling_on_hit()
	_stances()
	_boost()
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	# Attack against defence only: every number below is exact.
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AccuracyStage.new(), AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _vitals(fighter: Combatant) -> Vitals:
	return Vitals.of(fighter.get_parent())


func _skill(name: String, power: float) -> Skill:
	var made := Skill.new()
	made.id = StringName("skill/" + name)
	made.name_key = "fixture." + name
	made.power = power
	return made


func _command(kind: BattleCommand.Kind, skill: Skill = null) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	command.skill = skill
	return command


func _regeneration() -> void:
	Flags.clear_all()
	var sage := _fighter(&"fixture_sage", &"side_a", {&"speed": 9.0, &"max_hp": 20.0,
		&"max_mp": 10.0, &"regen_mp": 3.0, &"max_bp": 5.0, &"regen_bp": 1.0})
	var foe := _fighter(&"fixture_foe", &"side_b", {&"speed": 1.0, &"max_hp": 20.0})
	_vitals(sage).set_to(&"mp", 2)
	Meters.regen_turn(sage)
	equal("regen_mp 3 restores 3 mp a turn", _vitals(sage).current(&"mp"), 5)
	var battle := Battle.new([sage], [foe], null, RandomNumberGenerator.new())
	battle.start()
	_vitals(sage).set_to(&"bp", 0)
	battle.next_turn()
	equal("a battle regenerates its actor as the turn begins: one Boost point", _vitals(sage).current(&"bp"), 1)
	var aura := StatModifier.new()
	aura.stat = &"regen_mp"
	aura.value = -5.0
	aura.source = &"fixture_aura"
	sage.sheet.add(aura)
	_vitals(sage).set_to(&"mp", 6)
	Meters.regen_turn(sage)
	equal("a negative regen drains instead: 6 + 3 - 5", _vitals(sage).current(&"mp"), 4)
	var fresh := _fighter(&"fixture_fresh", &"side_a", {&"max_hp": 9.0, &"max_limit": 100.0,
		&"start_limit": 0.0, &"max_bp": 5.0, &"start_bp": 0.2})
	equal("a gauge with start_limit 0 starts empty, not full", _vitals(fresh).current(&"limit"), 0)
	equal("start_bp 0.2 of 5 starts at 1", _vitals(fresh).current(&"bp"), 1)
	_free_all()


func _filling_on_hit() -> void:
	Flags.clear_all()
	var brute := _fighter(&"fixture_brute", &"side_a", {&"attack": 10.0, &"max_hp": 50.0})
	var hero := _fighter(&"fixture_hero", &"side_b", {&"max_hp": 50.0, &"max_limit": 100.0,
		&"fill_on_hit_limit": 0.5, &"evasion": 0.0})
	_vitals(hero).set_to(&"limit", 0)
	brute.hit(hero, 0.0, &"", RandomNumberGenerator.new())
	equal("taking 10 fills half of it into the limit gauge", _vitals(hero).current(&"limit"), 5)
	hero.sheet.set_base(&"evasion", 1.0)
	brute.hit(hero, 0.0, &"", RandomNumberGenerator.new())
	equal("a miss fills nothing", _vitals(hero).current(&"limit"), 5)
	var finale := _skill("fixture_finale", 30.0)
	finale.cost_pool = &"limit"
	finale.cost = 100
	equal("a limit special waits for a full gauge", SkillUse.affordable(hero, finale), false)
	_vitals(hero).set_to(&"limit", 100)
	SkillUse.pay(hero, finale)
	equal("and using it empties the gauge", _vitals(hero).current(&"limit"), 0)
	_free_all()


func _stances() -> void:
	Flags.clear_all()
	var monk := _fighter(&"fixture_monk", &"side_a", {&"max_hp": 20.0, &"max_mp": 10.0})
	var fury := StatusEffect.new()
	fury.id = &"status/fixture_fury"
	fury.duration = 0.0
	var stance := _skill("fixture_stance", 0.0)
	stance.target = FactionTable.Target.SELF
	stance.toggle_status = fury
	stance.cost_pool = &"mp"
	stance.cost = 4
	var rng := RandomNumberGenerator.new()
	SkillUse.pay(monk, stance)
	SkillUse.apply(monk, stance, [monk], rng)
	equal("using a stance turns it on", StatusSet.of(monk.get_parent()).stacks(fury.id), 1)
	equal("and turning it on costs", _vitals(monk).current(&"mp"), 6)
	_vitals(monk).set_to(&"mp", 0)
	equal("turning it off is affordable with nothing in the pool", SkillUse.affordable(monk, stance), true)
	SkillUse.pay(monk, stance)
	SkillUse.apply(monk, stance, [monk], rng)
	equal("using it again turns it off", StatusSet.of(monk.get_parent()).stacks(fury.id), 0)
	equal("and turning it off is free", _vitals(monk).current(&"mp"), 0)
	equal("a stance that does nothing else is not a problem", stance.problems().size(), 0)
	stance.power = 5.0
	equal("a stance that also hits is a problem", stance.problems().size(), 1)
	_free_all()


func _boost() -> void:
	Flags.clear_all()
	var fencer := _fighter(&"fixture_fencer", &"side_a", {&"speed": 9.0, &"attack": 4.0,
		&"max_hp": 99.0, &"max_bp": 5.0})
	var post := _fighter(&"fixture_post", &"side_b", {&"speed": 1.0, &"max_hp": 99.0})
	var battle := Battle.new([fencer], [post], null, RandomNumberGenerator.new())
	battle.start()
	_vitals(fencer).set_to(&"bp", 3)
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [post], 2)
	equal("an attack boosted twice lands three times: 99 - 3 x 4", _vitals(post).current(&"hp"), 87)
	equal("and spends two Boost points", _vitals(fencer).current(&"bp"), 1)
	battle.next_turn()
	# The post swings back rather than defending, so its defence stays at zero for the skill below.
	battle.act(_command(BattleCommand.Kind.ATTACK), [fencer])
	battle.next_turn()
	equal("a boost the pool cannot pay is refused", battle.act(_command(BattleCommand.Kind.ATTACK), [post], 2), false)
	_vitals(fencer).set_to(&"bp", 5)
	equal("a boost above boost_max is refused", battle.act(_command(BattleCommand.Kind.ATTACK), [post], 4), false)
	equal("DEFEND cannot be boosted", battle.act(_command(BattleCommand.Kind.DEFEND), [], 1), false)
	var lance := _skill("fixture_lance", 6.0)
	lance.boost_power = 0.5
	battle.act(_command(BattleCommand.Kind.SKILL, lance), [post], 2)
	equal("a skill boosted twice at 0.5 a level doubles its own power: 87 - (6 x 2 + 4)", _vitals(post).current(&"hp"), 71)
	equal("refused commands spent nothing; the skill spent two", _vitals(fencer).current(&"bp"), 3)
	_free_all()
