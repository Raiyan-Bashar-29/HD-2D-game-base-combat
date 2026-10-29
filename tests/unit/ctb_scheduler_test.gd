extends TestCase
## `CtbScheduler`, the second `TurnScheduler`: a fast actor acting twice, `delay_by`, and a speed
## of zero. Then the ORDER CONTRACT both schedulers must keep, run unchanged against each, which
## is what proves the scheduler is a swap point and not two different APIs.
##
## OWNS: assertions about the CTB order, and about what every scheduler promises.
## MUST NOT: name a game's combatants. Every id here is made up for the case.


func run() -> void:
	plan(15)
	_twice_as_fast_acts_twice()
	_delay_by_pushes_back()
	_speed_zero_never_acts()
	for turns: TurnScheduler in [RoundScheduler.new(), CtbScheduler.new()]:
		_the_contract(turns)


func _take(turns: TurnScheduler, count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in count:
		out.append(turns.next())
	return out


func _twice_as_fast_acts_twice() -> void:
	var turns := CtbScheduler.new()
	turns.join(&"slow", 5.0)
	turns.join(&"fast", 10.0)
	equal("twice the speed acts twice per slow turn, ties to the first to join",
			_take(turns, 6), [&"fast", &"slow", &"fast", &"fast", &"slow", &"fast"])


func _delay_by_pushes_back() -> void:
	var turns := CtbScheduler.new()
	turns.join(&"one", 10.0)
	turns.join(&"two", 10.0)
	turns.delay_by(&"one", 5.0)
	equal("a pushed-back actor loses its tie", turns.next(), &"two")
	equal("and its remaining wait is what was pushed", is_equal_approx(turns.wait_of(&"one"), 5.0), true)
	turns.delay_by(&"one", -50.0)
	equal("a pull forward never goes below zero", turns.wait_of(&"one"), 0.0)


func _speed_zero_never_acts() -> void:
	var turns := CtbScheduler.new()
	turns.join(&"frozen", 0.0)
	turns.join(&"moving", 1.0)
	equal("speed 0 never acts", _take(turns, 3), [&"moving", &"moving", &"moving"])


func _the_contract(turns: TurnScheduler) -> void:
	var kind: String = (turns.get_script() as Script).get_global_name()
	equal(kind + ": nobody in the battle means no turn", turns.next(), &"")
	turns.join(&"alpha", 9.0)
	turns.join(&"beta", 6.0)
	turns.join(&"gamma", 3.0)
	equal(kind + ": the fastest acts first", turns.next(), &"alpha")
	var seen: Array[StringName] = turns.preview(6)
	equal(kind + ": preview agrees with next", _take(turns, 6), seen)
	turns.leave(&"beta")
	equal(kind + ": someone who left never acts again", _take(turns, 6).has(&"beta"), false)
	equal(kind + ": and is not in the roster", turns.has(&"beta"), false)
