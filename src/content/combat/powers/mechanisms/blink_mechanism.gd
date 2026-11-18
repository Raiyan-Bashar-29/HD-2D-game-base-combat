class_name BlinkMechanism
extends PowerMechanism
## M9, a blink (C6.12a): the user is somewhere else at once. See `docs/POWERS.md` § M9.
##
## IN PLAIN WORDS, IN THE FIELD: using the power moves the user's body, with no travel time:
## - TARGET: to `distance` metres in front of the aimed fighter, facing it;
## - BEHIND_TARGET: to `distance` metres behind it, facing its back;
## - FORWARD: `distance` metres the way the user faces;
## - UP: `height` metres straight up, to fall back down (an air trick);
## - SWAP: the user and the aimed fighter trade places.
## The aimed fighter is the power's target, else the lock-on, else the nearest foe. With none,
## TARGET, BEHIND_TARGET and SWAP do nothing. `cancels_recovery` ends the move the user was
## playing, so the next one may start at once. A `path_strike` hits each foe the user passes
## through on the way, once. `arrival` is a status put on the user when it lands: give it
## `invincible` and a short SECONDS duration for i-frames, or an evasion stat. A TURNS
## `arrival` is a problem: the field never counts turns, so it would never run out (C8.27a).
##
## IN A BATTLE nothing stands anywhere: the user's next turn comes `sooner` ticks earlier in a
## CTB battle (a round battle ignores it), and `battle_arrival` is put on the user (a TURNS
## status, evasion until the next turn), else `arrival`. SWAP trades the user's and the target's places in the turn order. A
## `path_strike` hits the aimed foe.
##
## OWNS: the shape of a blink.
## MUST NOT: hold running state. `BlinkRun` (gameplay) runs it.

enum To { TARGET, BEHIND_TARGET, FORWARD, UP, SWAP }

@export var to: To = To.FORWARD
## FORWARD: metres moved. TARGET and BEHIND_TARGET: metres from the target.
@export var distance: float = 4.0
## UP: metres risen.
@export var height: float = 3.0
## True: the move the user was playing ends, so the next may start at once.
@export var cancels_recovery: bool = false
## A battle: CTB ticks the user's next turn comes sooner.
@export var sooner: float = 0.0
## Put on the user when it lands. Null for none.
@export var arrival: StatusEffect
## Put on the user instead of `arrival` in a turn-based battle, counted in TURNS. Null: `arrival`.
@export var battle_arrival: StatusEffect
## Hits each foe passed through on the way (the aimed foe in a battle). Null for none.
@export var path_strike: ActionMove
## How wide the path is that `path_strike` sweeps, in metres.
@export var path_width: float = 1.0


func kind() -> StringName:
	return &"blink"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	for effect: StatusEffect in [arrival, battle_arrival]:
		if effect != null:
			out.append(effect)
	return out


## A blink to a target, a swap or a striking path is aimed, so a battle offers targets.
func aims_at_foes() -> bool:
	return to == To.TARGET or to == To.BEHIND_TARGET or to == To.SWAP or path_strike != null


## An aimed blink goes to, or strikes along the way to, one foe (C10.1).
func aims_at_one() -> bool:
	return aims_at_foes()


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if distance < 0.0 or height < 0.0 or sooner < 0.0 or path_width <= 0.0:
		found.append("%s has a negative distance, height or sooner, or no path width" % context)
	if to == To.UP and height <= 0.0:
		found.append("%s blinks up by no height" % context)
	if arrival != null and arrival.unit == StatusEffect.Unit.TURNS and arrival.duration > 0.0:
		found.append("%s arrival counts in turns and would never run out in the field" % context)
	for effect: StatusEffect in statuses():
		found.append_array(effect.problems())
	if path_strike != null:
		found.append_array(path_strike.problems("%s path_strike" % context))
	return found
