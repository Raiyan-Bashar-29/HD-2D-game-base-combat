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
## MORE HAPPENINGS (C6.4b): a foe the holder finishes off (`on_kill`), an ally of the holder
## falling (`on_ally_defeated`), a move started that differs from the one before (`on_new_move`,
## as a style rank counts; the field only, a battle has no moves), and points of another pool
## paid as a cost (`on_spent` for each point of `spent_pool`: "+1 true arts per 3 arts spent" is
## `spent_pool arts`, `on_spent 0.3334`). A PERFECT DODGE (C6.6c, the field only) gives
## `on_perfect_dodge` on top of `on_dodge`, since it is a dodge too.
##
## RUNNING: `per_running_second` is ADDED to `per_moving_second` while the player runs, because a
## run is a fast move. "+4 walking, -15 running" is `per_moving_second 4`, `per_running_second -19`.
##
## BLOCKED: while the holder has any status carrying one of `blocked_by_tags`, this rule does
## nothing at all, fill or drain ("+7 a second while free of ailments").
##
## OWNS: the numbers.
## MUST NOT: hold a fighter's current fill. The pool is in `Vitals`; `KitGauges` moves it.

## The happenings a rule can answer, besides the passing of time.
enum Event {HIT_DEALT, HIT_TAKEN, DODGE, MISS, KILL, ALLY_DEFEATED, NEW_MOVE, PERFECT_DODGE}

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
## Points a second while running, on top of `per_moving_second`, in the field.
@export var per_running_second: float = 0.0
## Points for each hit the holder lands.
@export var on_hit_dealt: float = 0.0
## Points for each hit that hurts the holder.
@export var on_hit_taken: float = 0.0
## Points for each attack the holder dodges.
@export var on_dodge: float = 0.0
## Points for each attack the holder dodges perfectly, on top of `on_dodge`.
@export var on_perfect_dodge: float = 0.0
## Points for each attack of the holder's that misses.
@export var on_miss: float = 0.0
## Points for each foe the holder's hit defeats.
@export var on_kill: float = 0.0
## Points each time one of the holder's allies falls.
@export var on_ally_defeated: float = 0.0
## Points for each move started that differs from the one before, in the field.
@export var on_new_move: float = 0.0
## The pool whose spending moves this rule.
@export var spent_pool: StringName = &""
## Points for each point of `spent_pool` paid as a cost.
@export var on_spent: float = 0.0
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
		Event.KILL:
			return on_kill
		Event.ALLY_DEFEATED:
			return on_ally_defeated
		Event.NEW_MOVE:
			return on_new_move
		Event.PERFECT_DODGE:
			return on_perfect_dodge
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
	if on_spent != 0.0 and spent_pool == &"":
		found.append("%s fills on spending but names no pool spent" % where)
	for at: int in levels:
		if at < 0:
			found.append("%s has a level below 0 points" % where)
		if levels[at] == null:
			found.append("%s has an empty level at %d" % [where, at])
		else:
			found.append_array(levels[at].problems())
	return found
