class_name Flourish
extends Node
## A moment when the whole fight stands still (C6.8): `CombatClock` at 0 for `seconds` of real
## time, then the fight runs again at the speed it had and `finished` is said.
##
## IN PLAIN WORDS: a finisher's time-stop finale. The user's strike is held back while every
## fighter, shot and status stands frozen; when the moment is over the fight resumes and the
## finisher lands its strike. It counts real time, not fight time, or it would never end.
##
## Freed early (the kit came off, the area changed), it still gives the fight its time back.
##
## OWNS: one frozen moment and putting the clock back after it.
## MUST NOT: strike anyone (the finisher does), or touch the game's own pause.

## The moment is over and the fight runs again.
signal finished

## Real seconds left.
var seconds: float = 0.0

var _before: float = 1.0
var _over: bool = false


func _ready() -> void:
	_before = CombatClock.scale
	CombatClock.set_scale(0.0)


func _process(delta: float) -> void:
	wait(delta)


## `real` seconds of real time pass. At the end the fight runs again and `finished` is said.
func wait(real: float) -> void:
	if _over:
		return
	seconds -= real
	if seconds > 0.0:
		return
	_give_back()
	finished.emit()
	queue_free()


## True once the fight runs again.
func over() -> bool:
	return _over


func _exit_tree() -> void:
	_give_back()


func _give_back() -> void:
	if _over:
		return
	_over = true
	CombatClock.set_scale(_before)
