extends TestCase
## `RoundScheduler`, the default `TurnScheduler`: speed order, ties, leaving and joining mid-round,
## a preview that agrees with what `next()` then answers, and a hand-over (C8.27b).
##
## OWNS: assertions about turn order.
## MUST NOT: name a game's combatants. Every id here is made up for the case.


func run() -> void:
	plan(14)
	_fastest_first()
	_ties_go_to_the_first_to_join()
	_leaving_mid_round_is_skipped()
	_joining_waits_for_the_next_round()
	_preview_agrees_with_next()
	_an_empty_battle_has_no_turn()
	_a_hand_over_keeps_the_place()


func _three() -> RoundScheduler:
	var turns := RoundScheduler.new()
	turns.join(&"slow", 3.0)
	turns.join(&"fast", 9.0)
	turns.join(&"middle", 5.0)
	return turns


func _take(turns: TurnScheduler, count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in count:
		out.append(turns.next())
	return out


func _fastest_first() -> void:
	var turns := _three()
	equal("a round is fastest first", _take(turns, 3), [&"fast", &"middle", &"slow"])
	equal("and that was round 1", turns.round_number(), 1)
	equal("the next round starts the same way", turns.next(), &"fast")
	equal("as round 2", turns.round_number(), 2)


func _ties_go_to_the_first_to_join() -> void:
	var turns := RoundScheduler.new()
	turns.join(&"first", 4.0)
	turns.join(&"second", 4.0)
	turns.join(&"third", 4.0)
	equal("equal speeds act in join order", _take(turns, 3), [&"first", &"second", &"third"])


func _leaving_mid_round_is_skipped() -> void:
	var turns := _three()
	turns.next()
	turns.leave(&"middle")
	equal("someone who leaves mid-round is skipped", turns.next(), &"slow")
	equal("and is gone from later rounds", _take(turns, 2), [&"fast", &"slow"])


func _joining_waits_for_the_next_round() -> void:
	var turns := _three()
	turns.next()
	turns.join(&"newcomer", 99.0)
	equal("a newcomer does not cut into the current round", _take(turns, 2), [&"middle", &"slow"])
	equal("and leads the next one", turns.next(), &"newcomer")


func _preview_agrees_with_next() -> void:
	var turns := _three()
	turns.next()
	var seen: Array[StringName] = turns.preview(5)
	equal("preview runs through the rest of this round into the next",
			seen, [&"middle", &"slow", &"fast", &"middle", &"slow"])
	equal("and next() then answers exactly that", _take(turns, 5), seen)


func _an_empty_battle_has_no_turn() -> void:
	var turns := RoundScheduler.new()
	equal("nobody in the battle means no turn", turns.next() == &"" and turns.preview(3).is_empty(), true)


# C8.27b: the newcomer takes the leaver's place this round, never a second turn in one.
func _a_hand_over_keeps_the_place() -> void:
	var turns := _three()
	turns.next()
	var refused: Array[bool] = [turns.hand_over(&"nobody", &"bench", 1.0), turns.hand_over(&"slow", &"middle", 1.0)]
	var handed: bool = turns.hand_over(&"middle", &"bench", 1.0)
	equal("a hand-over takes the leaver's place this round, then goes by its own speed",
		[refused, handed, _take(turns, 2), _take(turns, 3)],
		[[false, false], true, [&"bench", &"slow"], [&"fast", &"slow", &"bench"]])
	turns = _three()
	turns.next()
	turns.leave(&"fast")
	turns.hand_over(&"middle", &"fast", 9.0)
	equal("one who already acted this round gets no second turn in it", _take(turns, 3),
		[&"slow", &"fast", &"slow"])
