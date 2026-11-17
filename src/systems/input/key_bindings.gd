class_name KeyBindings
extends RefCounted
## What a particular player has changed about the input map, and the file it lives in.
##
## WHY THIS IS NOT IN actions.gd
## `Actions` owns the action NAMES and their DEFAULT bindings - a declarative list, readable in
## a diff, which is the whole point of ADR-0003. What one player has since reassigned is a
## different concern with a different lifetime: it belongs to their machine, like `Settings`
## does, not to the project. Folding it in would also have taken actions.gd from 83 code lines
## to 148 of its 150, which is the shape of a file about to be given an exemption.
##
## STORED AS CODES, NOT AS EVENTS. A ConfigFile can hold an InputEventKey object, but then the
## file is a serialised engine class and every property that class has is part of the format.
## One integer per binding is readable, hand-repairable, and cannot break when the engine adds
## a field.
##
## AN ANALOGUE STICK IS NEVER ERASED. Rebinding a key replaces the KEYS of that action and
## rebinding a pad button replaces its PAD BUTTONS. A stick's `InputEventJoypadMotion` is neither,
## so `move_up` keeps its left-stick axis however often W is reassigned - which is what stops a
## keyboard rebind from quietly making the game unplayable on a controller.
##
## A TRIGGER IS A PAD BUTTON HERE (T7.5). It is an axis to the engine, but a player presses it like
## a button, so it belongs to the pad half: it is named, it can be chosen when rebinding a pad
## slot, and choosing a button replaces it (or the other way round). It is stored in the pad field
## as `TRIGGER_CODE` plus its axis, and named through a localization key, because the engine's own
## name for it starts "Joystick 2 Y-Axis".
##
## OWNS: user://input.cfg, and the events it installs into the InputMap.
## MUST NOT: name an action, decide a default, or read input. It mentions `Actions` in exactly
## one expression - `rebind`'s gate - and `Actions` does not mention this class, so the two files
## cannot become a cycle. See that method's note for why the list is read rather than copied.

const PATH: String = "user://input.cfg"
const KEY_FIELD: String = "key"
const PAD_FIELD: String = "pad"
## A trigger's stored code is this plus its axis: 204 the left, 205 the right. Pad buttons stop
## below 128, so the two can never meet.
const TRIGGER_CODE: int = 200
const LEFT_TRIGGER_KEY: String = "ui.rebind.trigger_left"
const RIGHT_TRIGGER_KEY: String = "ui.rebind.trigger_right"

## The file read and written. `PATH` unless the suite says otherwise: the runner points it at its
## own scratch copy, T6.13, because a case that rebinds and resets would otherwise write, then
## DELETE, the player's real overrides, and race every other suite running on the machine.
static var file_path: String = PATH


## Bind `action` to `event` and remember it. Returns false for an action that is not rebindable,
## or an event that is not a key, a pad button or a trigger - a mouse wheel cannot be a movement
## key, and saying so is better than storing a binding that never fires.
##
## THE GATE IS `Actions.is_rebindable`, NOT `InputMap.has_action`, AND THE DIFFERENCE WAS A BUG.
## Until T5.5 this asked only whether the action EXISTED, so `debug_console` or `cam_zoom_in`
## could be overridden and written to input.cfg - and then `reset_bindings()` re-declares only
## the four rebindable groups, so nothing put the erased default back and `forget_all()` was the
## only way out of a file the player could not see. Refusing the write is the fix: an override
## that cannot be reset must not be storable in the first place.
##
## AND THIS IS THE ONE PLACE THE MUST NOT LINE BELOW IS SPENT. It says this file never mentions
## `Actions`; it now does, in exactly one expression, because the alternative is a second copy of
## the rebindable list here and two lists that drift is the defect this project keeps finding.
## `Actions` is an autoload and does not reference this class, so there is still no cycle.
static func rebind(action: StringName, event: InputEvent) -> bool:
	if not Actions.is_rebindable(action):
		Log.error("input", "'%s' is not a rebindable action" % action)
		return false
	if not InputMap.has_action(action):
		Log.error("input", "Cannot rebind unknown action '%s'" % action)
		return false
	var code: int = code_of(event)
	if code < 0:
		Log.warn("input", "'%s' cannot be bound to %s" % [action, event.as_text()])
		return false

	var pad: bool = _pad_half(event)
	_install(action, event, pad)

	var file := ConfigFile.new()
	file.load(file_path)
	file.set_value(String(action), PAD_FIELD if pad else KEY_FIELD, code)
	var err: Error = file.save(file_path)
	if err != OK:
		Log.error("input", "Could not write %s: %s" % [file_path, error_string(err)])
		return false
	Log.info("input", "'%s' bound to %s" % [action, event.as_text()])
	return true


## Put every stored override back. Called ONCE and AFTER the defaults are declared, because
## installing an override erases the default of the same kind - run it first and the defaults
## would simply overwrite it.
static func load_all() -> int:
	var file := ConfigFile.new()
	if file.load(file_path) != OK:
		return 0
	var restored: int = 0
	for section: String in file.get_sections():
		var action: StringName = StringName(section)
		if not InputMap.has_action(action):
			# Not an error yet: a game adds its own actions after this runs, and
			# `Actions.add_rebindable` restores each one's section then (T7.3).
			Log.info("input", "%s names '%s', not defined yet" % [file_path, section])
			continue
		restored += _restore(file, action, KEY_FIELD)
		restored += _restore(file, action, PAD_FIELD)
	if restored > 0:
		Log.info("input", "Restored %d custom binding(s)" % restored)
	return restored


