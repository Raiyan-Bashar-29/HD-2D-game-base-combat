class_name AtbRules
extends Resource
## How a fighter's ATB gauge fills (C4.2): the swap point for the hybrid formula's pace.
##
## IN PLAIN WORDS: the gauge has `segments` bars of `segment_size` points each. It fills a
## little every second on its own, and faster when the fighter fights well: each hit it lands
## and each attack it dodges adds points. A command in the hybrid's menu (C4.3) costs whole
## bars. Raise `per_second` for a calmer game, raise `on_hit_dealt` for an aggressive one.
##
## OWNS: the numbers.
## MUST NOT: hold a fighter's current fill. `AtbGauge` does that, one per fighter.

## How many bars the gauge has.
@export var segments: int = 2
## Points in one bar.
@export var segment_size: float = 100.0
## Points gained per second of fight time, doing nothing.
@export var per_second: float = 4.0
## Points gained for each hit this fighter lands.
@export var on_hit_dealt: float = 12.0
## Points gained for each attack this fighter dodges.
@export var on_dodge: float = 10.0


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if segments < 1 or segment_size <= 0.0:
		found.append("%s has no bars to fill" % context)
	if per_second < 0.0 or on_hit_dealt < 0.0 or on_dodge < 0.0:
		found.append("%s has a negative fill rate" % context)
	return found
