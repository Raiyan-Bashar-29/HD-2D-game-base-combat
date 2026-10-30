class_name MoveTimeline
extends RefCounted
## The clock of one real-time fighter's moves: which phase the current move is in, when the next
## swing of a chain may start, and when the fighter is untouchable.
##
## IN PLAIN WORDS: a fighter node calls `step(dt)` every physics frame and gets back the phases
## it entered during that frame, in order, so it can switch a hitbox on as ACTIVE begins and off
## as RECOVERY begins. One long frame may cross several phases; none is skipped.
##
## PRESSING ATTACK (`press`) starts the chain's first move when idle, and the chain's next move
## once the current one is in its chain window. A press that comes a little early, up to
## `buffer_window` seconds before the window opens, is remembered and plays the moment the
## window opens, so a player who mashes is not punished. A press earlier than that is dropped.
## After the last move of a chain, pressing again waits until the fighter is idle.
##
## A DODGE (`start` with the dodge move) is allowed when idle or during recovery
## (`can_dodge`): it cancels the follow-through, never a wind-up or a live swing.
##
## `swing` counts every move started, so a hitbox can hit each target once per swing.
##
## OWNS: the current move, its elapsed time, the chain position and the buffered press.
## MUST NOT: read input, move a body or touch a node. It is stepped by `dt` so tests need no
## frames.

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

## How early a press may come before the chain window and still count.
var buffer_window: float = 0.25

var move: ActionMove
var phase: Phase = Phase.IDLE
## Seconds since the current move started.
var elapsed: float = 0.0
## Which move of the chain is playing; -1 when no chain is.
var chain_index: int = -1
var swing: int = 0

var _chain: Array[ActionMove] = []
var _buffered: bool = false


## Plays `next` from its first frame, ending whatever was playing. Leaves any chain.
func start(next: ActionMove) -> void:
	_begin(next, 0.0)
	chain_index = -1
	_chain = []


## The attack button. True when a move started now; false when it was buffered or dropped.
func press(chain: Array[ActionMove]) -> bool:
	if chain.is_empty():
		return false
	if phase == Phase.IDLE:
		_chain = chain
		chain_index = 0
		_begin(chain[0], 0.0)
		return true
	if chain_index < 0 or chain_index + 1 >= _chain.size():
		return false
	if phase == Phase.RECOVERY and elapsed >= _window_opens():
		_next_in_chain(elapsed - _window_opens())
		return true
	if _window_opens() - elapsed <= buffer_window:
		_buffered = true
	return false


## Advances the clock by `dt` seconds. Returns the phases entered, in order.
func step(dt: float) -> Array[int]:
	var entered: Array[int] = []
	if phase == Phase.IDLE:
		return entered
	elapsed += dt
	var moved: bool = true
	while moved and phase != Phase.IDLE:
		moved = _advance(entered)
	return entered


## Ends the current move at once: a stagger, a knockback, a defeat.
func cancel() -> void:
	phase = Phase.IDLE
	move = null
	chain_index = -1
	_buffered = false


func busy() -> bool:
	return phase != Phase.IDLE


## True while the current move's hitbox should be live.
func is_hitting() -> bool:
	return phase == Phase.ACTIVE and move.strikes()


func can_dodge() -> bool:
	return phase == Phase.IDLE or phase == Phase.RECOVERY


func invulnerable() -> bool:
	if move == null or move.iframes_to <= move.iframes_from:
		return false
	return elapsed >= move.iframes_from and elapsed < move.iframes_to


## One transition if one is due; true when it happened, so `step` loops on.
func _advance(entered: Array[int]) -> bool:
	if phase == Phase.STARTUP and elapsed >= move.startup:
		phase = Phase.ACTIVE
	elif phase == Phase.ACTIVE and elapsed >= move.startup + move.active:
		phase = Phase.RECOVERY
	elif phase == Phase.RECOVERY and _buffered and elapsed >= _window_opens():
		_next_in_chain(elapsed - _window_opens())
	elif phase == Phase.RECOVERY and elapsed >= move.length():
		cancel()
	else:
		return false
	entered.append(phase)
	return true


func _begin(next: ActionMove, carried: float) -> void:
	move = next
	phase = Phase.STARTUP
	elapsed = carried
	swing += 1
	_buffered = false


func _next_in_chain(carried: float) -> void:
	chain_index += 1
	_begin(_chain[chain_index], carried)


## Seconds after the current move starts when the next chain move may begin.
func _window_opens() -> float:
	return move.startup + move.active + move.chain_after
