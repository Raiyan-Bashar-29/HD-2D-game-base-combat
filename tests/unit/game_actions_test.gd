extends TestCase
## A game's own input actions, added with `Actions.add_rebindable` (T7.3), are rebindable like
## the built-in ones: listed on the controls screen, rebound and saved, put back by a reset, and
## given back the player's saved binding when the game adds them at boot.
##
## THE BOOT ORDER IS THE HEADLINE. `KeyBindings.load_all()` runs in `Actions._ready`, before any
## game code exists, so it cannot restore an action the game has not added yet. The case removes
## the action and adds it again, which is what a fresh boot does, and asserts the saved key comes
## back rather than the default.
##
## THIS CASE WRITES THE BINDINGS FILE, the run's scratch copy (T6.13), and resets it at the end.
##
## OWNS: assertions about `Actions.add_rebindable`, `remove_rebindable`, `rebindable`,
## `is_rebindable` and `KeyBindings.restore`.
## MUST NOT: name a game's action. The one here is made up for the case.

const ACTION: StringName = &"game_actions_test_verb"

var _stack: UiRoot = null


func run() -> void:
	plan(19)
	_stack = UiRoot.new()
	attach(_stack)
	_before_adding_nothing_is_allowed()
	_adding_defines_and_lists_it()
	_a_built_in_cannot_be_taken()
	_a_saved_binding_survives_a_boot()
	_a_reset_puts_the_default_back()
	_the_controls_screen_lists_it()
	Actions.remove_rebindable(ACTION)
	equal("removing takes it out of the InputMap", InputMap.has_action(ACTION), false)
	equal("and off the list", Actions.rebindable().has(ACTION), false)
	Actions.reset_bindings()


func _before_adding_nothing_is_allowed() -> void:
	equal("not rebindable before it is added", Actions.is_rebindable(ACTION), false)
	equal("so rebinding it is refused",
			KeyBindings.rebind(ACTION, KeyBindings.event_for_key(KEY_U)), false)


func _adding_defines_and_lists_it() -> void:
	var count: int = Actions.rebindable().size()
	equal("adding is accepted", Actions.add_rebindable(ACTION, _default()), true)
	equal("the action exists with its default key", _has_key(KEY_Y), true)
	equal("it is listed after the built-in ones", Actions.rebindable().back(), ACTION)
	Actions.add_rebindable(ACTION, _default())
	equal("adding it twice lists it once", Actions.rebindable().size(), count + 1)


func _a_built_in_cannot_be_taken() -> void:
	var events: Array[InputEvent] = [KeyBindings.event_for_key(KEY_Y)]
	equal("a built-in action is refused", Actions.add_rebindable(Actions.RUN, events), false)
	equal("and keeps its own key", KeyBindings.text_for(Actions.RUN, false), "Shift")
	equal("an engine ui_ action is refused too", Actions.add_rebindable(&"ui_accept", events), false)


func _a_saved_binding_survives_a_boot() -> void:
	equal("rebinding the game's action is accepted",
			KeyBindings.rebind(ACTION, KeyBindings.event_for_key(KEY_U)), true)
	equal("the new key is bound", _has_key(KEY_U), true)
	# A boot in miniature: the action is gone when load_all runs, and the game adds it later.
	Actions.remove_rebindable(ACTION)
	KeyBindings.load_all()
	Actions.add_rebindable(ACTION, _default())
	equal("THE SAVED KEY CAME BACK when the game added it", _has_key(KEY_U), true)
	equal("not the default", _has_key(KEY_Y), false)


func _a_reset_puts_the_default_back() -> void:
	Actions.reset_bindings()
	equal("a reset puts the game action's default back", _has_key(KEY_Y), true)
	equal("and leaves the built-ins working", KeyBindings.text_for(Actions.RUN, false), "Shift")


func _the_controls_screen_lists_it() -> void:
	var screen := RebindScreen.new()
	_stack.open(screen)
	# Counted from rebindable(), not REBINDABLE: a game's own suite may have added actions of its
	# own before this case runs (5.18.1, found by the combat fork).
	equal("the controls screen has a row for every rebindable action, plus reset",
			screen.row_texts().size(), Actions.rebindable().size() + 1)
	equal("and that row names its key", screen.row_text(ACTION).contains("Y"), true)
	_stack.close_top()


func _default() -> Array[InputEvent]:
	return [KeyBindings.event_for_key(KEY_Y)]


func _has_key(code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(ACTION):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == code:
			return true
	return false
