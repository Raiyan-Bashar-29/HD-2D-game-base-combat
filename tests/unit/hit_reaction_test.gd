extends TestCase
## Hit or miss, counters and reflect (C2.15): accuracy against evasion under a seed, a sure-hit
## skill, a miss that changes nothing but is announced, a counter that answers a plain attack
## only, and a reflect that bounces a skill carrying the right tag back at its user.
##
## OWNS: assertions about what happens around a hit: whether it lands, and what answers it.
## MUST NOT: name a game's skills, statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []
var _missed: int = 0
var _damaged: int = 0
var _countered: int = 0
var _reflected: int = 0


func run() -> void:
	plan(19)
	SaveFixture.activate()
	Flags.clear_all()
	Events.attack_missed.connect(_on_missed)
	Events.combatant_damaged.connect(_on_damaged)
	Events.countered.connect(_on_countered)
	Events.skill_reflected.connect(_on_reflected)
	_accuracy_stage_alone()
	_a_miss_through_a_combatant()
	_counters()
	_reflect()
	Events.attack_missed.disconnect(_on_missed)
	Events.combatant_damaged.disconnect(_on_damaged)
	Events.countered.disconnect(_on_countered)
	Events.skill_reflected.disconnect(_on_reflected)
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	# Accuracy, then attack against defence: no crit or variance, so every number is exact.
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


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _reacting(name: String, reaction: StatusEffect.Reaction) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName("status/" + name)
	made.duration = 5.0
	made.reactions = [reaction]
	return made


func _command(kind: BattleCommand.Kind, tags: Array[StringName] = []) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	if kind == BattleCommand.Kind.SKILL:
		command.skill = Skill.new()
		command.skill.id = &"skill/fixture_spark"
		command.skill.name_key = "fixture.spark"
		command.skill.power = 4.0
		command.skill.tags = tags
	return command


func _accuracy_stage_alone() -> void:
	var formula := DamageFormula.new()
	formula.stages = [AccuracyStage.new(), AttackDefenceStage.new()]
	var hunter := StatSheet.new()
	hunter.set_base(&"attack", 6.0)
	var ghost := StatSheet.new()
	ghost.set_base(&"evasion", 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var before: int = rng.state
	formula.resolve(DamageRequest.of(hunter, StatSheet.new(), 2.0), rng)
	equal("a certain hit draws no random number, so old seeded fights replay unchanged", rng.state, before)
	var dodged: DamageResult = formula.resolve(DamageRequest.of(hunter, ghost, 2.0), rng)
	equal("evasion 1 makes every hit miss", dodged.missed, true)
	equal("and a miss does nothing", dodged.total(), 0)
	equal("a miss stops the stages after accuracy", dodged.stages_run.size(), 1)
	var sure := DamageRequest.of(hunter, ghost, 2.0)
	sure.sure_hit = true
	equal("a sure hit ignores evasion", formula.resolve(sure, rng).missed, false)
	var blur := StatSheet.new()
	blur.set_base(&"evasion", 0.5)
	var first: Array[bool] = _misses(formula, hunter, blur, 5)
	var landed: int = first.count(false)
	equal("evasion 0.5 dodges about half of 200 hits", landed > 60 and landed < 140, true)
	equal("and the same seed misses the same hits", _misses(formula, hunter, blur, 5), first)
	equal("the standard formula checks accuracy first",
		DamageFormula.standard().stages[0] is AccuracyStage, true)


func _misses(formula: DamageFormula, from: StatSheet, to: StatSheet, seed: int) -> Array[bool]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[bool] = []
	for i: int in 200:
		out.append(formula.resolve(DamageRequest.of(from, to, 1.0), rng).missed)
	return out


func _a_miss_through_a_combatant() -> void:
	Flags.clear_all()
	var swinger := _fighter(&"fixture_swinger", &"side_a", {&"attack": 5.0, &"max_hp": 20.0})
	var dodger := _fighter(&"fixture_dodger", &"side_b", {&"evasion": 1.0, &"max_hp": 20.0})
	_missed = 0
	_damaged = 0
	swinger.hit(dodger, 0.0, &"", RandomNumberGenerator.new())
	equal("a missed hit takes no hp", _hp(dodger), 20)
	equal("the miss is announced, and no damage is", [_missed, _damaged], [1, 0])
	_free_all()


func _counters() -> void:
	Flags.clear_all()
	var striker := _fighter(&"fixture_striker", &"side_a", {&"speed": 9.0, &"attack": 5.0, &"max_hp": 30.0})
	var guard := _fighter(&"fixture_guard", &"side_b", {&"speed": 1.0, &"attack": 3.0, &"max_hp": 30.0})
	var battle := Battle.new([striker], [guard], null, RandomNumberGenerator.new())
	battle.start()
	StatusSet.of(guard.get_parent()).apply(_reacting("fixture_riposte", StatusEffect.Reaction.COUNTER))
	_countered = 0
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [guard])
	equal("a plain attack on a countering fighter is answered: 30 - 3", _hp(striker), 27)
	equal("and the counter is announced", _countered, 1)
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.DEFEND), [])
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.SKILL), [guard])
	equal("a skill is not countered", _hp(striker), 27)
	guard.sheet.set_base(&"evasion", 1.0)
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.DEFEND), [])
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [guard])
	equal("an attack that missed is not countered", _hp(striker), 27)
	_free_all()


func _reflect() -> void:
	Flags.clear_all()
	var caster := _fighter(&"fixture_caster", &"side_a", {&"speed": 9.0, &"max_hp": 30.0})
	var mirror := _fighter(&"fixture_mirror", &"side_b", {&"speed": 1.0, &"max_hp": 30.0})
	StatusSet.of(mirror.get_parent()).apply(_reacting("fixture_mirror", StatusEffect.Reaction.REFLECT))
	_reflected = 0
	var rng := RandomNumberGenerator.new()
	var bolt: Skill = _command(BattleCommand.Kind.SKILL, [&"magic"]).skill
	SkillUse.apply(caster, bolt, [mirror], rng)
	equal("a magic skill on a reflecting target leaves the target alone", _hp(mirror), 30)
	equal("and lands on its user instead: 30 - 4", _hp(caster), 26)
	equal("the bounce is announced", _reflected, 1)
	var blade: Skill = _command(BattleCommand.Kind.SKILL).skill
	SkillUse.apply(caster, blade, [mirror], rng)
	equal("a skill without the tag is not reflected", _hp(mirror), 26)
	var blank := _reacting("fixture_blank", StatusEffect.Reaction.REFLECT)
	blank.reflect_tag = &""
	equal("a reflect that names no tag is a problem", blank.problems().size(), 1)
	_free_all()


func _on_missed(_who: StringName, _by: StringName) -> void:
	_missed += 1


func _on_damaged(_who: StringName, _by: StringName, _amount: int, _critical: bool) -> void:
	_damaged += 1


func _on_countered(_who: StringName, _against: StringName) -> void:
	_countered += 1


func _on_reflected(_who: StringName, _back_to: StringName, _skill_id: StringName) -> void:
	_reflected += 1
