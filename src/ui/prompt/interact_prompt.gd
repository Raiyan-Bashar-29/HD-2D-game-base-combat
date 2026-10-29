extends Label
## The interaction prompt. Shows the verb and the object's name, and the refusal reason when
## the player is turned down.
##
## Every string here goes through `tr()`. There is no path in this file by which raw
## player-facing text can reach the screen, which is the point: the previous project
## accumulated ~200 hard-coded strings because the easy path was the wrong one.
##
## OWNS: the prompt text and its visibility.
## MUST NOT: decide what can be interacted with, or perform an interaction. It renders what
## the sensor announces.

## Seconds a refusal message stays up before the normal prompt returns.
const REFUSAL_SECONDS: float = 1.8

## THE TWO SETTINGS THIS LABEL CONSUMES, named here because this is the only file that can.
## `gameplay/show_interact_hints` is a preference about the PROMPT, and this node is the prompt;
## `accessibility/high_contrast_prompts` is a preference about how the prompt READS, and the
## outline it turns on is a property of this Label. Neither had a consumer before T5.5, and both
## were drawn to the player and translated in both languages the whole time.
const HINTS_SETTING: String = "gameplay/show_interact_hints"
const CONTRAST_SETTING: String = "accessibility/high_contrast_prompts"
## Outline width in pixels when high contrast is on. THREE VALUES WERE PHOTOGRAPHED and this is
## the one that survived, which is the only way to pick a number like this: at 6 the outline
## swamped the glyphs of an 18px font and the crop was HARDER to read than the plain prompt -
## the opposite of what the setting is for - and at 2 it was invisible against the courtyard's
## bright grass. At 4 the halo separates the text from the ground and the letterforms survive.
const OUTLINE_PIXELS: int = 4
## The theme type the palette colours live under, spelled the same way the HUD spells it.
const PALETTE: StringName = &"UiPalette"
## The button that performs the verb, e.g. "[E]". Until T6.2 the prompt named the verb and never
## the button, so a pad player was never told which one to press. The words come from
## `KeyBindings.text_for` for whichever device `Actions` last saw, so a rebinding shows up here
## too. A translatable WRAPPER, because the brackets are layout that a language may lay out
## differently. Where an icon sheet will plug in instead is `docs/ART_CONTRACT.md` § Button prompts.
const BUTTON_KEY: String = "ui.prompt.button"

var _sensor: InteractionSensor = null
var _target: Node3D = null
var _verb: GameEnums.InteractVerb = GameEnums.InteractVerb.LOOK
var _label_key: String = ""
var _refusal_left: float = 0.0
## A screen is covering the world. Gameplay UI has nothing to say while that is true.
var _ui_blocked: bool = false


func _ready() -> void:
	# _and_offsets_ matters: set_anchors_preset alone leaves the offsets at zero, which gives a
	# zero-width box and text that spills off the left edge of the screen.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offset_top = -110.0
	offset_bottom = -60.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	visible = false

	Events.interact_target_changed.connect(_on_target_changed)
	Events.interaction_refused.connect(_on_refused)
	Events.player_spawned.connect(_on_player_spawned)
	Events.ui_mode_changed.connect(_on_ui_mode_changed)
	Events.setting_changed.connect(_on_setting_changed)
	Events.input_device_changed.connect(_on_device_changed)
	_apply_contrast()
	if Director.player != null:
		_on_player_spawned(Director.player)


func _process(delta: float) -> void:
	if _refusal_left > 0.0:
		_refusal_left -= delta
		if _refusal_left > 0.0:
			return
		_redraw()
	elif _sensor != null and _target != null and _sensor.hold_progress() > 0.0:
		_redraw()


func _on_player_spawned(player: Node3D) -> void:
	_sensor = player.get_node_or_null(^"InteractionSensor") as InteractionSensor


func _on_target_changed(target: Node3D, verb: GameEnums.InteractVerb, label_key: String) -> void:
	_target = target
	_verb = verb
	_label_key = label_key
	if _refusal_left <= 0.0:
		_redraw()


func _on_refused(_target: Node3D, reason: GameEnums.RefusalReason, args: Dictionary,
		message_key: String) -> void:
	# An authored line wins over the one computed from the reason; see events.gd.
	var key: String = message_key if message_key != "" else _refusal_key(reason)
	text = tr(key).format(args)
	visible = true
	_refusal_left = REFUSAL_SECONDS


func _on_ui_mode_changed(mode: GameEnums.UiMode) -> void:
	_ui_blocked = mode != GameEnums.UiMode.GAMEPLAY
	if _ui_blocked:
		_refusal_left = 0.0
	_redraw()


func _redraw() -> void:
	# A refusal is NOT a hint and is shown either way: the player pressed a button and is owed
	# an answer. Turning hints off silences the standing prompt, not the reply to a press.
	if _ui_blocked or _target == null or not Settings.get_bool(HINTS_SETTING):
		text = ""
		visible = false
		return
	var line: String = "%s  %s  %s" % [
		_button_text(), tr(_verb_key(_verb)), tr(_label_key) if _label_key != "" else ""
	]
	# A hold interaction shows its progress, so the player knows to keep holding rather than
	# concluding the button is broken.
	if _sensor != null:
		var progress: float = _sensor.hold_progress()
		if progress > 0.0:
			line += "  [%s]" % "=".repeat(maxi(1, roundi(progress * 10.0)))
	text = line.strip_edges()
	visible = true


## Empty when the action has no binding on this device, so the prompt still names the verb rather
## than drawing an empty "[]".
func _button_text() -> String:
	var pad: bool = Actions.device() == GameEnums.DeviceKind.GAMEPAD
	var words: String = KeyBindings.text_for(Actions.INTERACT, pad)
	return tr(BUTTON_KEY).format({"key": words}) if words != "" else ""


## A standing refusal is left alone: it is the reply to a press, and redrawing would cut it short.
func _on_device_changed(_device: GameEnums.DeviceKind) -> void:
	if _refusal_left <= 0.0:
		_redraw()


## Enum name to localization key: USE -> "verb.use". Keeps the key list mechanical, so a new
## verb cannot be added without a matching key showing up as a missing translation.
func _verb_key(verb: GameEnums.InteractVerb) -> String:
	var names: Array = GameEnums.InteractVerb.keys()
	var raw: String = names[verb]
	return "verb.%s" % raw.to_lower()


func _refusal_key(reason: GameEnums.RefusalReason) -> String:
	var names: Array = GameEnums.RefusalReason.keys()
	var raw: String = names[reason]
	return "refusal.%s" % raw.to_lower()


## An outline rather than a background box, because the prompt is centred over the world and a
## box would occlude what the player is about to interact with. The outline colour comes from the
## project theme's palette, so a game that restyles the UI restyles this too and nothing here
## names a colour.
func _apply_contrast() -> void:
	if not Settings.get_bool(CONTRAST_SETTING):
		remove_theme_constant_override(&"outline_size")
		remove_theme_color_override(&"font_outline_color")
		return
	add_theme_constant_override(&"outline_size", OUTLINE_PIXELS)
	add_theme_color_override(&"font_outline_color", get_theme_color(&"solid", PALETTE))


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	var path: String = "%s/%s" % [section, key]
	if path == CONTRAST_SETTING:
		_apply_contrast()
	elif path == HINTS_SETTING:
		_redraw()
