class_name GaugeRule
extends Resource
## How one of a kit's gauges fills and drains (C6.4a, mechanism M6): the generalisation of the
## ATB rules (C4.2) to any pool. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: a gauge is an ordinary pool (`Vitals`), such as `zantetsuken` or `arts`. The kit
## gives it its size with a `max_<pool>` stat bonus, and `start_<pool>` 0 makes it start empty.
## This rule says what moves it: so many points a second, a turn, a second standing still or
## moving, and so many for each hit landed, hit taken, attack dodged and attack missed. A negative
## amount drains. Fractions are kept until they make a whole point, so +7 a second really is +7.
##
## LEVELS: `levels` maps a number of points to a status. While the pool holds at least that
## many, the status of the highest level reached is held and the others are not (Concentration's
## three ranks, a style rank). Put a pool's levels on one of its rules only.
##
## BLOCKED: while the holder has any status carrying one of `blocked_by_tags`, this rule does
## nothing at all, fill or drain ("+7 a second while free of ailments").
##
## OWNS: the numbers.
## MUST NOT: hold a fighter's current fill. The pool is in `Vitals`; `KitGauges` moves it.

## The happenings a rule can answer, besides the passing of time.
enum Event {HIT_DEALT, HIT_TAKEN, DODGE, MISS}

## The pool this rule moves.
@export var pool: StringName = &""
## Points a second of fight time, in the field.
@export var per_second: float = 0.0
## Points at the start of each of the holder's turns, in a battle.
@export var per_turn: float = 0.0
## Points a second while standing still, in the field.
@export var per_idle_second: float = 0.0
## Points a second while moving, in the field.
@export var per_moving_second: float = 0.0
## Points for each hit the holder lands.
@export var on_hit_dealt: float = 0.0
## Points for each hit that hurts the holder.
@export var on_hit_taken: float = 0.0
## Points for each attack the holder dodges.
@export var on_dodge: float = 0.0
## Points for each attack of the holder's that misses.
@export var on_miss: float = 0.0
## While a status with any of these tags is held, this rule is paused.
@export var blocked_by_tags: Array[StringName] = []
## Points reached -> the status held from there up to the next level.
@export var levels: Dictionary[int, StatusEffect] = {}


## The points `event` is worth under this rule.
func amount(event: Event) -> float:
	match event:
		Event.HIT_DEALT:
			return on_hit_dealt
		Event.HIT_TAKEN:
			return on_hit_taken
		Event.DODGE:
			return on_dodge
		Event.MISS:
			return on_miss
	return 0.0


## The status of the highest level at or below `points`, or null below the first.
func level_at(points: int) -> StatusEffect:
	var best: int = -1
	for at: int in levels:
		if at <= points and at > best:
			best = at
	return levels[best] if best >= 0 else null


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s gauge %s" % [context, pool]
	if pool == &"":
		found.append("%s names no pool" % where)
	for at: int in levels:
		if at < 0:
			found.append("%s has a level below 0 points" % where)
		if levels[at] == null:
			found.append("%s has an empty level at %d" % [where, at])
		else:
			found.append_array(levels[at].problems())
	return found
