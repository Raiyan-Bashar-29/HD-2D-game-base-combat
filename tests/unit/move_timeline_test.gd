extends TestCase
## Moves as data, timing as pure code (C3.2): a move walks startup, active and recovery in order;
## one long frame crosses several phases without skipping any; a press in the chain window plays
## the next swing, an early press is buffered and a too-early one dropped; a chain stops at its
## end and starts over once idle; a dodge may cut short recovery but never a wind-up; i-frames
## cover exactly their window; and `problems()` catches bad moves and sets.
##
## OWNS: assertions about `ActionMove`, `MoveSet` and `MoveTimeline`.
## MUST NOT: name a game's moves. Every move here is made up for the case.

const P := MoveTimeline.Phase


func run() -> void:
	plan(22)
	_a_chain_plays_in_order()
	_early_presses()
	_dodge_and_iframes()
	_problems()


## A swing: 0.1 s wind-up, 0.1 s live, 0.3 s follow-through, chain window from 0.1 s into it.
func _swing(power: float = 5.0) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.1
	made.active = 0.1
	made.recovery = 0.3
	made.chain_after = 0.1
	made.power = power
	return made


func _roll() -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.3
	made.recovery = 0.1
	made.iframes_from = 0.05
	made.iframes_to = 0.25
	made.travel_speed = 6.0
	return made


func _a_chain_plays_in_order() -> void:
	var chain: Array[ActionMove] = [_swing(), _swing()]
	var clock := MoveTimeline.new()
	equal("a fresh timeline is idle", clock.busy(), false)
	equal("pressing while idle starts the first swing", clock.press(chain), true)
	equal("in its wind-up", [clock.phase, clock.chain_index], [P.STARTUP, 0])
	equal("0.1 s later the swing goes live", clock.step(0.1), [P.ACTIVE])
	equal("and its hitbox is on", clock.is_hitting(), true)
	equal("0.1 s later it is following through", clock.step(0.1), [P.RECOVERY])
	equal("which a dodge may cut short", clock.can_dodge(), true)
	clock.step(0.15)
	equal("a press in the chain window plays the next swing at once", clock.press(chain), true)
	equal("the second swing started, carrying the 0.05 s overshoot",
		[clock.chain_index, is_equal_approx(clock.elapsed, 0.05), clock.swing], [1, true, 2])
	clock.step(0.2)
	equal("past the end of the chain, a press does nothing", clock.press(chain), false)
	equal("a long frame ends the follow-through", clock.step(1.0), [P.IDLE])
	equal("and the chain is over", clock.chain_index, -1)
	equal("pressing again starts the chain over", [clock.press(chain), clock.chain_index], [true, 0])
	equal("a long first frame enters each phase in turn", clock.step(0.25), [P.ACTIVE, P.RECOVERY])


func _early_presses() -> void:
	var chain: Array[ActionMove] = [_swing(), _swing()]
	var clock := MoveTimeline.new()
	clock.press(chain)
	clock.step(0.1)
	equal("a press just before the window is buffered, not played", clock.press(chain), false)
	equal("and plays the moment the window opens", clock.step(0.25), [P.RECOVERY, P.STARTUP])
	clock.cancel()
	clock.buffer_window = 0.05
	clock.press(chain)
	clock.press(chain)
	clock.step(0.6)
	equal("a press far too early is dropped, so the chain never continued", clock.busy(), false)


func _dodge_and_iframes() -> void:
	var clock := MoveTimeline.new()
	var chain: Array[ActionMove] = [_swing()]
	clock.press(chain)
	equal("no dodging out of a wind-up", clock.can_dodge(), false)
	clock.start(_roll())
	clock.step(0.01)
	var before: bool = clock.invulnerable()
	clock.step(0.1)
	var during: bool = clock.invulnerable()
	clock.step(0.2)
	equal("a dodge is untouchable only inside its i-frames", [before, during, clock.invulnerable()],
		[false, true, false])
	equal("and a roll strikes nothing", clock.is_hitting(), false)


func _problems() -> void:
	var bad := _swing()
	bad.startup = -1.0
	bad.chain_after = 2.0
	equal("a negative time and a chain window past recovery are two problems",
		bad.problems("fixture").size(), 2)
	var moves := MoveSet.new()
	moves.dodge = _swing(0.0)
	equal("an empty chain and a dodge with no i-frames are two problems",
		moves.problems("fixture").size(), 2)
