class_name FighterTime
extends RefCounted
## One fighter's own time speed (C8.11a), read beside `CombatClock`.
##
## IN PLAIN WORDS: the stat `time_rate` on a fighter's sheet changes how fast its own fight time
## runs: ADD -0.5 is half speed, ADD 1 is double, and -1 (or lower) stops it dead. So a time stop
## is a status with a `time_rate` -1 modifier put on everyone but its user, and a haste one with
## +0.5. `rate` is 1 plus that stat, never below 0. A fighter's moves, stun, walking, its shots
## and blasts, its ghost and its ATB run at it. Its statuses do NOT: they count on the fight's
## clock, so a time stop wears off on time.
##
## OWNS: reading one fighter's time speed.
## MUST NOT: change `CombatClock`, which is the whole fight's, or hold any state.

const STAT: StringName = &"time_rate"


## How fast `body`'s own time runs: 1 normal, 0 stopped. 1 for anything that is not a fighter.
static func rate(body: Node) -> float:
	var me: Combatant = Combatant.of(body) if body != null and is_instance_valid(body) else null
	if me == null:
		return 1.0
	return maxf(0.0, 1.0 + me.sheet.value(STAT))


## How fast the fighter behind `attacker` runs: for its shots and blasts.
static func of_attacker(attacker: Combatant) -> float:
	if attacker == null or not is_instance_valid(attacker):
		return 1.0
	return rate(attacker.get_parent())
