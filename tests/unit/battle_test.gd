extends TestCase
## `Battle`: a whole fixture fight driven with no frames. Turn order, an illegal target refused,
## a skill's cost and ALL scope, DEFEND lasting until the defender's next turn, a heal, a status
## from a skill, the fallen leaving the queue, and the three endings: WON, LOST and FLED.
##
## OWNS: assertions about what a turn-based battle does with a command.
## MUST NOT: name a game's combatants, skills or items. Every name here is made up for the case.

var _ended: Array[int] = []
var _actors: Array[Node] = []


func run() -> void:
	plan(20)
	SaveFixture.activate()
	Flags.clear_all()
	Events.battle_ended.connect(_on_ended)
	_a_fight_to_victory()
	_defend_and_heal()
	_defeat_and_flight()
	Events.battle_ended.disconnect(_on_ended)
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


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _command(kind: BattleCommand.Kind, skill: Skill = null) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	command.skill = skill
	return command


func _skill(power: float, target: FactionTable.Target, scope: Skill.Scope) -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture"
	skill.name_key = "fixture.skill"
	skill.power = power
	skill.target = target
	skill.scope = scope
	return skill


func _a_fight_to_victory() -> void:
	Flags.clear_all()
	_ended.clear()
	var hero := _fighter(&"fixture_hero", &"side_a", {&"speed": 10.0, &"attack": 10.0, &"max_hp": 30.0, &"max_mp": 10.0})
	var left := _fighter(&"fixture_left", &"side_b", {&"speed": 5.0, &"attack": 4.0, &"max_hp": 12.0})
	var right := _fighter(&"fixture_right", &"side_b", {&"speed": 3.0, &"attack": 4.0, &"max_hp": 12.0})
	var battle := Battle.new([hero], [left, right], null, RandomNumberGenerator.new())
	battle.start()
	var attack := _command(BattleCommand.Kind.ATTACK)
	equal("the fastest acts first", battle.next_turn(), hero)
	equal("attacking yourself is refused", battle.act(attack, [hero]), false)
	equal("and refusing kept the turn", battle.current(), hero)
	battle.act(attack, [left])
	equal("an attack is the attack stat through the formula: 12 - 10", _hp(left), 2)
	equal("the enemies then act, fastest first", [battle.next_turn(), battle.next_turn()] == [left, right], true)
	var sweep := _skill(4.0, FactionTable.Target.ENEMY, Skill.Scope.ALL)
	sweep.cost_pool = &"mp"
	sweep.cost = 6
	var burst := _command(BattleCommand.Kind.SKILL, sweep)
	battle.next_turn()
	battle.act(burst, [])
	equal("an ALL skill hits every enemy: 2 left falls, 12 - 14 is 0", _hp(left) == 0 and _hp(right) == 0, true)
	equal("and paid its cost", Vitals.of(hero.get_parent()).current(&"mp"), 4)
	equal("no enemy standing is WON, announced once", battle.outcome() == Battle.Outcome.WON and _ended == [Battle.Outcome.WON], true)
	equal("an ended battle has no next turn", battle.next_turn(), null)
	equal("and refuses any command", battle.act(attack, [left]), false)
	_free_all()


func _defend_and_heal() -> void:
	Flags.clear_all()
	var hero := _fighter(&"fixture_guard", &"side_a", {&"speed": 10.0, &"max_hp": 40.0, &"max_mp": 2.0})
	var foe := _fighter(&"fixture_foe", &"side_b", {&"speed": 5.0, &"attack": 20.0, &"max_hp": 50.0})
	var battle := Battle.new([hero], [foe])
	battle.start()
	var poison := StatusEffect.new()
	poison.id = &"status/fixture_mark"
	var dart := _skill(0.0, FactionTable.Target.ENEMY, Skill.Scope.ONE)
	dart.statuses = [poison]
	dart.cost_pool = &"mp"
	dart.cost = 5
	battle.next_turn()
	equal("a skill its user cannot afford is refused", battle.act(_command(BattleCommand.Kind.SKILL, dart), [foe]), false)
	dart.cost = 0
	battle.act(_command(BattleCommand.Kind.SKILL, dart), [foe])
	equal("a skill's status lands at chance 1", StatusSet.of(foe.get_parent()).stacks(poison.id), 1)
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [hero])
	equal("an undefended hit: 40 - 20", _hp(hero), 20)
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.DEFEND), [])
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [hero])
	equal("DEFEND halves the next hit: 20 - 10", _hp(hero), 10)
	battle.next_turn()
	equal("and runs out at the defender's own next turn", StatusSet.of(hero.get_parent()).stacks(&"status/defend"), 0)
	var mend := _skill(-15.0, FactionTable.Target.ALLY, Skill.Scope.ONE)
	battle.act(_command(BattleCommand.Kind.SKILL, mend), [hero])
	equal("a negative power heals, not through defence: 10 + 15", _hp(hero), 25)
	_free_all()


func _defeat_and_flight() -> void:
	Flags.clear_all()
	_ended.clear()
	var hero := _fighter(&"fixture_weak", &"side_a", {&"speed": 1.0, &"max_hp": 5.0})
	var brute := _fighter(&"fixture_brute", &"side_b", {&"speed": 9.0, &"attack": 50.0, &"max_hp": 50.0})
	var battle := Battle.new([hero], [brute])
	battle.start()
	battle.next_turn()
	battle.act(_command(BattleCommand.Kind.ATTACK), [hero])
	equal("no party member standing is LOST", battle.outcome(), Battle.Outcome.LOST)
	Flags.clear_all()
	var runner := _fighter(&"fixture_runner", &"side_a", {&"speed": 9.0, &"max_hp": 5.0})
	var chaser := _fighter(&"fixture_chaser", &"side_b", {&"speed": 1.0, &"max_hp": 5.0})
	var trapped := Battle.new([runner], [chaser])
	trapped.can_flee = false
	trapped.start()
	trapped.next_turn()
	equal("a flee that is not allowed is refused", trapped.act(_command(BattleCommand.Kind.FLEE), []), false)
	var open := Battle.new([runner], [chaser])
	open.start()
	open.next_turn()
	open.act(_command(BattleCommand.Kind.FLEE), [])
	equal("a flee at chance 1 is FLED", open.outcome(), Battle.Outcome.FLED)
	equal("each ending was announced once, in order", _ended, [Battle.Outcome.LOST, Battle.Outcome.FLED])
	_free_all()


func _on_ended(outcome: int) -> void:
	_ended.append(outcome)
