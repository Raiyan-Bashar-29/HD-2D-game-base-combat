extends TestCase
## The rarer ailments (C8.7a). Doom: a fatal status fells its holder when it runs out, in
## turns or in seconds, and a cure before that saves them. Petrify: a status that counts its
## holder as fallen loses the battle for a side that still stands, and holds a field fighter
## still. Instant death: a SLAY effect fells on its chance, and `resist_death` or an
## invincible status refuses it.
##
## OWNS: assertions about `StatusEffect.fatal` and `counts_as_fallen`, `StatusSet.fallen`,
## `SkillEffect.Kind.SLAY` and what `Battle` makes of a petrified side.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	_content()
	_doom()
	_petrify()
	_slay()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _content() -> void:
	var endless: StatusEffect = _status(&"status/fixture_doom", 0.0)
	endless.fatal = true
	var stone: StatusEffect = _stone()
	equal("a fatal status needs a duration; a petrify may skip turns with no end",
		[endless.problems().size(), stone.problems().size()], [1, 0])
	var slay := SkillEffect.new()
	slay.kind = SkillEffect.Kind.SLAY
	var none: int = slay.problems("fixture").size()
	slay.amount = 0.5
	equal("a SLAY effect needs a chance above 0 up to 1", [none, slay.problems("fixture").size()], [1, 0])


func _doom() -> void:
	var me: Combatant = _fighter(&"fixture_doomed", &"side_a", {&"max_hp": 30.0})
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	var doom: StatusEffect = _status(&"status/fixture_doom", 2.0)
	doom.fatal = true
	statuses.apply(doom)
	statuses.tick_turn()
	var mid: int = _hp(me)
	statuses.tick_turn()
	equal("a doomed fighter is unhurt until the count ends, then falls", [mid, _hp(me)], [30, 0])
	var saved: Combatant = _fighter(&"fixture_saved", &"side_a", {&"max_hp": 30.0})
	statuses = StatusSet.of(saved.get_parent())
	statuses.apply(doom)
	statuses.tick_turn()
	statuses.cure(doom.id)
	statuses.tick_turn()
	equal("a doom cured before it runs out fells nobody", _hp(saved), 30)
	var timed: Combatant = _fighter(&"fixture_timed", &"side_a", {&"max_hp": 30.0})
	statuses = StatusSet.of(timed.get_parent())
	var clock: StatusEffect = _status(&"status/fixture_doom_clock", 1.0)
	clock.unit = StatusEffect.Unit.SECONDS
	clock.fatal = true
	statuses.apply(clock)
	statuses.tick_seconds(0.6)
	var early: int = _hp(timed)
	statuses.tick_seconds(0.6)
	equal("a doom counted in seconds does the same in the field", [early, _hp(timed)], [30, 0])
	var warded: Combatant = _fighter(&"fixture_warded", &"side_a", {&"max_hp": 30.0, &"resist_death": 1.0})
	doom.tags = [&"death"]
	equal("a fighter immune to its tag never takes the doom",
		StatusSet.of(warded.get_parent()).apply(doom), false)


func _petrify() -> void:
	var me: Combatant = _fighter(&"fixture_stone_hero", &"side_a", {&"max_hp": 50.0, &"speed": 9.0})
	var foe: Combatant = _fighter(&"fixture_stone_foe", &"side_b", {&"max_hp": 50.0, &"speed": 1.0})
	var battle := Battle.new([me], [foe])
	battle.start()
	var actor: Combatant = battle.next_turn()
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	var before: Array = [statuses.fallen(), statuses.halts()]
	statuses.apply(_stone())
	var attack := BattleCommand.new()
	battle.act(attack, [foe])
	equal("a side whose last standing member is petrified has lost, though its hp is whole",
		[actor == me, before, statuses.fallen(), statuses.halts(), _hp(me), battle.outcome()],
		[true, [false, false], true, true, 50, Battle.Outcome.LOST])
	statuses.cure(_stone().id)
	equal("cured, the fighter counts as standing again", [statuses.fallen(), statuses.halts()], [false, false])


func _slay() -> void:
	var user: Combatant = _fighter(&"fixture_reaper", &"side_a", {&"max_hp": 50.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var skill := Skill.new()
	var effect := SkillEffect.new()
	effect.kind = SkillEffect.Kind.SLAY
	effect.amount = 1.0
	skill.effects = [effect]
	var plain: Combatant = _fighter(&"fixture_mortal", &"side_b", {&"max_hp": 900.0})
	var immune: Combatant = _fighter(&"fixture_boss", &"side_b", {&"max_hp": 900.0, &"resist_death": 1.0})
	var shelled: Combatant = _fighter(&"fixture_shelled", &"side_b", {&"max_hp": 900.0})
	var shell: StatusEffect = _status(&"status/fixture_shell", 3.0)
	shell.invincible = true
	StatusSet.of(shelled.get_parent()).apply(shell)
	SkillUse.apply(user, skill, [plain, immune, shelled], rng)
	equal("a sure SLAY fells its target at once; one immune to death or invincible stands",
		[_hp(plain), _hp(immune), _hp(shelled)], [0, 900, 900])
	effect.amount = 0.5
	var half: Combatant = _fighter(&"fixture_half", &"side_b", {&"max_hp": 900.0, &"resist_death": 0.5})
	var fell: int = 0
	for i: int in 200:
		SkillUse.apply(user, skill, [half], rng)
		if _hp(half) == 0:
			fell += 1
			Vitals.of(half.get_parent()).revive(900)
	equal("half a chance against half a resistance takes about one in four", fell > 25 and fell < 75, true)


func _status(id: StringName, lasts: float) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = id
	made.name_key = "ui.cancel"
	made.duration = lasts
	return made


func _stone() -> StatusEffect:
	var made: StatusEffect = _status(&"status/fixture_stone", 0.0)
	made.blocks = [StatusEffect.Block.SKIP_TURN]
	made.counts_as_fallen = true
	return made


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant
