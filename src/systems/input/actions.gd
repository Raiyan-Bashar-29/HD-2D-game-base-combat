extends Node
## Input action definitions. Autoload `Actions`.
##
## WHY THESE LIVE IN CODE, NOT IN project.godot
## Godot serialises input events into project.godot as long Object(InputEventKey, ...) blobs
## with every property spelled out. Those are unreadable in a diff, painful to hand-edit, and
## break silently if the engine changes a property. Declared here they are readable, greppable,
## reviewable, and the same list feeds the future key-rebinding UI and the button-glyph lookup.
##
## THE TRADE-OFF, stated plainly: the Godot editor's Project Settings > Input Map panel will
## look empty, because these actions do not exist until the game runs. That is accepted.
## See docs/decisions/ADR-0003-input-map-in-code.md.
##
## WHICH DEVICE THE PLAYER IS HOLDING LIVES HERE TOO, and the MUST NOT line below was NARROWED
## to allow it rather than dropped. Since T6.2 this node reads every event for one fact only - did
## it come from a pad, or from a keyboard and mouse - so a prompt can name the button the player
## will actually press. The rule is `InputDevice.device_for`, a pure function; this file holds
## its last answer and announces a change on `Events.input_device_changed`. It lives here rather
## than in an eleventh autoload because adding one needs an ADR, and the fact is part of the
## input map's own vocabulary: the two halves `KeyBindings.text_for(action, pad)` already reads.
##
## OWNS: the action name constants, their default bindings, and which device is active.
## MUST NOT: decide what any action means, or read an event for anything but its device.
## Actions are named, not interpreted.

# Movement. Camera-relative, resolved by the player controller.
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"

# Traversal modifiers. Default gait is a walk; run is held.
#
# THERE IS NO `jump`. There was one from WP-01 until T5.5: declared, bound to Space and the pad's
# west button, listed in REBINDABLE, drawn as a row on the rebinding screen and translated in
# both languages - for a verb `player_controller.gd`'s own header says three times over this
# template does not have. Nothing polled it. A rebinding screen offering a control that cannot
# do anything is worse than a dead constant, because the player is the one who finds out.
# `GameEnums.MoveState.JUMP` is a different symbol and stays: an enum value a game may drive is
# not the same as an input action this one binds. Re-add the action WITH its poller, never before.
const RUN: StringName = &"run"
const SNEAK: StringName = &"sneak"

# World interaction.
const INTERACT: StringName = &"interact"
const INTERACT_CYCLE: StringName = &"interact_cycle"
const CANCEL: StringName = &"cancel"

# Screens.
const INVENTORY: StringName = &"inventory"
const JOURNAL: StringName = &"journal"
const MAP: StringName = &"map"
const PAUSE: StringName = &"pause"

# Camera.
const CAM_ZOOM_IN: StringName = &"cam_zoom_in"
const CAM_ZOOM_OUT: StringName = &"cam_zoom_out"

# Developer only. Never referenced by gameplay code.
const DEBUG_CONSOLE: StringName = &"debug_console"
const DEBUG_FREECAM: StringName = &"debug_freecam"
const DEBUG_PERF: StringName = &"debug_perf"
const DEBUG_SCREENSHOT: StringName = &"debug_screenshot"

## Every gameplay action, in the order a rebinding screen should list them.
const REBINDABLE: Array[StringName] = [
	MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT,
	RUN, SNEAK,
	INTERACT, INTERACT_CYCLE, CANCEL,
	INVENTORY, JOURNAL, MAP, PAUSE,
]

const STICK_DEADZONE: float = 0.25

## Keyboard until proven otherwise. A game that boots with a pad in hand switches on the first
## press, and one that boots on a keyboard never shows a pad button it has no pad for.
var _device: GameEnums.DeviceKind = GameEnums.DeviceKind.KEYBOARD_MOUSE


func _ready() -> void:
	_define_movement()
	_define_traversal()
	_define_interaction()
	_define_screens()
	_define_camera()
	_define_debug()
	# AFTER the defaults, never before: installing an override erases the default of the same
	# kind, so loading first would leave the defaults to overwrite the player's own choices.
	KeyBindings.load_all()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Log.info("input", "Registered %d input actions" % InputMap.get_actions().size())


