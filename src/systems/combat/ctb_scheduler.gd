class_name CtbScheduler
extends TurnScheduler
## Conditional turn-based order, as in Final Fantasy X: no rounds, only a queue of waits.
##
## EACH ACTOR WAITS `delay / speed` TICKS between turns. Whoever's wait runs out first acts,
## every other wait drops by the same amount, and the actor's own wait starts again. A fast actor
## therefore acts twice before one half its speed acts once, which a round never allows.
##
## TIES GO TO WHOEVER JOINED FIRST, the same rule as `RoundScheduler`, so no random draw is
## needed. `delay_by` is the seam a heavy skill or a slowing status pushes an actor back with.
##
## A SPEED CHANGE COUNTS FROM THE ACTOR'S NEXT TURN. Joining again with a new speed keeps the
## wait already running; the new speed sets the wait after it acts. An actor with speed 0 never
## acts.
##
## A CLOCK-FED ATB BATTLE (C4.10), as in the classic Final Fantasy games, is this same queue
## with the ticks fed by time: each frame a host calls `advance(CombatClock.scaled(delta) *
## ticks_per_second)`, and when it names someone, that fighter's gauge is full and the host
## calls the battle's `next_turn()`. Holding the clock at 0 while a menu is open is "wait" mode:
## nothing fills. `next()` alone, with no `advance`, is still plain CTB.
##
## OWNS: each actor's remaining wait.
## MUST NOT: know what a tick is in seconds. A tick is an ordering unit, not time; whoever feeds
## `advance` decides how many ticks a second is worth.

## The wait, in ticks, of an actor with speed 1. Only the ratios between speeds matter to the
## order; this sets the scale `delay_by` is measured in.
@export var delay: float = 100.0

const _EPSILON: float = 0.000001

var _wait: Dictionary[StringName, float] = {}


func join(id: StringName, speed: float) -> void:
	var fresh: bool = not has(id)
	super(id, speed)
	if fresh:
		_wait[id] = _full_wait(id)


func leave(id: StringName) -> void:
	super(id)
	_wait.erase(id)


## Pushes `id` back by `ticks`, or forward with a negative number, never below zero.
func delay_by(id: StringName, ticks: float) -> void:
	if _wait.has(id):
		_wait[id] = maxf(0.0, _wait[id] + ticks)


## Lets `ticks` of time pass: every wait drops by that much, never below 0. Returns who is
## ready to act now (the one `next()` would answer, once their wait has run out), or `&""` while
## nobody is. Nothing is consumed: the turn itself is still taken with `next()`, which, with
## that wait already at 0, moves nobody else on.
func advance(ticks: float) -> StringName:
	for id: StringName in _ids:
		_wait[id] = maxf(0.0, _wait[id] - maxf(0.0, ticks))
	var id: StringName = _soonest(_wait)
	if id != &"" and _wait[id] <= _EPSILON:
		return id
	return &""


## The ticks before `id` acts. Infinite for an actor who never will.
func wait_of(id: StringName) -> float:
	return _wait.get(id, INF)


func next() -> StringName:
	var id: StringName = _soonest(_wait)
	if id == &"":
		return id
	var step: float = _wait[id]
	for other: StringName in _ids:
		_wait[other] = maxf(0.0, _wait[other] - step)
	_wait[id] = _full_wait(id)
	return id


func preview(count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var waits: Dictionary[StringName, float] = _wait.duplicate()
	while out.size() < count:
		var id: StringName = _soonest(waits)
		if id == &"":
			break
		var step: float = waits[id]
		for other: StringName in _ids:
			waits[other] = maxf(0.0, waits[other] - step)
		waits[id] = _full_wait(id)
		out.append(id)
	return out


func _full_wait(id: StringName) -> float:
	var speed: float = speed_of(id)
	return INF if speed <= 0.0 else delay / speed


func _soonest(waits: Dictionary[StringName, float]) -> StringName:
	var best: StringName = &""
	var best_wait: float = INF
	for id: StringName in _ids:
		var wait: float = waits[id]
		if is_inf(wait):
			continue
		if best == &"" or wait < best_wait - _EPSILON:
			best = id
			best_wait = wait
	return best
