class_name CombatActions
extends RefCounted
## The action-combat inputs (C3.1): attack, dodge, lock on, cycle the locked target, and open the
## hybrid's command menu (C4.4).
##
## IN PLAIN WORDS: upstream's `Actions` autoload defines every other input at boot, and this
## fork may not edit it (ADR-0008), so the combat actions live here and `ActionHost` calls
## `install()` once when the game starts. After that they are ordinary InputMap actions:
## `Input.is_action_just_pressed(CombatActions.ATTACK)` works anywhere.
##
## THE BINDINGS AVOID EVERY KEY AND BUTTON ALREADY TAKEN. The plan's J for attack is the
## journal's, so attack is K. Pad X, the right stick click and both triggers were the free pad
## inputs. Space is also the engine's own `ui_accept`, which only matters inside menus, and the
## field fighter ignores input while a menu holds the input lock. `combat_input_test.gd` fails
## if a later binding anywhere collides with one of these.
##
## THE COMMAND MENU HAS NO STANDARD PAD BUTTON LEFT (C4.4). A, B, X, Y, both shoulders, both
## stick clicks, both triggers, Back and Start are all someone's by then, so it sits on F and on
## the pad's extra centre button (`JOY_BUTTON_MISC1`: Share, Capture or the like, depending on
## the pad). A game wanting it elsewhere rebinds it once the C5.3 seam exists. The party switch
## (C4.7) is on C and the pad's first back paddle (`JOY_BUTTON_PADDLE1`), for the same reason:
## a pad without paddles switches from the keyboard until C5.3.
##
## NOT YET REBINDABLE. `KeyBindings.rebind` accepts only `Actions.REBINDABLE`, an upstream list;
## the seam that lets a game add to it is C5.3.
##
## OWNS: the names and default bindings of the combat actions.
## MUST NOT: touch any other action, or overwrite a combat action already installed.

const ATTACK: StringName = &"combat_attack"
const DODGE: StringName = &"combat_dodge"
const LOCK_ON: StringName = &"combat_lock_on"
const LOCK_CYCLE: StringName = &"combat_lock_cycle"
## Opens the hybrid's command menu mid-fight (C4.4).
const COMMAND: StringName = &"combat_command"
## Hands control to the next party member in the field (C4.7).
const SWITCH: StringName = &"combat_switch"
const ALL: Array[StringName] = [ATTACK, DODGE, LOCK_ON, LOCK_CYCLE, COMMAND, SWITCH]
## A trigger is an axis from 0 to 1; half-way down counts as pressed.
const TRIGGER_DEADZONE: float = 0.5


## Defines each combat action that does not exist yet. Safe to call again: an action already
## in the InputMap is left exactly as it is.
static func install() -> void:
	_define(ATTACK, [_key(KEY_K), _pad(JOY_BUTTON_X)])
	_define(DODGE, [_key(KEY_SPACE), _trigger(JOY_AXIS_TRIGGER_RIGHT)])
	_define(LOCK_ON, [_key(KEY_Q), _trigger(JOY_AXIS_TRIGGER_LEFT)])
	_define(LOCK_CYCLE, [_key(KEY_R), _pad(JOY_BUTTON_RIGHT_STICK)])
	_define(COMMAND, [_key(KEY_F), _pad(JOY_BUTTON_MISC1)])
	_define(SWITCH, [_key(KEY_C), _pad(JOY_BUTTON_PADDLE1)])


static func _define(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, TRIGGER_DEADZONE)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


## Physical keycodes, `Actions`' rule, so the keys stay put on AZERTY and Dvorak.
static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _trigger(axis: JoyAxis) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = 1.0
	return event
