class_name TurnScheduler
extends Resource
## Decides whose turn it is. THE TURN-BASED FORMULA'S SWAP POINT: a battle asks only `next()`
## and `preview()`, so speed-sorted rounds, a CTB queue or a game's own rule all plug in by
## choosing a different subclass in data.
##
## IT ORDERS IDS BY A NUMBER, AND KNOWS NOTHING ELSE. No `Combatant`, no `Vitals`, no clock: a
## battle (C2.4) tells it who joined, who left and how fast each one is. That keeps it a system,
## below gameplay, and lets a test drive one with three made-up ids.
##
## THE BASE KEEPS THE ROSTER; a subclass decides the order. `join`, `leave`, `speed_of` and
## `has` are shared, so every scheduler agrees on who is in the battle.
##
## A BATTLE OWNS ITS OWN COPY. The roster is runtime state, so a battle takes a fresh one with
## `duplicate()`, and two battles authored with the same `.tres` never share a queue.
##
## AN EXTRA TURN FOR A WEAKNESS HIT (C8.1, "one more"): with `weakness_extra_turns` above 0,
## `again(id)` owes `id` one more turn, taken before the usual order goes on. Each subclass's
## `next()` asks `_take_owed()` first and its `preview()` starts from `_owed_preview()`. Extra
## turns in a row stop at `weakness_extra_turns`, and one turn earns at most one.
##
## A HAND-OVER (C8.27b): `hand_over` puts a newcomer in a leaver's place in the order, so a free
## swap costs the one coming in no turn. Each subclass also hands over its own queue or wait.
##
## OWNS: who is in the queue, each one's speed, and the order they act in.
## MUST NOT: know what a turn does, read stats itself, or use the global random generator.

## How many extra turns in a row a weakness hit can earn (C8.1). 0 is off.
@export var weakness_extra_turns: int = 0

var _ids: Array[StringName] = []
var _owed: Array[StringName] = []
var _chain: int = 0
var _speeds: Dictionary[StringName, float] = {}


## Adds `id`, or updates its speed if it is already in. A newcomer acts from the next ordering
## its subclass makes, never in the middle of the current one.
func join(id: StringName, speed: float) -> void:
	if not _speeds.has(id):
		_ids.append(id)
	_speeds[id] = maxf(0.0, speed)


## Removes `id`. A defeated or fled actor leaves, and is skipped if it was already queued.
func leave(id: StringName) -> void:
	_ids.erase(id)
	_speeds.erase(id)


## `in_id`, not in the battle yet, takes `out_id`'s place in the order with `speed`. False,
## changing nothing, when `out_id` is not in or `in_id` already is.
func hand_over(out_id: StringName, in_id: StringName, speed: float) -> bool:
	var at: int = _ids.find(out_id)
	if at < 0 or has(in_id):
		return false
	_ids[at] = in_id
	_speeds.erase(out_id)
	_speeds[in_id] = maxf(0.0, speed)
	return true


func has(id: StringName) -> bool:
	return _speeds.has(id)


func speed_of(id: StringName) -> float:
	return _speeds.get(id, 0.0)


## Who acts now, consuming the turn. Empty when nobody is left.
func next() -> StringName:
	return &""


## The next `count` turns, without consuming any. The turn-order strip draws this, so it must
## agree with what `next()` will answer.
func preview(_count: int) -> Array[StringName]:
	return []


## Owes `id` one more turn after this one (C8.1). False when the rule is off, `id` is not in
## the battle, it is already owed one, or the extra turns in a row are used up.
func again(id: StringName) -> bool:
	if weakness_extra_turns <= 0 or not has(id) or _owed.has(id) or _chain >= weakness_extra_turns:
		return false
	_owed.append(id)
	return true


## The next owed turn, consumed; empty when none is owed, which also ends a chain.
func _take_owed() -> StringName:
	while not _owed.is_empty():
		var id: StringName = _owed.pop_front()
		if has(id):
			_chain += 1
			return id
	_chain = 0
	return &""


## The owed turns still to come, for the front of a preview.
func _owed_preview(count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _owed:
		if out.size() < count and has(id):
			out.append(id)
	return out