## Put back the stored override of ONE action, for an action defined after `load_all` ran: a
## game's own, added through `Actions.add_rebindable`. Returns how many halves it restored.
static func restore(action: StringName) -> int:
	var file := ConfigFile.new()
	if file.load(file_path) != OK or not file.has_section(String(action)):
		return 0
	if not InputMap.has_action(action):
		return 0
	return _restore(file, action, KEY_FIELD) + _restore(file, action, PAD_FIELD)


## Forget every override. The caller re-declares the defaults afterwards: this class does not
## know what they are and must not learn.
static func forget_all() -> void:
	if not FileAccess.file_exists(file_path):
		return
	var dir: DirAccess = DirAccess.open(file_path.get_base_dir())
	if dir == null or dir.remove(file_path.get_file()) != OK:
		Log.warn("input", "Could not remove %s" % file_path)


## What one action's binding reads as on screen, for the keyboard half or the pad half. Empty
## when that half is unbound, which a rebinding screen renders as a dash rather than a blank.
static func text_for(action: StringName, pad: bool) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if pad and button != null:
			return _pad_text(button)
		if pad and _trigger_axis(event) >= 0:
			return _trigger_text(_trigger_axis(event))
		var key: InputEventKey = event as InputEventKey
		if not pad and key != null:
			return _key_text(key)
	return ""


## The integer this project stores for an event, or -1 for an event it will not bind.
static func code_of(event: InputEvent) -> int:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		return button.button_index
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if _trigger_axis(event) >= 0 and motion.axis_value > 0.0:
		return TRIGGER_CODE + motion.axis
	return -1


## Whether a press the controls screen hears can become a binding: a key, a pad button, or a
## trigger pushed past half-way (T7.5). Not a release, an echo, a mouse button or a stick.
static func bindable(event: InputEvent) -> bool:
	return event.is_pressed() and not event.is_echo() and code_of(event) >= 0


## Physical keycodes, exactly as the defaults use, so a reassigned WASD stays in the same
## physical place on an AZERTY or Dvorak keyboard instead of scattering.
static func event_for_key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	return event


static func event_for_pad(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index as JoyButton
	return event


## A trigger pressed all the way, as a binding (T7.5). `axis` is `JOY_AXIS_TRIGGER_LEFT` or `_RIGHT`.
static func event_for_trigger(axis: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = 1.0
	return event


## Replace the events of the SAME KIND, then add the new one. action_get_events hands back a
## fresh Array each call, so erasing while walking it is safe.
static func _install(action: StringName, event: InputEvent, pad: bool) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		var same_kind: bool = _pad_half(existing) if pad else (existing is InputEventKey)
		if same_kind:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)


static func _restore(file: ConfigFile, action: StringName, field: String) -> int:
	var stored: Variant = file.get_value(String(action), field, -1)
	# to_float, then a cast: `int(value)` on a Variant does not parse in this project.
	var code: int = DictRead.to_float(stored) as int
	if code < 0:
		return 0
	var event: InputEvent = null
	if field == KEY_FIELD:
		event = event_for_key(code)
	elif code < TRIGGER_CODE:
		event = event_for_pad(code)
	elif code == TRIGGER_CODE + JOY_AXIS_TRIGGER_LEFT or code == TRIGGER_CODE + JOY_AXIS_TRIGGER_RIGHT:
		event = event_for_trigger(code - TRIGGER_CODE)
	else:
		return 0
	_install(action, event, field == PAD_FIELD)
	return 1


## The pad half of a binding: a button, or a trigger (T7.5). A stick axis is neither.
static func _pad_half(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or _trigger_axis(event) >= 0


## A trigger's axis, or -1 for any other event.
static func _trigger_axis(event: InputEvent) -> int:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null:
		return -1
	if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
		return motion.axis
	return -1


static func _trigger_text(axis: int) -> String:
	var key: String = LEFT_TRIGGER_KEY if axis == JOY_AXIS_TRIGGER_LEFT else RIGHT_TRIGGER_KEY
	return String(TranslationServer.translate(key))


## as_text() on a physical-only key prints "W (Physical)", which is accurate and unreadable on
## a menu row. as_text_physical_keycode() prints "W".
static func _key_text(key: InputEventKey) -> String:
	if key.physical_keycode != KEY_NONE:
		return key.as_text_physical_keycode()
	return key.as_text()


## And as_text() on a pad button prints EVERY console's name for it - "Joypad Button 2 (Left
## Action, Sony Square, Xbox X, Nintendo Y)" - which is sixty characters and ran straight off the
## side of the controls screen in a capture. The parenthetical's first name is the readable part:
## "Left Action". Falls back to the whole string for a button nobody has named.
static func _pad_text(button: InputEventJoypadButton) -> String:
	var full: String = button.as_text()
	var opened: int = full.find("(")
	if opened < 0:
		return full
	var inner: String = full.substr(opened + 1).trim_suffix(")")
	return inner.get_slice(",", 0).strip_edges()
