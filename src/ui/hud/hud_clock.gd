extends Label
## The clock readout. The whole HUD, for now, and deliberately the whole of this file.
##
## WHY THIS IS ITS OWN NODE AND NOT A "Hud" THAT OWNS EVERYTHING
## The prompt and the toasts already exist as siblings under `UILayer`, each listening to the
## bus for the one thing it draws. A `Hud` node that adopted them would put three unrelated
## concerns behind one parent whose only job is to forward signals, and the next readout —
## weather, an objective, a day counter — would join it rather than stand on its own. So the
## HUD is a *layer*, not a class: independent readouts, each subscribing to what it shows.
##
## It is PAUSABLE on purpose. Behind an open menu no in-game minute passes, so a clock that
## kept ticking would be lying. Pause table: src/ui/root/ui_root.gd.
##
## OWNS: the rendering of the current time.
## MUST NOT: advance time, decide what an hour means, or read any other system. It draws what
## `Clock` announces.

const CLOCK_KEY: String = "ui.hud.clock"
const PHASE_PREFIX: String = "time.phase."
## The theme role this readout draws in. Its size and colour come from `gui/theme/custom` —
## see assets/theme/ui_theme.tres. Until T2.1 the size was a constant here.
const VARIATION: StringName = &"HudText"
const PALETTE: StringName = &"UiPalette"


func _ready() -> void:
	# _and_offsets_ matters: set_anchors_preset alone leaves every offset at zero and the text
	# lands off the corner of the screen. TOP_WIDE with a right alignment rather than
	# TOP_RIGHT, so the box has a real width to align inside.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	offset_top = 24.0
	offset_bottom = 72.0
	offset_right = -32.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = VARIATION
	add_theme_color_override(&"font_color", get_theme_color(&"text", PALETTE))

	Events.minute_passed.connect(_on_minute_passed)
	_redraw(Clock.day, Clock.hour, Clock.minute)


func _on_minute_passed(day: int, hour: int, minute: int) -> void:
	_redraw(day, hour, minute)


## One placeholder per fact, so a translator may reorder them and a 12-hour locale can put the
## phase first. Never assembled by concatenation.
func _redraw(day: int, hour: int, minute: int) -> void:
	text = tr(CLOCK_KEY).format({
		"day": day,
		"time": "%02d:%02d" % [hour, minute],
		"phase": tr(_phase_key(Clock.phase_for_hour(hour))),
	})


## Enum name to key: DEEP_NIGHT -> "time.phase.deep_night". Mechanical, exactly like the
## prompt's verb keys, so a new phase cannot be added without a missing translation showing up.
func _phase_key(phase: GameEnums.DayPhase) -> String:
	var names: Array = GameEnums.DayPhase.keys()
	var raw: String = names[phase]
	return "%s%s" % [PHASE_PREFIX, raw.to_lower()]
