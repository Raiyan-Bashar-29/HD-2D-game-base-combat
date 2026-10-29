class_name InputDevice
extends RefCounted
## Which kind of device an input event came from. The PURE half of "which device is active":
## one static function, no state, so every rule it applies is assertable without a window, a
## pad or a main loop. `Actions` holds the answer and announces a change; this only decides.
##
## TWO EVENTS ARE DELIBERATELY NOT A SWITCH, and each is a real complaint about real games.
##   Mouse MOTION. A desk gets bumped, a cable drags the mouse a pixel, and a player holding a
##   pad watches every prompt flicker to "E". A mouse CLICK is a switch; moving it is not.
##   A stick under the deadzone. An idle stick drifts, and a pad lying on the sofa would pull
##   a keyboard player's prompts to pad buttons. The threshold is `Actions.STICK_DEADZONE`,
##   the number the InputMap's own actions use, so a stick too gentle to move the player is too
##   gentle to change what the prompts say.
## Anything else this function does not recognise — touch, MIDI, a synthesised action event —
## keeps the previous answer, for the same reason: not knowing is not evidence of a switch.
##
## OWNS: the rule for which events count as picking a device up.
## MUST NOT: hold state, emit a signal, or read the InputMap. `Actions` owns the current device.


static func device_for(event: InputEvent, previous: GameEnums.DeviceKind) -> GameEnums.DeviceKind:
	if event is InputEventJoypadButton:
		return GameEnums.DeviceKind.GAMEPAD
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		if absf(motion.axis_value) >= Actions.STICK_DEADZONE:
			return GameEnums.DeviceKind.GAMEPAD
		return previous
	if event is InputEventKey or event is InputEventMouseButton:
		return GameEnums.DeviceKind.KEYBOARD_MOUSE
	return previous
