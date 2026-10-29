extends TestCase
## The screen stack, pause semantics and the token input lock.
##
## THE HEADLINE ASSERTION IS _overlapping_locks_release_correctly(). Everything else in this
## file exists to make that one trustworthy. Lock A, lock B, release A, and the player must
## STILL be locked - because the bug this whole package prevents is a climb that finished
## inside a conversation clearing the hold the conversation was still relying on.
##
## Driven by direct open()/close_top()/lock_input() calls, never by simulated input and never
## by waiting on real frames: TestCase.run() is synchronous and cannot await a physics frame.
##
## OWNS: assertions about the lock, the stack, the announced mode and the pause table.
## MUST NOT: assert anything about what a screen renders. That is screens_test.gd's job; this
## file drives real InventoryScreens purely as stack occupants and never looks inside one.

var _mover: PlayerController = null
var _stack: UiRoot = null
var _heard: Array[int] = []


func run() -> void:
	plan(83)
	_bare_lock()
	_overlapping_locks_release_correctly()
	_lock_is_idempotent()
	_stack_opens_and_closes()
	_stack_hands_control_over()
	_climb_still_gives_control_back()
	_pause_table()
	_tear_down()


## The lock on its own, with no player and no screen attached to it.
func _bare_lock() -> void:
	var lock := InputLock.new()
	equal("a fresh lock holds nothing", lock.is_locked(), false)
	equal("and names nobody", lock.count(), 0)
	lock.lock(&"dialogue")
	equal("locking holds it", lock.is_locked(), true)
	equal("and it knows who", lock.holds(&"dialogue"), true)
	equal("and not who it is not", lock.holds(&"climb"), false)
	equal("holders names the holder", lock.holders(), [&"dialogue"] as Array[StringName])
	lock.release(&"climb")
	equal("releasing a token nobody holds is harmless", lock.is_locked(), true)
	lock.lock(&"")
	equal("an empty token is not a hold", lock.count(), 1)
	lock.release(&"dialogue")
	equal("releasing the holder frees it", lock.is_locked(), false)
	# The copy must be a copy, or a caller could pick the lock by emptying the list it got.
	lock.lock(&"ui")
	var taken: Array[StringName] = lock.holders()
	taken.clear()
	equal("holders hands out a copy", lock.is_locked(), true)


## The exact collision WP-02 exists to prevent, asserted on the real PlayerController.
func _overlapping_locks_release_correctly() -> void:
	_mover = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_mover)
	equal("the player starts free", _mover.is_input_locked(), false)

	_mover.lock_input(&"dialogue")
	equal("A locks", _mover.is_input_locked(), true)
	_mover.lock_input(&"climb")
	equal("B locks too", _mover.is_input_locked(), true)
	equal("and both are named", _mover.input_holders().size(), 2)

	_mover.release_input(&"dialogue")
	equal("releasing A leaves the player LOCKED", _mover.is_input_locked(), true)
	equal("because B still holds", _mover.input_holders(), [&"climb"] as Array[StringName])

	_mover.release_input(&"climb")
	equal("releasing B returns control", _mover.is_input_locked(), false)
	equal("and nobody is left holding", _mover.input_holders().size(), 0)


## A doubled signal must not need a doubled release. dialogue_started firing twice is not a
## hypothetical - a save loaded mid-conversation would do exactly that.
func _lock_is_idempotent() -> void:
	_mover.lock_input(&"dialogue")
	_mover.lock_input(&"dialogue")
	equal("locking twice is still one hold", _mover.input_holders().size(), 1)
	_mover.release_input(&"dialogue")
	equal("so one release is enough", _mover.is_input_locked(), false)


func _stack_opens_and_closes() -> void:
	_stack = UiRoot.new()
	attach(_stack)
	Events.ui_mode_changed.connect(_on_mode_changed)

	equal("an empty stack allows gameplay", _stack.is_gameplay_input_allowed(), true)
	equal("and reports GAMEPLAY", _stack.mode(), GameEnums.UiMode.GAMEPLAY)
	equal("closing nothing reports nothing closed", _stack.close_top(), false)
	equal("a null screen is refused", _stack.open(null), false)

	var menu := InventoryScreen.new()
	equal("the inventory opens", _stack.open(menu), true)
	equal("depth is one", _stack.depth(), 1)
	equal("it is the top", _stack.top(), menu)
	equal("it can be found by id", _stack.has_screen(InventoryScreen.SCREEN_ID), true)
	equal("gameplay input stops", _stack.is_gameplay_input_allowed(), false)
	equal("the mode is MODAL", _stack.mode(), GameEnums.UiMode.MODAL)
	equal("the tree is paused", get_tree().paused, true)
	equal("the mode was announced once", _heard.size(), 1)
	equal("as MODAL", _heard[0], GameEnums.UiMode.MODAL)
	equal("opening the same screen twice is refused", _stack.open(menu), false)

	_overlay_over_the_menu()

	equal("closing the menu succeeds", _stack.close_top(), true)
	equal("the stack is empty", _stack.depth(), 0)
	equal("gameplay input returns", _stack.is_gameplay_input_allowed(), true)
	equal("and the world restarts", get_tree().paused, false)
	equal("GAMEPLAY was announced", _heard[-1], GameEnums.UiMode.GAMEPLAY)


