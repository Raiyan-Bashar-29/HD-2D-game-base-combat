extends TestCase
## A pad trigger is the pad half of a binding (T7.5): named on the controls screen, chosen when
## rebinding a pad slot, saved, put back at boot, and replaced by a button or replacing one. A
## stick axis is still never touched.
##
## THE GAP IT CLOSES: a trigger is an axis to the engine, and `KeyBindings` named and rebound only
## pad buttons, so an action on a trigger showed "—" in the pad column and a trigger could not be
## chosen there. The combat fork's dodge and lock-on sit on the triggers.
##
## THE BOOT ORDER IS ASSERTED as in `options_test`: the default is put back over the rebind, as a
## fresh boot does, and the override file must bring the trigger back.
##
## THIS CASE WRITES THE BINDINGS FILE, the run's scratch copy (T6.13), and resets it at the end.
##
## OWNS: assertions about triggers in `KeyBindings` and on the controls screen.
## MUST NOT: name a game's action. The one here is made up for the case.

const ACTION: StringName = &"pad_trigger_test_verb"

var _stack: UiRoot = null


func run() -> void:
	plan(21)
	_stack = UiRoot.new()
	attach(_stack)
	_a_trigger_has_a_code()
	_a_trigger_replaces_the_pad_button()
	_a_saved_trigger_survives_a_boot()
	_a_button_replaces_the_trigger()
	_a_stick_survives_a_trigger()
	_a_default_trigger_is_named()
	_tear_down()


func _a_trigger_has_a_code() -> void:
	var right: InputEventJoypadMotion = KeyBindings.event_for_trigger(JOY_AXIS_TRIGGER_RIGHT)
	equal("a trigger's code is past every button",
			KeyBindings.code_of(right), KeyBindings.TRIGGER_CODE + JOY_AXIS_TRIGGER_RIGHT)
	equal("a stick has none", KeyBindings.code_of(_motion(JOY_AXIS_LEFT_X, 1.0)), -1)
	equal("nor a released trigger", KeyBindings.code_of(_motion(JOY_AXIS_TRIGGER_LEFT, 0.0)), -1)
	equal("a trigger pushed past half-way can be bound", KeyBindings.bindable(right), true)
	equal("one barely touched cannot", KeyBindings.bindable(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.4)), false)
	equal("nor a stick", KeyBindings.bindable(_motion(JOY_AXIS_LEFT_Y, 1.0)), false)


func _a_trigger_replaces_the_pad_button() -> void:
	var keys: String = KeyBindings.text_for(Actions.INVENTORY, false)
	equal("a pad slot takes a trigger",
			KeyBindings.rebind(Actions.INVENTORY, KeyBindings.event_for_trigger(JOY_AXIS_TRIGGER_RIGHT)), true)
	equal("and names it", KeyBindings.text_for(Actions.INVENTORY, true), tr(KeyBindings.RIGHT_TRIGGER_KEY))
	equal("the pad button it replaced is gone", _buttons(Actions.INVENTORY), 0)
	equal("the key half is untouched", KeyBindings.text_for(Actions.INVENTORY, false), keys)
	var file := ConfigFile.new()
	file.load(KeyBindings.file_path)
	equal("it is saved as its code", file.get_value(String(Actions.INVENTORY), KeyBindings.PAD_FIELD, -1),
			KeyBindings.TRIGGER_CODE + JOY_AXIS_TRIGGER_RIGHT)
	var screen := RebindScreen.new()
	equal("the controls screen opens", _stack.open(screen), true)
	equal("its row names the trigger", screen.row_text(Actions.INVENTORY).contains(tr(KeyBindings.RIGHT_TRIGGER_KEY)), true)
	equal("cleanup", _stack.close_top(), true)


## What a boot does: the default goes back on, then the override file is read.
func _a_saved_trigger_survives_a_boot() -> void:
	InputMap.action_erase_events(Actions.INVENTORY)
	InputMap.action_add_event(Actions.INVENTORY, KeyBindings.event_for_pad(JOY_BUTTON_Y))
	equal("the saved trigger is put back", KeyBindings.restore(Actions.INVENTORY), 1)
	equal("over the default button", [_buttons(Actions.INVENTORY), KeyBindings.text_for(Actions.INVENTORY, true)],
			[0, tr(KeyBindings.RIGHT_TRIGGER_KEY)])


func _a_button_replaces_the_trigger() -> void:
	KeyBindings.rebind(Actions.INVENTORY, KeyBindings.event_for_pad(JOY_BUTTON_Y))
	equal("a button replaces the trigger", [_buttons(Actions.INVENTORY), _triggers(Actions.INVENTORY)], [1, 0])


func _a_stick_survives_a_trigger() -> void:
	KeyBindings.rebind(Actions.MOVE_UP, KeyBindings.event_for_trigger(JOY_AXIS_TRIGGER_LEFT))
	equal("the D-pad button goes", _buttons(Actions.MOVE_UP), 0)
	equal("the stick stays", _has_stick(Actions.MOVE_UP), true)


func _a_default_trigger_is_named() -> void:
	var events: Array[InputEvent] = [KeyBindings.event_for_trigger(JOY_AXIS_TRIGGER_LEFT)]
	Actions.add_rebindable(ACTION, events, 0.5)
	equal("an action whose default is a trigger names it", KeyBindings.text_for(ACTION, true),
			tr(KeyBindings.LEFT_TRIGGER_KEY))
	var file := ConfigFile.new()
	file.load(KeyBindings.file_path)
	file.set_value(String(ACTION), KeyBindings.PAD_FIELD, KeyBindings.TRIGGER_CODE + JOY_AXIS_RIGHT_Y)
	file.save(KeyBindings.file_path)
	equal("a stored code that is no trigger is not restored", KeyBindings.restore(ACTION), 0)
	Actions.remove_rebindable(ACTION)


func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _buttons(action: StringName) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			count += 1
	return count


func _triggers(action: StringName) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if KeyBindings.code_of(event) >= KeyBindings.TRIGGER_CODE:
			count += 1
	return count


func _has_stick(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion != null and motion.axis == JOY_AXIS_LEFT_Y:
			return true
	return false


func _tear_down() -> void:
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	Actions.reset_bindings()
