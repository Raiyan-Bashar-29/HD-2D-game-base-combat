class_name DefenceCue
extends Label
## The defence prompt on screen (C8.20): "Evade!" or "Block!" in the middle of the view.
##
## IN PLAIN WORDS: it listens to `Events.defence_prompt`. A kind shows its words until
## `seconds` (at least `LEAST`) have passed or an empty kind clears it.
##
## OWNS: showing the prompt.
## MUST NOT: decide when to warn (`DefenceWatch` does) or read input.

const KEYS: Dictionary[StringName, String] = {&"evade": "ui.combat.defence.evade", &"block": "ui.combat.defence.block"}
## The shortest time a prompt stays up, so a fast hit's warning can still be read.
const LEAST: float = 0.4
const VARIATION: StringName = &"HudText"
const PALETTE: StringName = &"UiPalette"

var _left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = VARIATION
	add_theme_color_override(&"font_color", get_theme_color(&"accent", PALETTE))
	visible = false
	Events.defence_prompt.connect(show_prompt)


func _process(delta: float) -> void:
	if visible:
		_left -= delta
		if _left <= 0.0:
			visible = false


## Shows `kind`'s words for `seconds`; an unknown or empty kind hides it.
func show_prompt(kind: StringName, seconds: float) -> void:
	visible = KEYS.has(kind)
	if visible:
		text = tr(KEYS[kind])
		_left = maxf(seconds, LEAST)