## A non-pausing overlay dropped over a pausing menu must NOT restart the world underneath it.
func _overlay_over_the_menu() -> void:
	var covered: UiScreen = _stack.top()
	# A second inventory standing in for the dialogue box WP-05 will bring. It is the flag
	# that is under test, not the contents, and a screen declares its flags in _init so an
	# override set here still stands after _ready - which is what the next line asserts.
	var talk := InventoryScreen.new()
	talk.pauses_world = false
	equal("an overlay opens on top", _stack.open(talk), true)
	equal("and _ready did not overwrite its declaration", talk.pauses_world, false)
	equal("depth is two", _stack.depth(), 2)
	equal("only the top screen processes", talk.process_mode, Node.PROCESS_MODE_ALWAYS)
	equal("the covered one is disabled", covered.process_mode, Node.PROCESS_MODE_DISABLED)
	# And not DRAWN. Every screen dims rather than blanks, so two stacked let the lower one's
	# rows print through the upper one's - a WP-12 capture caught the pause menu's status line
	# running through the settings screen's first heading.
	equal("the top screen is drawn", talk.visible, true)
	equal("and the covered one is not", covered.visible, false)
	equal("the world stays paused", get_tree().paused, true)
	equal("and the mode is unchanged", _stack.mode(), GameEnums.UiMode.MODAL)
	equal("so nothing new was announced", _heard.size(), 1)
	equal("closing the overlay succeeds", _stack.close_top(), true)
	equal("the menu is top again", _stack.depth(), 1)
	equal("and processes again", covered.process_mode, Node.PROCESS_MODE_ALWAYS)
	equal("and is drawn again", covered.visible, true)


## The stack announces; the player and the sensor each take their own token on hearing it.
func _stack_hands_control_over() -> void:
	var sensor: InteractionSensor = _mover.get_node_or_null(^"InteractionSensor") as InteractionSensor
	equal("the player has a sensor", sensor != null, true)
	equal("the player is free to begin with", _mover.is_input_locked(), false)
	equal("and so is the sensor", sensor.is_suspended(), false)

	var menu := InventoryScreen.new()
	equal("a screen opens", _stack.open(menu), true)
	equal("the player took the ui token", _mover.input_holders(), [&"ui"] as Array[StringName])
	equal("and the sensor is suspended", sensor.is_suspended(), true)

	# A conversation over a screen: two independent holders again, in the sensor as well as
	# in the body. Closing one must not release the other in either of them.
	Events.dialogue_started.emit(&"test")
	equal("dialogue holds it too", _mover.input_holders().size(), 2)
	equal("closing the screen does not end the conversation", _stack.close_top(), true)
	equal("so the player stays locked", _mover.is_input_locked(), true)
	equal("and so does the sensor", sensor.is_suspended(), true)
	Events.dialogue_finished.emit(&"test")
	equal("ending it returns control", _mover.is_input_locked(), false)
	equal("to the sensor as well", sensor.is_suspended(), false)


## WP-01 must not regress: a climb takes the lock and gives exactly its own token back, even
## while something else is holding at the same time.
func _climb_still_gives_control_back() -> void:
	_mover.global_position = Vector3.ZERO
	var top: Vector3 = Vector3(0.0, 2.0, 0.0)
	Events.dialogue_started.emit(&"test")
	equal("the climb starts inside a conversation", _mover.begin_climb(top), true)
	equal("two systems hold the player", _mover.input_holders().size(), 2)

	var steps: int = 0
	while _mover.is_climbing() and steps < 600:
		_mover.climb_step(1.0 / 60.0)
		steps += 1
	equal("the climb finished", _mover.is_climbing(), false)
	equal("it arrived", _mover.global_position.is_equal_approx(top), true)
	equal("it gave back its own token", _mover.input_holders(), [&"dialogue"] as Array[StringName])
	equal("and left the conversation holding", _mover.is_input_locked(), true)

	Events.dialogue_finished.emit(&"test")
	equal("the conversation ends and the player is free", _mover.is_input_locked(), false)


## The pause table in ui_root.gd, asserted rather than merely written down. can_process()
## answers "would this node tick right now", which is exactly the question.
func _pause_table() -> void:
	var menu := InventoryScreen.new()
	equal("a modal screen opens", _stack.open(menu), true)
	equal("the world clock stops", Clock.can_process(), false)
	equal("the weather stops", Weather.can_process(), false)
	equal("music keeps playing", Audio.can_process(), true)
	equal("a transition can still finish", Director.can_process(), true)
	equal("the stack itself keeps answering", _stack.can_process(), true)
	equal("and so does the open screen", menu.can_process(), true)
	equal("the player is stopped", _mover.can_process(), false)

	equal("closing it restarts the world", _stack.close_top(), true)
	equal("the clock runs again", Clock.can_process(), true)
	equal("and the player moves again", _mover.can_process(), true)


func _tear_down() -> void:
	if Events.ui_mode_changed.is_connected(_on_mode_changed):
		Events.ui_mode_changed.disconnect(_on_mode_changed)
	if _stack != null:
		_stack.close_all()
		_stack = null
	# Belt and braces. A suite that exits with the tree paused freezes every later case.
	get_tree().paused = false
	_mover = null


func _on_mode_changed(mode: GameEnums.UiMode) -> void:
	_heard.append(mode)
