extends TestCase
## Combat input and layers (C3.1, C4.4): the five action-combat actions exist after `install()`, on
## keys and pad buttons no other action already uses, installing twice changes nothing, the
## prompt text resolves, and the two new physics layers are named in `project.godot` exactly where
## `CombatLayers` says they are.
##
## OWNS: assertions about `CombatActions` and `CombatLayers`.
## MUST NOT: rebind anything the player chose; it only reads the InputMap after installing.

func run() -> void:
	plan(14)
	CombatActions.install()
	_the_actions()
	_the_layers()


func _the_actions() -> void:
	var all_there: bool = true
	for action: StringName in CombatActions.ALL:
		all_there = all_there and InputMap.has_action(action)
	equal("all five combat actions exist after install", all_there, true)
	equal("attack is on K", _has_key(CombatActions.ATTACK, KEY_K), true)
	equal("and on the pad's west button", _has_pad(CombatActions.ATTACK, JOY_BUTTON_X), true)
	equal("dodge is on the right trigger", _has_axis(CombatActions.DODGE, JOY_AXIS_TRIGGER_RIGHT), true)
	equal("the command menu is on F", _has_key(CombatActions.COMMAND, KEY_F), true)
	equal("and on the pad's extra centre button", _has_pad(CombatActions.COMMAND, JOY_BUTTON_MISC1), true)
	equal("no combat key or button is already another action's", _clashes(), [])
	var before: int = InputMap.action_get_events(CombatActions.ATTACK).size()
	CombatActions.install()
	equal("installing twice adds nothing", InputMap.action_get_events(CombatActions.ATTACK).size(), before)
	equal("a prompt can name the key", KeyBindings.text_for(CombatActions.ATTACK, false) != "", true)


func _the_layers() -> void:
	equal("layer 11 is named hitbox in project.godot",
		ProjectSettings.get_setting("layer_names/3d_physics/layer_11", ""), "hitbox")
	equal("layer 12 is named hurtbox", ProjectSettings.get_setting("layer_names/3d_physics/layer_12", ""), "hurtbox")
	equal("CombatLayers.HITBOX is layer 11", CombatLayers.HITBOX, 1 << 10)
	equal("CombatLayers.HURTBOX is layer 12", CombatLayers.HURTBOX, 1 << 11)
	equal("a hitbox looks for hurtboxes and nothing else", CombatLayers.HITBOX_MASK, CombatLayers.HURTBOX)


func _has_key(action: StringName, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == code:
			return true
	return false


func _has_pad(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		if pad != null and pad.button_index == button:
			return true
	return false


func _has_axis(action: StringName, axis: JoyAxis) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion != null and motion.axis == axis:
			return true
	return false


## Every "combat action: other action" pair that share a key, a pad button or a pad axis.
func _clashes() -> Array[String]:
	var out: Array[String] = []
	for action: StringName in CombatActions.ALL:
		for event: InputEvent in InputMap.action_get_events(action):
			for other: StringName in InputMap.get_actions():
				if other == action or CombatActions.ALL.has(other) or String(other).begins_with("ui_"):
					continue
				for theirs: InputEvent in InputMap.action_get_events(other):
					if _same(event, theirs):
						out.append("%s: %s" % [action, other])
	return out


func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	return false
