class_name PowerScaling
extends Resource
## One rule that makes a power stronger or weaker by the situation (C6.1a). Phase C6, the hero
## powers, is designed in `docs/POWERS.md`.
##
## IN PLAIN WORDS: "the sun is up, so it hits harder", "the less hp you have left, the longer it
## lasts", "a divine foe is bound for longer". The caller reads the `source` as a number from
## 0 to 1 (how full the user's hp is, how much is missing, how full a pool is, how far through
## the day the clock is, or 1 when the target has the `tag` and 0 when not) and hands it to
## `multiplier`. With a `curve`, the curve gives the multiplier at that point. Without one, it is
## `1 + factor * reading`: a factor of 1 doubles the power at a full reading.
##
## WHAT IT CHANGES (`affects`): the power of each hit, the duration of its statuses, how many
## hits it lands, or the count of something a mechanism makes (projectiles, clones).
##
## OWNS: the shape of one scaling rule and its maths.
## MUST NOT: read a fighter, a pool or the clock itself. The caller does that (C6.1b,
## `PowerUse`), so this stays pure data and a test needs no scene.

## Where the reading comes from.
enum Source {
	USER_HP_FRACTION,  ## The user's hp, 0 (none) to 1 (full).
	USER_MISSING_HP,  ## How much hp the user has lost, 0 (none) to 1 (all).
	POOL_FRACTION,  ## How full the user's `pool` is, 0 to 1.
	CLOCK_CURVE,  ## How far through the day it is, 0 (midnight) to 1; needs a `curve`.
	TARGET_HAS_TAG,  ## 1 when the target holds a status tagged `tag`, else 0.
}

## What the multiplier is applied to.
enum Affects { POWER, DURATION, HITS, COUNT }

@export var source: Source = Source.USER_HP_FRACTION
@export var affects: Affects = Affects.POWER
## The pool POOL_FRACTION reads, such as `mp` or a kit gauge.
@export var pool: StringName = &""
## The status tag TARGET_HAS_TAG looks for.
@export var tag: StringName = &""
## When set, the multiplier at each reading, read across 0 to 1. Required for CLOCK_CURVE.
## A `Curve` clamps its values to `max_value`, which starts at 1: raise it for a multiplier
## above 1, or the curve tops out at 1 without a word.
@export var curve: Curve
## Without a curve, the multiplier is `1 + factor * reading`.
@export var factor: float = 1.0


## The multiplier at `reading` (0 to 1; anything outside is clamped). Never below 0.
func multiplier(reading: float) -> float:
	var at: float = clampf(reading, 0.0, 1.0)
	if curve != null:
		return maxf(0.0, curve.sample(at))
	return maxf(0.0, 1.0 + factor * at)


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if source == Source.CLOCK_CURVE and curve == null:
		found.append("%s scales by the clock but has no curve" % context)
	if source == Source.POOL_FRACTION and pool == &"":
		found.append("%s scales by a pool but names none" % context)
	if source == Source.TARGET_HAS_TAG and tag == &"":
		found.append("%s scales by a target's tag but names none" % context)
	return found
