extends TestCase
## `BattleBrain`, `BrainEntry` and `BattleAi`: a weight of zero never fires, a flag condition
## gates an entry, a pool condition waits for low hp, an unaffordable skill is never chosen, the
## LOWEST_HP rule, the fallback attack, and a seeded battle choosing the same targets twice.
##
## OWNS: assertions about how an uncontrolled combatant picks its turn.
## MUST NOT: name a game's combatants, skills or flags. Every name here is made up for the case.

const RAGE_FLAG: StringName = &"fixture/ai_rage"

var _actors: Array[Node] = []


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	_content_problems()
	_weights_and_fallback()
	_a_flag_condition_gates()
	_a_pool_condition_waits()
	_lowest_hp_and_cost()
	_seeded_choices_repeat()
	Flags.clear_all()


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


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _entry(command: BattleCommand, weight: float) -> BrainEntry:
	var entry := BrainEntry.new()
	entry.command = command
	entry.weight = weight
	return entry


func _skill_command(power: float, target: FactionTable.Target) -> BattleCommand:
	var skill := Skill.new()
	skill.id = &"skill/fixture_ai"
	skill.name_key = "fixture.ai"
	skill.power = power
	skill.target = target
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = skill
	return command


func _brain(entries: Array[BrainEntry]) -> BattleBrain:
	var brain := BattleBrain.new()
	brain.entries = entries
	return brain


## A fresh duel with the AI's combatant on turn. It is fast, hits for its attack stat, and faces
## one or two targets.
func _duel(second: bool = false) -> Battle:
	Flags.clear_all()
	var ai := _fighter(&"fixture_ai", &"side_b", {&"speed": 10.0, &"attack": 5.0, &"max_hp": 40.0, &"max_mp": 3.0})
	var party: Array[Combatant] = [_fighter(&"fixture_one", &"side_a", {&"speed": 1.0, &"max_hp": 100.0})]
	if second:
		party.append(_fighter(&"fixture_two", &"side_a", {&"speed": 1.0, &"max_hp": 100.0}))
	var battle := Battle.new(party, [ai], null, RandomNumberGenerator.new())
	battle.rng.seed = 11
	battle.start()
	battle.next_turn()
	return battle


func _content_problems() -> void:
	equal("an entry with no command is caught", _entry(null, 1.0).problems("fixture").size() > 0, true)
	var gated := _entry(BattleCommand.new(), 1.0)
	gated.condition_test = GameEnums.FlagTest.IS_TRUE
	equal("a flag test naming no flag is caught", _brain([gated]).problems("fixture").size() > 0, true)


func _weights_and_fallback() -> void:
	var battle := _duel()
	var big := _skill_command(50.0, FactionTable.Target.ENEMY)
	BattleAi.take_turn(battle, _brain([_entry(big, 0.0)]))
	equal("a weight of zero never fires: the fallback attack hit for 5", _hp(battle.party[0]), 95)
	_free_all()


func _a_flag_condition_gates() -> void:
	var battle := _duel()
	var big := _entry(_skill_command(50.0, FactionTable.Target.ENEMY), 100.0)
	big.condition_flag = RAGE_FLAG
	big.condition_test = GameEnums.FlagTest.IS_TRUE
	var plain := _entry(BattleCommand.new(), 1.0)
	BattleAi.take_turn(battle, _brain([big, plain]))
	equal("with the flag unset, the gated entry is skipped", _hp(battle.party[0]), 95)
	_free_all()
	battle = _duel()
	Flags.set_flag(RAGE_FLAG, true)
	BattleAi.take_turn(battle, _brain([big, plain]))
	equal("with it set, the gated entry is chosen: 100 - (50 + 5)", _hp(battle.party[0]), 45)
	_free_all()


func _a_pool_condition_waits() -> void:
	var battle := _duel()
	var ai: Combatant = battle.enemies[0]
	var mend := _entry(_skill_command(-10.0, FactionTable.Target.ALLY), 100.0)
	mend.target_rule = BrainEntry.TargetRule.SELF
	mend.below_fraction = 0.5
	var plain := _entry(BattleCommand.new(), 1.0)
	BattleAi.take_turn(battle, _brain([mend, plain]))
	equal("at full hp the heal waits, and it attacks", _hp(battle.party[0]), 95)
	_free_all()
	battle = _duel()
	ai = battle.enemies[0]
	Vitals.of(ai.get_parent()).set_to(&"hp", 10)
	BattleAi.take_turn(battle, _brain([mend, plain]))
	equal("under half it heals itself: 10 + 10", _hp(ai), 20)
	_free_all()


func _lowest_hp_and_cost() -> void:
	var battle := _duel(true)
	Vitals.of(battle.party[1].get_parent()).set_to(&"hp", 30)
	var aimed := _entry(BattleCommand.new(), 1.0)
	aimed.target_rule = BrainEntry.TargetRule.LOWEST_HP
	BattleAi.take_turn(battle, _brain([aimed]))
	equal("LOWEST_HP hits the weaker target", [_hp(battle.party[0]), _hp(battle.party[1])], [100, 25])
	_free_all()
	battle = _duel()
	var dear := _skill_command(50.0, FactionTable.Target.ENEMY)
	dear.skill.cost_pool = &"mp"
	dear.skill.cost = 5
	BattleAi.take_turn(battle, _brain([_entry(dear, 100.0)]))
	equal("a skill the user cannot afford is never chosen", _hp(battle.party[0]), 95)
	_free_all()


func _seeded_choices_repeat() -> void:
	var picks: Array[Array] = []
	for attempt: int in 2:
		var battle := _duel(true)
		var anyone := _entry(BattleCommand.new(), 1.0)
		anyone.target_rule = BrainEntry.TargetRule.RANDOM
		var hits: Array[int] = []
		for turn: int in 6:
			BattleAi.take_turn(battle, _brain([anyone]))
			hits.append(_hp(battle.party[0]))
			battle.next_turn()
			battle.next_turn()
			battle.next_turn()
		picks.append(hits)
		_free_all()
	equal("the same seed makes the same choices", picks[0], picks[1])
