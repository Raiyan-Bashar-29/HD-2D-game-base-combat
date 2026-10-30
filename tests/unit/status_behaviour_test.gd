extends TestCase
## Statuses that change behaviour (C2.14): a sleep that costs exactly its turns, waking on a hit,
## silence and the other command blocks, the AI never choosing a blocked command, resistance
## and immunity, and a field where everyone sleeps not hanging the battle.
##
## OWNS: assertions about what a status stops its holder doing.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []
var _skipped: int = 0
var _resisted: int = 0


func run() -> void:
	plan(16)
	SaveFixture.activate()
	Flags.clear_all()
	Events.turn_skipped.connect(_on_skipped)
	Events.status_resisted.connect(_on_resisted)
	_a_forever_sleep_is_a_problem()
	_sleep_costs_its_turns_and_breaks_on_a_hit()
	_silence_and_the_other_blocks()
	_resistance_and_immunity()
	_everyone_asleep_does_not_hang()
	Events.turn_skipped.disconnect(_on_skipped)
	Events.status_resisted.disconnect(_on_resisted)
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
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


func _status(name: String, blocks: Array[StatusEffect.Block], duration: float) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName("status/" + name)
	made.blocks = blocks
	made.duration = duration
	made.tags = [&"ailment"]
	return made


func _statuses(fighter: Combatant) -> StatusSet:
	return StatusSet.of(fighter.get_parent())


func _command(kind: BattleCommand.Kind) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	if kind == BattleCommand.Kind.SKILL:
		command.skill = Skill.new()
		command.skill.id = &"skill/fixture_bolt"
		command.skill.name_key = "fixture.bolt"
		command.skill.power = 3.0
	return command


func _a_forever_sleep_is_a_problem() -> void:
	var forever := _status("fixture_forever", [StatusEffect.Block.SKIP_TURN], 0.0)
	equal("a turn-skipping status that never ends is a problem", forever.problems().size(), 1)


func _sleep_costs_its_turns_and_breaks_on_a_hit() -> void:
	Flags.clear_all()
	var sleeper := _fighter(&"fixture_sleeper", &"side_a", {&"speed": 10.0, &"max_hp": 50.0})
	var waker := _fighter(&"fixture_waker", &"side_b", {&"speed": 5.0, &"attack": 5.0, &"max_hp": 50.0})
	var battle := Battle.new([sleeper], [waker], null, RandomNumberGenerator.new())
	battle.start()
	_statuses(sleeper).apply(_status("fixture_doze", [StatusEffect.Block.SKIP_TURN], 2.0))
	_skipped = 0
	equal("the faster fighter, asleep, loses its turn", battle.next_turn(), waker)
	equal("and the loss is announced", _skipped, 1)
	battle.act(_command(BattleCommand.Kind.DEFEND), [])
	equal("a two-turn sleep costs a second turn", battle.next_turn(), waker)
	battle.act(_command(BattleCommand.Kind.DEFEND), [])
	equal("then it has worn off and the sleeper acts", battle.next_turn(), sleeper)
	var nap := _status("fixture_nap", [StatusEffect.Block.SKIP_TURN], 9.0)
	nap.breaks_on_hit = true
	_statuses(sleeper).apply(nap)
	waker.hit(sleeper, 1.0, &"", RandomNumberGenerator.new())
	equal("a hit that hurts ends a sleep that breaks on hit", _statuses(sleeper).stacks(nap.id), 0)
	_free_all()


func _silence_and_the_other_blocks() -> void:
	Flags.clear_all()
	var mute := _fighter(&"fixture_mute", &"side_a", {&"speed": 10.0, &"attack": 4.0, &"max_hp": 30.0, &"max_mp": 10.0})
	var foe := _fighter(&"fixture_target", &"side_b", {&"speed": 1.0, &"max_hp": 30.0})
	var battle := Battle.new([mute], [foe], null, RandomNumberGenerator.new())
	battle.start()
	_statuses(mute).apply(_status("fixture_hush", [StatusEffect.Block.NO_SKILLS, StatusEffect.Block.NO_FLEE], 3.0))
	battle.next_turn()
	var spell := _command(BattleCommand.Kind.SKILL)
	equal("silence forbids a SKILL", battle.allows(spell), false)
	equal("and acting with one is refused", battle.act(spell, [foe]), false)
	equal("NO_FLEE forbids fleeing", battle.allows(_command(BattleCommand.Kind.FLEE)), false)
	equal("a plain ATTACK is never blocked", battle.allows(_command(BattleCommand.Kind.ATTACK)), true)
	var brain := BattleBrain.new()
	var entry := BrainEntry.new()
	entry.command = spell
	brain.entries = [entry]
	BattleAi.take_turn(battle, brain)
	equal("the AI never picks a blocked command: it falls back to an attack, 30 - 4",
		Vitals.of(foe.get_parent()).current(&"hp"), 26)
	_free_all()


func _resistance_and_immunity() -> void:
	Flags.clear_all()
	var immune := _fighter(&"fixture_immune", &"side_a", {&"resist_ailment": 1.0})
	var plain := _fighter(&"fixture_plain", &"side_a", {})
	var partial := _fighter(&"fixture_partial", &"side_a", {&"resist_ailment": 0.5})
	var hex := _status("fixture_hex", [StatusEffect.Block.NO_ITEMS], 3.0)
	_resisted = 0
	equal("resistance 1 is immunity", _statuses(immune).apply(hex), false)
	equal("and the shrug is announced", _resisted, 1)
	equal("no resistance lets it land", _statuses(plain).apply(hex), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var landed: int = 0
	for i: int in 200:
		if _statuses(partial).apply(hex, rng):
			landed += 1
		_statuses(partial).cure(hex.id)
	equal("resistance 0.5 stops about half of 200 tries", landed > 60 and landed < 140, true)
	_free_all()


func _everyone_asleep_does_not_hang() -> void:
	Flags.clear_all()
	var one := _fighter(&"fixture_one", &"side_a", {&"speed": 3.0, &"max_hp": 9.0})
	var two := _fighter(&"fixture_two", &"side_b", {&"speed": 2.0, &"max_hp": 9.0})
	var battle := Battle.new([one], [two], null, RandomNumberGenerator.new())
	battle.start()
	var coma := _status("fixture_coma", [StatusEffect.Block.SKIP_TURN], 0.0)
	coma.breaks_on_hit = true
	_statuses(one).apply(coma)
	_statuses(two).apply(coma)
	equal("with everyone asleep for good, next_turn gives up instead of looping", battle.next_turn(), null)
	_free_all()


func _on_skipped(_who: StringName, _status_id: StringName) -> void:
	_skipped += 1


func _on_resisted(_who: StringName, _status_id: StringName) -> void:
	_resisted += 1
