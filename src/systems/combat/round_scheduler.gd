class_name RoundScheduler
extends TurnScheduler
## The template default: rounds, and in each round everyone acts once, fastest first.
##
## TIES GO TO WHOEVER JOINED FIRST, so the order is fully decided by the roster and needs no
## random draw. A battle that wants random tie-breaks adds a small random speed when it joins.
##
## A ROUND IS ORDERED WHEN IT STARTS. A speed change, a newcomer or a slowed actor takes effect
## from the next round, which is how most round-based games read; anyone who leaves is skipped.
##
## A SKIPPED TURN (C8.21): `skip_next` makes a fighter's next place in the order pass it by.
##
## OWNS: the order of the current round and the round count.
## MUST NOT: let anyone act twice in a round.

var _queue: Array[StringName] = []
var _round: int = 0
var _skips: Dictionary[StringName, int] = {}


## `id` loses its next turn in the order, as a team tech's partner does (C8.21).
func skip_next(id: StringName) -> void:
	_skips[id] = _skips.get(id, 0) + 1


func next() -> StringName:
	var owed: StringName = _take_owed()
	if owed != &"":
		return owed
	while true:
		_skip_departed()
		if _queue.is_empty():
			_queue = _ordered()
			if _queue.is_empty():
				return &""
			_round += 1
		var id: StringName = _queue.pop_front()
		if _skips.get(id, 0) <= 0:
			return id
		_skips[id] -= 1
	return &""


func preview(count: int) -> Array[StringName]:
	var out: Array[StringName] = _owed_preview(count)
	var order: Array[StringName] = _ordered()
	if order.is_empty():
		return out
	for id: StringName in _queue:
		if out.size() >= count:
			return out
		if has(id):
			out.append(id)
	while out.size() < count:
		for id: StringName in order:
			if out.size() >= count:
				break
			out.append(id)
	return out


## Which round the last `next()` belongs to: 1 for the first, 0 before anyone has acted.
func round_number() -> int:
	return _round


func _skip_departed() -> void:
	while not _queue.is_empty() and not has(_queue[0]):
		_queue.pop_front()


func _ordered() -> Array[StringName]:
	var order: Array[StringName] = _ids.duplicate()
	var position: Dictionary[StringName, int] = {}
	for i: int in order.size():
		position[order[i]] = i
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		if speed_of(a) != speed_of(b):
			return speed_of(a) > speed_of(b)
		return position[a] < position[b])
	return order
