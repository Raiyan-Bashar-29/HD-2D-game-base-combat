extends TestCase
## An extra turn for a weakness hit (C8.1, "one more"). The turn order owes a fighter one more
## turn when its rule is on, gives it before the usual order, shows it first in the preview,
## and stops at the rule's count in a row. In a battle, hitting a foe's weakness in your turn
## earns the next turn too, says so, and an ally's weakness does not.
##
## OWNS: assertions about `TurnScheduler.again` and `Weakness`'s one-more rule.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

const HERO: StringName = &"fixture_one_more_hero"
const FOE: StringName = &"fixture_one_more_foe"
const NOON: float = 12.0

var _earned: Array[StringName] = []


func run() -> void:
	plan(5)
	_orders()
	_in_a_battle()


func _orders() -> void:
	var rounds := RoundScheduler.new()
	rounds.join(&"a", 10.0)
	rounds.join(&"b", 9.0)
	rounds.join(&"c", 8.0)
	equal("with the rule off, nobody is owed a turn", rounds.again(&"a"), false)
	rounds.weakness_extra_turns = 1
	var first: StringName = rounds.next()
	var owed: bool = rounds.again(first)
	equal("with it on, the one who just acted goes again, shown first in the preview",
		[owed, rounds.preview(1), rounds.next()], [true, [first], first])
	var ctb := CtbScheduler.new()
	ctb.weakness_extra_turns = 1
	ctb.join(&"x", 10.0)
	ctb.join(&"y", 5.0)
	var acted: StringName = ctb.next()
	equal("an extra turn cannot chain past the rule's count, in CTB too",
		[rounds.again(first), ctb.again(acted), ctb.next(), ctb.again(acted)], [false, true, acted, false])


func _in_a_battle() -> void:
	var holder := Node.new()
	attach(holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_one_more"
	encounter.weakness_extra_turns = 1
	var foe: CombatantDef = _def(FOE, &"side_b")
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var built: Battle = BattleSetup.build(encounter, [_def(HERO, &"side_a")], holder, rng)
	var hero: Combatant = built.party[0]
	var enemy: Combatant = built.enemies[0]
	enemy.weak_to = [&"fixture_fire"]
	hero.weak_to = [&"fixture_fire"]
	while built.next_turn() != hero:
		built.act(_defend(), [])
	Events.extra_turn_earned.connect(_on_earned)
	Weakness.strike(hero, [&"fixture_fire"])
	var after_ally: Array[StringName] = _earned.duplicate()
	Weakness.strike(enemy, [&"fixture_fire"])
	Events.extra_turn_earned.disconnect(_on_earned)
	built.act(_defend(), [])
	equal("a weakness hit on a foe earns the next turn and is announced; hitting your own side's does not",
		[after_ally, _earned, built.next_turn()], [[], [HERO], hero])
	equal("the encounter's rule reached the battle's turn order", built.scheduler.weakness_extra_turns, 1)
	BattleSetup.release(built)
	holder.free()


func _on_earned(who: StringName) -> void:
	_earned.append(who)


func _defend() -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.DEFEND
	return command


func _def(id: StringName, side: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0, &"speed": 10.0 if id == HERO else 1.0}
	def.level_curve = LevelCurve.new()
	return def
