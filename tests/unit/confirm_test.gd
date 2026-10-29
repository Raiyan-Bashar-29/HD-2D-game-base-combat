extends TestCase
## The confirm screen, and the one question the base asks with it: overwriting a save.
##
## TWO HALVES, BECAUSE EACH CAN BREAK ALONE. The SCREEN — its flags, where focus lands, that
## cancel cannot answer it, that only "yes" runs the action — is asserted on an instance with no
## stack under it, so pressing a row cannot trigger the stack's DEFERRED close mid-case. The
## ROUTE — an occupied slot asks, an empty one does not, and "yes" is what writes — is asserted
## through a real `UiRoot`, closed explicitly.
##
## ROWS ARE PRESSED BY EMITTING `pressed`, which runs the connected Callable synchronously. That
## is the Button's own path, so a row wired to the wrong handler fails here.
##
## THIS CASE OWNS THE SCRATCH SAVE STORE FOR THE RUN, never `user://saves`, as `menus_test.gd`
## does: set-up points `SaveSystem` at `SaveFixture.root()`, and every slot there is emptied at
## set-up and again after, because "an empty slot saves without asking" needs one to be empty.
##
## OWNS: assertions about the confirm screen and the overwrite question.
## MUST NOT: re-assert the slot list's rows or headers (menus_test.gd) or the pause table
## (ui_test.gd).

const PROBE_SLOT: int = 3
const DETAIL: String = "probe detail"

var _stack: UiRoot = null
var _keys: ScreenKeys = null
var _yes_count: int = 0
var _close_count: int = 0
var _toasts: Array[String] = []


func run() -> void:
	plan(27)
	_set_up()
	_the_flags_are_declared_in_init()
	_no_is_where_focus_lands()
	_only_yes_runs_the_action()
	_cancel_cannot_dodge_the_question()
	_an_empty_slot_saves_without_asking()
	_an_occupied_slot_asks_first()
	_the_keys_exist()
	_tear_down()


func _set_up() -> void:
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	_stack = UiRoot.new()
	attach(_stack)
	_keys = ScreenKeys.new()
	attach(_keys)
	for slot: int in SaveSystem.AUTOSAVE_SLOT + 1:
		SaveSystem.delete_slot(slot)
	Events.notify_requested.connect(_on_toast)


## Declared in `_init`, not `_build`: `StubScreen` once set its flags too late and made an
## assertion pass vacuously for a whole package (menus_test.gd's header).
func _the_flags_are_declared_in_init() -> void:
	var screen := ConfirmScreen.new()
	equal("cancel cannot dismiss a question", screen.closes_on_cancel, false)
	equal("and it stops the world while it waits", screen.pauses_world, true)
	equal("it names itself", screen.screen_id, ConfirmScreen.SCREEN_ID)
	screen.free()


func _no_is_where_focus_lands() -> void:
	var screen: ConfirmScreen = _unstacked()
	equal("the question is the title", screen.title_key, SaveScreen.OVERWRITE_KEY)
	equal("the detail, then yes, then no",
		screen.row_texts(), [DETAIL, tr(ConfirmScreen.YES_KEY), tr(ConfirmScreen.NO_KEY)])
	equal("and focus is on no, though yes is drawn first", _focused(screen), tr(ConfirmScreen.NO_KEY))
	screen.refresh()
	equal("a redraw puts it back on no", _focused(screen), tr(ConfirmScreen.NO_KEY))
	screen.free()


## Neither row closes the screen itself: both ASK, and the stack decides.
func _only_yes_runs_the_action() -> void:
	var screen: ConfirmScreen = _unstacked()
	_row(screen, tr(ConfirmScreen.NO_KEY)).pressed.emit()
	equal("no does not run the action", _yes_count, 0)
	equal("but asks to close", _close_count, 1)
	_row(screen, tr(ConfirmScreen.YES_KEY)).pressed.emit()
	equal("yes runs it exactly once", _yes_count, 1)
	equal("and asks to close too", _close_count, 2)
	screen.free()


## THE HEADLINE. With the question on top, cancel and pause both fall through `UiRoot`, and the
## pause key cannot stack a pause menu over it either.
func _cancel_cannot_dodge_the_question() -> void:
	_yes_count = 0
	var screen := ConfirmScreen.asking(SaveScreen.OVERWRITE_KEY, DETAIL, _on_yes)
	equal("the question opens", _stack.open(screen), true)
	for action: StringName in [Actions.CANCEL, Actions.PAUSE]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		_stack._unhandled_input(event)
		equal("%s does not answer it" % action, _stack.depth(), 1)
	equal("the pause key opens nothing over it", _keys.toggle_pause_menu(_stack), false)
	equal("and nothing ran", _yes_count, 0)
	# THE CONTROL: the same event, on a screen that allows it, does close. Without this, an event
	# that never matched the action would pass every line above.
	screen.closes_on_cancel = true
	_stack._unhandled_input(_cancel())
	equal("the same cancel closes a screen that allows it", _stack.depth(), 0)
	_stack.close_all()


func _cancel() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = Actions.CANCEL
	event.pressed = true
	return event


func _an_empty_slot_saves_without_asking() -> void:
	var saving := SaveScreen.for_saving()
	_stack.open(saving)
	_row(saving, saving.slot_text(PROBE_SLOT)).pressed.emit()
	equal("an empty slot is written at once", SaveSystem.has_slot(PROBE_SLOT), true)
	equal("with no question in between", _stack.top(), saving)
	equal("and the player is told", _toasts, [SaveScreen.SAVED_KEY])
	_stack.close_all()


## The slot is occupied now. Pressing it asks; only the answer writes.
func _an_occupied_slot_asks_first() -> void:
	_toasts.clear()
	var saving := SaveScreen.for_saving()
	_stack.open(saving)
	var header: String = saving.slot_text(PROBE_SLOT)
	_row(saving, header).pressed.emit()
	var asked: ConfirmScreen = _stack.top() as ConfirmScreen
	equal("an occupied slot asks first", asked != null, true)
	if asked == null:
		_stack.close_all()
		return
	equal("naming the save it would replace", asked.detail, header)
	equal("and nothing was written yet", _toasts.size(), 0)
	asked.on_yes.call()
	equal("yes is what writes it", _toasts, [SaveScreen.SAVED_KEY])
	_stack.close_all()


func _the_keys_exist() -> void:
	for key: String in [SaveScreen.OVERWRITE_KEY, ConfirmScreen.YES_KEY, ConfirmScreen.NO_KEY]:
		equal("key %s is translated" % key, tr(key) != key, true)


## A question with no stack under it: `close_requested` is counted here instead of handled.
func _unstacked() -> ConfirmScreen:
	var screen := ConfirmScreen.asking(SaveScreen.OVERWRITE_KEY, DETAIL, _on_yes)
	screen.close_requested.connect(_on_close)
	attach(screen)
	return screen


func _row(screen: MenuScreen, text_value: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text_value:
			return button
	equal("a row reads '%s'" % text_value, false, true)
	return Button.new()


func _focused(screen: MenuScreen) -> String:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and button.has_focus():
			return button.text
	return ""


func _on_yes() -> void:
	_yes_count += 1


func _on_close() -> void:
	_close_count += 1


func _on_toast(key: String, _seconds: float, _args: Dictionary) -> void:
	_toasts.append(key)


func _tear_down() -> void:
	Events.notify_requested.disconnect(_on_toast)
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	for slot: int in SaveSystem.AUTOSAVE_SLOT + 1:
		SaveSystem.delete_slot(slot)
	_keys = null
