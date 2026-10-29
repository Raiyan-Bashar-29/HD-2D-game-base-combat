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
## OWNS: who is in the queue, each one's speed, and the order they act in.
## MUST NOT: know what a turn does, read stats itself, or use the global random generator.

var _ids: Array[StringName] = []
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
