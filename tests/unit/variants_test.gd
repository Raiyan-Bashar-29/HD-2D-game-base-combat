extends TestCase
## Three combat variants built from parts that already exist (C4.10), one case each:
## - an ATB battle: a turn-based `Battle` whose `CtbScheduler` is fed by fight time (`advance`);
## - pause-and-play: the fight's clock at 0 freezes every foe, while a command still lands;
## - timed hits: a `TimedWindow` turns the moment of a press into a power multiplier.
##
## OWNS: assertions about `CtbScheduler.advance`, `TimedWindow`, and how the three compose.
## MUST NOT: name a game's fighters or skills, or wait for frames.

## How many CTB ticks one second of fight time is worth, as an ATB host would choose.
const TICKS_PER_SECOND: float = 10.0

var _actors: Array[Node] = []


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Flags.clear_all()
	_atb_battle()
	_pause_and_play()
	_timed_hits()
	for actor: Node in _actors:
		if is_instance_valid(actor):
			actor.free()
	CombatClock.reset()
	Flags.clear_all()


func _atb_battle() -> void:
	var hero := _fighter(&"fixture_quick", &"player", 10.0)
	var foe := _fighter(&"fixture_slow", &"enemy", 5.0)
	var battle := Battle.new([hero], [foe], CtbScheduler.new())
	battle.start()
	var turns: CtbScheduler = battle.scheduler as CtbScheduler
	# Speeds 10 and 5 wait 10 and 20 ticks: one second of fight time fills neither gauge.
	equal("before the fastest gauge fills, nobody is ready", turns.advance(_ticks(0.5)), &"")
	var ready: StringName = turns.advance(_ticks(0.5))
	equal("once it fills, the quicker fighter is ready, and the battle gives them the turn",
		[ready, battle.next_turn() == hero], [&"fixture_quick", true])
	equal("the slower gauge filled for the same time meanwhile", turns.wait_of(&"fixture_slow"), 10.0)
	CombatClock.set_scale(0.0)
	equal("with the fight stopped (wait mode, a menu open) no gauge fills",
		[turns.advance(_ticks(5.0)), turns.wait_of(&"fixture_slow")], [&"", 10.0])
	CombatClock.reset()


func _pause_and_play() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_actors.append(player)
	player.global_position = Vector3.ZERO
	var loadout := ActionLoadout.new()
	loadout.fighter = CombatantDef.new()
	loadout.fighter.combatant_id = &"fixture_pauser"
	loadout.fighter.faction = &"player"
	loadout.fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0, &"attack": 5.0}
	loadout.moves = MoveSet.new()
	loadout.atb = AtbRules.new()
	ActionHost.equip(player, loadout)
	AtbMeter.of(player).gauge.gain(200.0)
	var enemy := _enemy(Vector3(0.0, 0.0, -3.0))
	CombatClock.set_scale(0.0)
	enemy.act(0.1)
	equal("with the clock at 0 a foe in sight neither walks nor swings",
		[Vector2(enemy.velocity.x, enemy.velocity.z), enemy.timeline.busy()], [Vector2.ZERO, false])
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	command.skill.id = &"skill/fixture_bolt"
	command.skill.power = 4.0
	command.skill.sure_hit = true
	equal("but a command chosen meanwhile lands at once",
		[FieldCommands.use(Combatant.of(player), command, RandomNumberGenerator.new()),
			Vitals.of(enemy).current(&"hp") < 20], [true, true])
	CombatClock.reset()
	enemy.act(0.1)
	equal("and play resumes: back at full speed it walks at the player",
		Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.0, true)


func _timed_hits() -> void:
	var window := TimedWindow.new()
	window.opens = 0.3
	window.closes = 0.5
	window.bonus = 1.5
	window.perfect = 0.06
	window.perfect_bonus = 2.0
	equal("too early, inside, dead centre, too late",
		[window.multiplier(0.1), window.multiplier(0.32), window.multiplier(0.4), window.multiplier(0.6)],
		[1.0, 1.5, 2.0, 1.0])
	equal("a well-made window has no problems", window.problems("x").size(), 0)
	var broken := TimedWindow.new()
	broken.opens = 0.5
	broken.closes = 0.2
	broken.bonus = -1.0
	equal("one that closes before it opens, with a negative bonus, has both reported",
		broken.problems("x").size(), 3)
	var formula := DamageFormula.new()
	formula.stages = [AttackDefenceStage.new()]
	var attacker := StatSheet.new()
	attacker.set_base(&"attack", 5.0)
	var defender := StatSheet.new()
	defender.set_base(&"defence", 1.0)
	var plain: float = formula.resolve(DamageRequest.of(attacker, defender, 4.0), RandomNumberGenerator.new()).amount
	var timed: float = formula.resolve(DamageRequest.of(attacker, defender, 4.0 * window.multiplier(0.32)),
		RandomNumberGenerator.new()).amount
	equal("the same hit pressed in time lands harder", timed > plain, true)


func _ticks(seconds: float) -> float:
	return CombatClock.scaled(seconds) * TICKS_PER_SECOND


func _fighter(id: StringName, side: StringName, speed: float) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 30.0, &"attack": 3.0, &"speed": speed}
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant


func _enemy(at: Vector3) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_frozen"
	def.faction = &"enemy"
	def.base_stats = {&"max_hp": 20.0, &"attack": 2.0}
	var entry := ActionBrainEntry.new()
	entry.move = ActionMove.new()
	var brain := ActionBrain.new()
	brain.move_speed = 2.0
	brain.wander_radius = 0.0
	brain.moves = [entry]
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	made.position = at
	attach(made)
	_actors.append(made)
	return made
