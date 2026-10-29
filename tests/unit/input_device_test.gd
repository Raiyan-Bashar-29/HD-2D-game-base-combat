extends TestCase
## The base knows which input device is active, and the two prompts that name a button follow it.
##
## THREE LAYERS, ASSERTED SEPARATELY, because each can be broken without the others noticing:
## the RULE (`InputDevice.device_for`, pure), the STATE (`Actions` holds the answer and emits only
## on a change), and the CONSUMERS (the interact prompt and the dialogue hint redraw). A rule that
## is right and a signal nobody listens to leaves the screen exactly as wrong as before.
##
## EVENTS ARE FED THROUGH `Actions.observe`, NOT PRESSED. The suite cannot press anything —
## `Input.parse_input_event` is buffered until a main-loop flush that never comes mid-run — so the
## one line not covered here is `Actions._input` calling `observe`, which is a single call.
##
## AND HOTPLUG CANNOT BE DRIVEN HEADLESS AT ALL: there is no pad to unplug. The handler is called
## directly with the arguments the engine would pass; that the engine does pass them is not
## asserted anywhere, and nothing in a headless run could assert it.
##
## OWNS: assertions about which device is active and who hears about it.
## MUST NOT: assert what a binding's words ARE. `KeyBindings` owns that, and a rebinding or an
## engine rename of "Bottom Action" must not break this case — so it compares against
## `KeyBindings.text_for` rather than spelling any key.

const KB: GameEnums.DeviceKind = GameEnums.DeviceKind.KEYBOARD_MOUSE
const PAD: GameEnums.DeviceKind = GameEnums.DeviceKind.GAMEPAD
const PROMPT_SCRIPT: GDScript = preload("res://src/ui/prompt/interact_prompt.gd")

var _heard: Array[GameEnums.DeviceKind] = []


func run() -> void:
	plan(31)
	_the_rule()
	Actions.observe(_key())
	Events.input_device_changed.connect(_on_heard)
	_the_state()
	_the_unplug()
	_the_prompt()
	_the_dialogue_hint()
	Events.input_device_changed.disconnect(_on_heard)
	Actions.observe(_key())


func _on_heard(device: GameEnums.DeviceKind) -> void:
	_heard.append(device)


func _the_rule() -> void:
	equal("a key is the keyboard", InputDevice.device_for(_key(), PAD), KB)
	equal("a mouse click is the keyboard and mouse", InputDevice.device_for(_click(), PAD), KB)
	equal("a pad button is the pad", InputDevice.device_for(_button(), KB), PAD)
	equal("a stick pushed past the deadzone is the pad", InputDevice.device_for(_stick(0.9), KB), PAD)
	equal("pushed the other way too", InputDevice.device_for(_stick(-0.9), KB), PAD)
	equal("at exactly the deadzone it counts",
		InputDevice.device_for(_stick(Actions.STICK_DEADZONE), KB), PAD)
	# The two that must NOT switch, each asked from both sides so a rule that always answers one
	# device cannot pass by accident.
	equal("stick drift under the deadzone keeps the keyboard",
		InputDevice.device_for(_stick(Actions.STICK_DEADZONE * 0.5), KB), KB)
	equal("and keeps the pad", InputDevice.device_for(_stick(0.05), PAD), PAD)
	equal("mouse motion keeps the pad", InputDevice.device_for(_motion(), PAD), PAD)
	equal("and keeps the keyboard", InputDevice.device_for(_motion(), KB), KB)
	equal("an event it does not know keeps the answer",
		InputDevice.device_for(InputEventAction.new(), PAD), PAD)


func _the_state() -> void:
	equal("the suite starts on the keyboard", Actions.device(), KB)
	Actions.observe(_button())
	equal("a pad button switches the base", Actions.device(), PAD)
	equal("and is announced once, naming the pad", _heard, [PAD] as Array[GameEnums.DeviceKind])
	Actions.observe(_button())
	Actions.observe(_stick(0.9))
	equal("more pad input is not announced again", _heard.size(), 1)
	Actions.observe(_motion())
	equal("a bumped mouse leaves the pad active", Actions.device(), PAD)
	Actions.observe(_key())
	equal("a key switches back", Actions.device(), KB)
	equal("and that is the second announcement", _heard.size(), 2)


func _the_unplug() -> void:
	Actions.observe(_button())
	_heard.clear()
	Actions._on_joy_connection_changed(0, true)
	equal("plugging a pad in changes nothing", Actions.device(), PAD)
	Actions._on_joy_connection_changed(0, false)
	equal("the last pad unplugged falls back to the keyboard", Actions.device(), KB)
	equal("and says so", _heard, [KB] as Array[GameEnums.DeviceKind])


func _the_prompt() -> void:
	var prompt: Label = PROMPT_SCRIPT.new() as Label
	attach(prompt)
	var target := Node3D.new()
	attach(target)
	Events.interact_target_changed.emit(target, GameEnums.InteractVerb.USE, "")
	var keys: String = KeyBindings.text_for(Actions.INTERACT, false)
	var pads: String = KeyBindings.text_for(Actions.INTERACT, true)
	equal("interact has a key and a pad button, and they differ", keys != pads and pads != "", true)
	equal("the prompt names the key", prompt.text.contains("[%s]" % keys), true)
	Actions.observe(_button())
	equal("picking up the pad renames the button", prompt.text.contains("[%s]" % pads), true)
	equal("and the key is gone", prompt.text.contains("[%s]" % keys), false)
	equal("the verb survives the redraw", prompt.text.contains(tr("verb.use")), true)
	Actions.observe(_key())
	equal("and back", prompt.text.contains("[%s]" % keys), true)


func _the_dialogue_hint() -> void:
	var screen: DialogueScreen = DialogueScreen.for_conversation()
	attach(screen)
	var keys: String = KeyBindings.text_for(Actions.INTERACT, false)
	var pads: String = KeyBindings.text_for(Actions.INTERACT, true)
	equal("the hint names the interact key", screen._hint.text.contains(keys), true)
	equal("and no longer promises Space, which advances nothing",
		screen._hint.text.begins_with("Space"), false)
	Actions.observe(_button())
	equal("mid-conversation, the pad renames it", screen._hint.text.contains(pads), true)
	Actions.observe(_key())
	equal("and back", screen._hint.text.contains(keys), true)


func _key() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	return event


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _motion() -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(3.0, 1.0)
	return event


func _button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _stick(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event
