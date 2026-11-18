class_name AtbClock
extends Node
## ATB time on the battle screen (C10.30), as in the classic Final Fantasy games.
##
## IN PLAIN WORDS: in an encounter whose `turn_order` is ATB, real time fills each fighter's
## gauge: every frame feeds the battle's CTB queue `atb_ticks_per_second` ticks a second, and the
## screen takes the next turn only when someone's gauge is full (`ready`). With wait mode on (the
## `combat/wait_mode` setting), the clock stops while a member's menu is open. ROUNDS and plain
## CTB encounters are untouched.
##
## OWNS: feeding time to the queue, and saying when a turn may start.
## MUST NOT: take a turn itself (the screen's `advance` does) or change the order's rules.

## The screen whose battle it times.
var screen: BattleScreen


## A clock for `on`, a battle screen.
static func for_screen(on: BattleScreen) -> AtbClock:
	var made := AtbClock.new()
	made.screen = on
	return made


## True when `battle` runs on ATB time.
static func timed(battle: Battle) -> bool:
	return battle != null and battle.encounter != null and battle.encounter.turn_order == Encounter.TurnOrder.ATB \
			and battle.scheduler is CtbScheduler


## True when `battle` may take its next turn now: always, unless it runs on ATB time and nobody's
## gauge is full yet.
static func ready(battle: Battle) -> bool:
	return not timed(battle) or (battle.scheduler as CtbScheduler).advance(0.0) != &""


func _process(delta: float) -> void:
	step(delta)


## `seconds` of real time pass: the gauges fill, and a full one starts its turn.
func step(seconds: float) -> void:
	var battle: Battle = screen.battle if screen != null else null
	if not timed(battle) or battle.outcome() != Battle.Outcome.ONGOING:
		return
	if battle.current() != null and CombatSettings.is_on(CombatSettings.WAIT_MODE):
		return
	var full: StringName = (battle.scheduler as CtbScheduler).advance(seconds * battle.encounter.atb_ticks_per_second)
	if full != &"" and battle.current() == null:
		screen.advance()
