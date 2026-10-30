class_name AtbGauge
extends RefCounted
## One fighter's ATB gauge (C4.2): points that fill, counted in whole bars, spent in whole bars.
##
## IN PLAIN WORDS: with the default rules the gauge holds two bars of 100 points. `fill` adds
## the passive points for some seconds of fight time, `gain` adds a reward (a hit landed, a
## dodge), and neither goes past the top. A command costs whole bars: `spend(1)` takes 100
## points and leaves any part-filled bar where it was, as FF7 Remake does.
##
## IT IS PURE. No node, no clock: `AtbMeter` decides when time passes and when a reward is due,
## and a test steps it by hand.
##
## OWNS: the fill and the arithmetic of bars.
## MUST NOT: decide what a bar buys. The field command rules (C4.3) and their menu (C4.4) do.

var rules: AtbRules
## Points held, from 0 to `capacity()`.
var value: float = 0.0


func _init(with_rules: AtbRules = null) -> void:
	rules = with_rules if with_rules != null else AtbRules.new()


## The most points the gauge can hold: every bar full.
func capacity() -> float:
	return float(rules.segments) * rules.segment_size


## `seconds` of fight time pass.
func fill(seconds: float) -> void:
	gain(rules.per_second * maxf(0.0, seconds))


## Adds `points`, capped at the top and never below empty.
func gain(points: float) -> void:
	value = clampf(value + points, 0.0, capacity())


## How many whole bars are full.
func full_segments() -> int:
	return floori(value / rules.segment_size + 0.000001)


func can_spend(bars: int) -> bool:
	return bars >= 0 and full_segments() >= bars


## Spends `bars` whole bars; false, and nothing spent, when there are not enough.
func spend(bars: int) -> bool:
	if not can_spend(bars):
		return false
	value -= float(bars) * rules.segment_size
	return true


## How full the gauge is, from 0 to 1.
func fraction() -> float:
	return value / capacity() if capacity() > 0.0 else 0.0