## An autoload's `_input` sees every event before any screen does, so the device is already
## current when the screen that event opens draws its first prompt.
func _input(event: InputEvent) -> void:
	observe(event)


## Which kind of device the player last used. A prompt reads this, then asks
## `KeyBindings.text_for(action, device() == GameEnums.DeviceKind.GAMEPAD)` for the words.
func device() -> GameEnums.DeviceKind:
	return _device


## Feed one event through the rule, and announce a change. Public because the suite cannot press
## a key: `Input.parse_input_event` is buffered until a main-loop flush that never comes mid-run,
## the reason `InteractionSensor.cycle()` is public too.
func observe(event: InputEvent) -> void:
	_become(InputDevice.device_for(event, _device))


func _become(next: GameEnums.DeviceKind) -> void:
	if next == _device:
		return
	_device = next
	Events.input_device_changed.emit(next)


## The last pad was unplugged, so nothing can press a pad button and any prompt naming one is
## wrong. PLUGGING a pad in changes nothing until it is pressed: owning a pad is not using one.
## HOTPLUG CANNOT BE DRIVEN HEADLESS - no pad exists there - so the suite calls this handler
## directly, and the engine's own emission of `joy_connection_changed` is untested by construction.
func _on_joy_connection_changed(_pad: int, connected: bool) -> void:
	if not connected and Input.get_connected_joypads().is_empty():
		_become(GameEnums.DeviceKind.KEYBOARD_MOUSE)


## Put every rebindable action back to the binding declared in this file, and forget the
## override file. `KeyBindings` cannot do this alone and must not try: the defaults live here,
## which is the whole of ADR-0003.
func reset_bindings() -> void:
	KeyBindings.forget_all()
	_define_movement()
	_define_traversal()
	_define_interaction()
	_define_screens()
	Log.info("input", "Bindings reset to defaults")


func _define_movement() -> void:
	_define(MOVE_UP, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _pad(JOY_BUTTON_DPAD_UP)])
	_define(MOVE_DOWN, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _pad(JOY_BUTTON_DPAD_DOWN)])
	_define(MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _pad(JOY_BUTTON_DPAD_LEFT)])
	_define(MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _pad(JOY_BUTTON_DPAD_RIGHT)])


func _define_traversal() -> void:
	_define(RUN, [_key(KEY_SHIFT), _pad(JOY_BUTTON_LEFT_SHOULDER)])
	_define(SNEAK, [_key(KEY_CTRL), _pad(JOY_BUTTON_LEFT_STICK)])


func _define_interaction() -> void:
	# E and the gamepad south button are the primary. Enter is included because players
	# reach for it, and it costs nothing.
	_define(INTERACT, [_key(KEY_E), _key(KEY_ENTER), _pad(JOY_BUTTON_A)])
	# Cycling between overlapping targets. Shoulder button and mouse wheel both feel natural.
	_define(INTERACT_CYCLE, [_key(KEY_TAB), _pad(JOY_BUTTON_RIGHT_SHOULDER)])
	_define(CANCEL, [_key(KEY_ESCAPE), _pad(JOY_BUTTON_B)])


func _define_screens() -> void:
	_define(INVENTORY, [_key(KEY_I), _pad(JOY_BUTTON_Y)])
	_define(JOURNAL, [_key(KEY_J), _pad(JOY_BUTTON_BACK)])
	_define(MAP, [_key(KEY_M)])
	_define(PAUSE, [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)])


func _define_camera() -> void:
	_define(CAM_ZOOM_IN, [_wheel(MOUSE_BUTTON_WHEEL_UP)])
	_define(CAM_ZOOM_OUT, [_wheel(MOUSE_BUTTON_WHEEL_DOWN)])


func _define_debug() -> void:
	_define(DEBUG_CONSOLE, [_key(KEY_F1)])
	_define(DEBUG_FREECAM, [_key(KEY_F2)])
	_define(DEBUG_PERF, [_key(KEY_F3)])
	_define(DEBUG_SCREENSHOT, [_key(KEY_F12)])


## Replace an action wholesale. Erasing first makes this safe to call again after a rebind.
func _define(action: StringName, events: Array[InputEvent], deadzone: float = STICK_DEADZONE) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


## Physical keycodes, not keycodes: this way WASD stays in the same physical place on an
## AZERTY or Dvorak keyboard instead of scattering.
func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
