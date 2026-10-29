class_name RebindScreen
extends MenuScreen
## Every rebindable action, its key and its pad button, and one press to change either.
##
## THE LIST IS `Actions.REBINDABLE`, IN ITS ORDER. That constant was written in WP-0 with the
## comment "in the order a rebinding screen should list them" and then had no reader for eleven
## packages. This is the reader; the order still lives with the actions, not here.
##
## PRESS A ROW, THEN PRESS THE THING YOU WANT. The next key or pad button becomes the binding.
## Escape aborts without changing anything, which is why capture happens in `_input`: it runs
## before `UiRoot._unhandled_input`, so the escape that cancels listening cannot also close the
## screen behind it.
##
## A KEY AND A PAD BUTTON ARE SEPARATE HALVES. Rebinding one never touches the other, and
## neither touches the analogue stick - see `KeyBindings`. So a player who reassigns the whole
## keyboard still has a working controller, which is the exit criterion this package is judged
## on.
##
## OWNS: the rows, and which action is currently listening.
## MUST NOT: write the input map or the override file itself. `KeyBindings` owns both, and
## `Actions` owns what the defaults are.

const SCREEN_ID: StringName = &"controls"
const TITLE_KEY: String = "ui.rebind.title"
const HINT_KEY: String = "ui.rebind.hint"
const ROW_KEY: String = "ui.rebind.row"
const LISTENING_KEY: String = "ui.rebind.listening"
const NONE_KEY: String = "ui.rebind.unbound"
const RESET_KEY: String = "ui.rebind.reset"
const ACTION_PREFIX: String = "ui.action."

## The action waiting for a button, or &"" when nothing is listening.
var _listening: StringName = &""
## One entry per row in draw order, empty for the reset row. Parallel array rather than metadata
## on the Button: `get_meta` returns a Variant, and an unsafe cast is an error here.
var _actions: Array[StringName] = []


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false
	# CAPTURE ENDS WHEN THE WINDOW GOES. The next key a player presses after coming back from an
	# alt-tab is not a choice they made on this row. Freeing the screen drops the connection.
	Events.focus_lost.connect(_stop_listening)


## _input, not _unhandled_input: this has to see the escape that cancels listening BEFORE
## UiRoot sees the escape that closes the screen, or aborting a rebind would also dismiss the
## menu behind it.
func _input(event: InputEvent) -> void:
	if _listening == &"":
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	var key: InputEventKey = event as InputEventKey
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_stop_listening()
		return
	var action: StringName = _listening
	_stop_listening()
	if KeyBindings.rebind(action, event):
		_redraw(action)


func _fill() -> void:
	_actions.clear()
	for action: StringName in Actions.REBINDABLE:
		add_row(row_text(action), listen.bind(action))
		_actions.append(action)
	add_row(tr(RESET_KEY), _on_reset)
	_actions.append(&"")


## What one row says. Public so a test asserts the string the player reads rather than
## re-deriving the format and asserting its own arithmetic.
func row_text(action: StringName) -> String:
	var label: String = tr(action_key(action))
	if action == _listening:
		return tr(LISTENING_KEY).format({"action": label})
	return tr(ROW_KEY).format({
		"action": label,
		"key": _or_dash(KeyBindings.text_for(action, false)),
		"pad": _or_dash(KeyBindings.text_for(action, true)),
	})


## A computed key, so no text scan can find it. Asserted mechanically by a loop over REBINDABLE
## in tests/unit/menus_test.gd, the same way the prompt's verb keys are.
static func action_key(action: StringName) -> String:
	return "%s%s" % [ACTION_PREFIX, action]


## Which action is waiting for a button. Public because no assertion can press a key -
## TestCase.run() is synchronous - so the suite drives listening directly and the windowed
## probe proves the real input path separately.
func listening() -> StringName:
	return _listening


## Start waiting for a button on behalf of one row. Public for the same reason `listening()` is:
## no assertion can press a key, so the suite drives this and the windowed probe proves the rest.
func listen(action: StringName) -> void:
	var previous: StringName = _listening
	_listening = action
	if previous != &"" and previous != action:
		_redraw(previous)
	_redraw(action)


func _stop_listening() -> void:
	var was: StringName = _listening
	_listening = &""
	if was != &"":
		_redraw(was)


## Only the row that changed. A full refresh() would rebuild every button and hand focus back to
## the top of the list, so rebinding the tenth action would walk you back to the first.
func _redraw(action: StringName) -> void:
	for index: int in mini(_actions.size(), rows.get_child_count()):
		if _actions[index] != action:
			continue
		var button: Button = rows.get_child(index) as Button
		if button != null:
			button.text = row_text(action)
		return


func _or_dash(text_value: String) -> String:
	return text_value if text_value != "" else tr(NONE_KEY)


func _on_reset() -> void:
	Actions.reset_bindings()
	refresh()
