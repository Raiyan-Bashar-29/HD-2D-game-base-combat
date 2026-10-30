class_name TimedWindow
extends Resource
## A timed hit (C4.10), as in the Mario RPGs or Sea of Stars: press the button at the right
## moment of a move and it lands harder. Pure: it only turns "when was it pressed" into a power
## multiplier, so any formula can use it.
##
## IN PLAIN WORDS: the window opens `opens` seconds after the move starts and closes at
## `closes`. A press inside it multiplies the power by `bonus`. When `perfect` is above 0, the
## middle `perfect` seconds of the window are a tighter target worth `perfect_bonus`. A press
## outside the window, too early or too late, changes nothing.
##
## Example: a sword swing with `opens` 0.3, `closes` 0.5, `bonus` 1.5 and `perfect` 0.06 gives
## x1.5 for a press between 0.3 s and 0.5 s, and `perfect_bonus` between 0.37 s and 0.43 s.
##
## OWNS: one window's timing and multipliers.
## MUST NOT: read input, time a move, or deal damage. The caller does those and multiplies.

@export var opens: float = 0.3
@export var closes: float = 0.5
@export var bonus: float = 1.5
## The width of the perfect centre, in seconds. 0 means there is none.
@export var perfect: float = 0.0
@export var perfect_bonus: float = 2.0


## The power multiplier for a press `pressed_at` seconds after the move started: 1.0 outside
## the window, `bonus` inside it, `perfect_bonus` in its centre.
func multiplier(pressed_at: float) -> float:
	if pressed_at < opens or pressed_at > closes:
		return 1.0
	if perfect > 0.0:
		var middle: float = (opens + closes) / 2.0
		if absf(pressed_at - middle) <= perfect / 2.0:
			return perfect_bonus
	return bonus


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if closes < opens:
		found.append("%s closes before it opens, so no press ever lands in it" % context)
	if bonus < 0.0 or perfect_bonus < 0.0:
		found.append("%s has a negative bonus" % context)
	if perfect > closes - opens:
		found.append("%s has a perfect centre wider than the window" % context)
	return found
