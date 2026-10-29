class_name SettingsScreen
extends MenuScreen
## Every row in `Settings.DEFAULTS`, on screen and changeable. The first consumer the settings
## file has ever had for most of what it declares.
##
## IT IS GENERATED FROM DEFAULTS, NOT HAND-LISTED. Adding a setting is one line in
## `settings.gd` and one row in the CSV; this file does not change, and there is no second list
## to fall out of step with the first. A hand-listed screen is how a setting ends up declared,
## saved, and unreachable.
##
## SO THE ROW LABELS ARE COMPUTED KEYS - `ui.settings.video.bloom` from `video/bloom` - and no
## text scan can find them. They are asserted mechanically instead, by a loop over DEFAULTS in
## `tests/unit/menus_test.gd`, exactly as the prompt's verb keys and the inventory's category
## keys are. That is better verification than a scan, not worse.
##
## ONE GESTURE CHANGES A ROW: press it, or push left or right on it. Left and right are handled
## in `_input`, which runs BEFORE the viewport's own focus navigation, because otherwise a
## horizontal press in a vertical list is swallowed hunting for a neighbour that is not there.
##
## OWNS: how a setting is presented and how one press changes it.
## MUST NOT: apply a setting. `Settings` announces `setting_changed` and the owning system
## reacts - which is why this screen can cover all 23 rows without knowing what any of them do.

const SCREEN_ID: StringName = &"settings"
const TITLE_KEY: String = "ui.settings.title"
const HINT_KEY: String = "ui.settings.hint"
const ROW_KEY: String = "ui.settings.row"
const LABEL_PREFIX: String = "ui.settings."
const SECTION_PREFIX: String = "ui.settings.section."
const ON_KEY: String = "ui.settings.on"
const OFF_KEY: String = "ui.settings.off"
const UNLIMITED_KEY: String = "ui.settings.unlimited"
const PERCENT_KEY: String = "ui.settings.value.percent"
const MULTIPLIER_KEY: String = "ui.settings.value.multiplier"
const RESET_KEY: String = "ui.settings.reset"
## The section a setting with no slash belongs to. `Settings._split` uses the same word.
const GENERAL: String = "general"

## Low, high and step for every float row. A percentage row is one whose high is 1.0; that is
## read from this table rather than declared twice.
const RANGES: Dictionary = {
	"video/resolution_scale": [0.5, 2.0, 0.25],
	"audio/master": [0.0, 1.0, 0.1],
	"audio/music": [0.0, 1.0, 0.1],
	"audio/ambience": [0.0, 1.0, 0.1],
	"audio/sfx": [0.0, 1.0, 0.1],
	"audio/ui": [0.0, 1.0, 0.1],
	"gameplay/text_speed": [0.25, 3.0, 0.25],
	"gameplay/camera_shake": [0.0, 1.0, 0.1],
	"accessibility/text_scale": [0.75, 2.0, 0.25],
}

## The values an int row may take, in the order pressing it walks them.
const CHOICES: Dictionary = {
	"video/window_mode": [0, 1, 2],
	"video/vsync": [0, 1, 2, 3],
	"video/max_fps": [0, 30, 60, 120, 144, 240],
}

## Int rows whose values are names rather than numbers, so `2` reads as "Exclusive fullscreen".
const NAMED: Array[String] = ["video/window_mode", "video/vsync"]

## One entry per row in draw order, empty for a heading or the reset row. A parallel array
## rather than metadata on the Button: `get_meta` hands back a Variant, and this project
## compiles an unsafe cast as an error.
var _paths: Array[String] = []


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## BEFORE the viewport's focus navigation, which is why this is _input and not
## _unhandled_input. ui_left and ui_right in a single-column list would otherwise be consumed
## looking for a horizontal neighbour, and the row would never hear them.
func _input(event: InputEvent) -> void:
	var direction: int = 0
	if event.is_action_pressed(&"ui_right"):
		direction = 1
	elif event.is_action_pressed(&"ui_left"):
		direction = -1
	if direction == 0:
		return
	var path: String = focused_path()
	if path == "":
		return
	get_viewport().set_input_as_handled()
	step(path, direction)


func _fill() -> void:
	_paths.clear()
	var section: String = ""
	for path: String in Settings.DEFAULTS:
		var head: String = path.get_slice("/", 0) if path.contains("/") else GENERAL
		if head != section:
			section = head
			add_note(tr("%s%s" % [SECTION_PREFIX, section]))
			_paths.append("")
		add_row(row_text(path), step.bind(path, 1))
		_paths.append(path)
	add_row(tr(RESET_KEY), _on_reset)
	_paths.append("")


## Move one row's value. `direction` is +1 or -1 and every row wraps, so a single gesture can
## reach every value and no row can be walked into a corner it cannot leave.
##
## Public because no assertion can press a key: TestCase.run() is synchronous, so the suite
## drives this directly and the windowed probe proves the key path separately.
func step(path: String, direction: int) -> void:
	if not Settings.DEFAULTS.has(path):
		return
	var value: Variant = Settings.get_value(path)
	if value is bool:
		Settings.set_value(path, not Settings.get_bool(path))
	elif value is String:
		Settings.set_value(path, _next_locale(direction))
	elif CHOICES.has(path):
		Settings.set_value(path, _next_choice(path, direction))
	else:
		Settings.set_value(path, _next_float(path, direction))
	_redraw(path)


## The path of the row that has focus, or "" for a heading, the reset row, or no focus at all.
func focused_path() -> String:
	if rows == null:
		return ""
	for index: int in mini(_paths.size(), rows.get_child_count()):
		var button: Button = rows.get_child(index) as Button
		if button != null and button.has_focus():
			return _paths[index]
	return ""


## "Bloom            On". Public so a test reads the same string the player does rather than
## re-deriving it and asserting its own arithmetic.
func row_text(path: String) -> String:
	return tr(ROW_KEY).format({"label": tr(label_key(path)), "value": value_text(path)})


static func label_key(path: String) -> String:
	return "%s%s" % [LABEL_PREFIX, path.replace("/", ".")]


func value_text(path: String) -> String:
	var value: Variant = Settings.get_value(path)
	if value is bool:
		return tr(ON_KEY) if Settings.get_bool(path) else tr(OFF_KEY)
	if value is String:
		return Settings.get_string(path)
	if CHOICES.has(path):
		return _choice_text(path)
	return _float_text(path)


## Only the row that changed, and its focus is left alone. A full refresh() here would rebuild
## every button and hand focus back to the first row, so holding right on a volume would walk
## you to the top of the screen instead of turning it up.
func _redraw(path: String) -> void:
	for index: int in mini(_paths.size(), rows.get_child_count()):
		if _paths[index] != path:
			continue
		var button: Button = rows.get_child(index) as Button
		if button != null:
			button.text = row_text(path)
		return


func _choice_text(path: String) -> String:
	var current: int = Settings.get_int(path)
	if NAMED.has(path):
		return tr("%s.%d" % [label_key(path), current])
	return tr(UNLIMITED_KEY) if current == 0 else str(current)


func _float_text(path: String) -> String:
	var current: float = Settings.get_float(path)
	if _high(path) <= 1.0:
		return tr(PERCENT_KEY).format({"percent": roundi(current * 100.0)})
	return tr(MULTIPLIER_KEY).format({"value": "%.2f" % current})


func _next_choice(path: String, direction: int) -> Variant:
	var options: Array = DictRead.get_array(CHOICES, path)
	if options.is_empty():
		return Settings.get_value(path)
	var at: int = maxi(0, options.find(Settings.get_int(path)))
	return options[wrapi(at + direction, 0, options.size())]


## Snapped to the step before comparing, so a value hand-edited into settings.cfg between two
## steps lands on the grid instead of carrying its offset forever.
func _next_float(path: String, direction: int) -> float:
	var low: float = _bound(path, 0, 0.0)
	var high: float = _high(path)
	var step_size: float = maxf(0.01, _bound(path, 2, 0.1))
	var next: float = snappedf(Settings.get_float(path), step_size) + step_size * float(direction)
	if next > high + step_size * 0.5:
		return low
	if next < low - step_size * 0.5:
		return high
	return clampf(next, low, high)


func _next_locale(direction: int) -> String:
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	if locales.is_empty():
		return Settings.get_string("locale")
	var at: int = maxi(0, locales.find(Settings.get_string("locale")))
	return locales[wrapi(at + direction, 0, locales.size())]


func _high(path: String) -> float:
	return _bound(path, 1, 1.0)


func _bound(path: String, index: int, fallback: float) -> float:
	var raw: Array = DictRead.get_array(RANGES, path)
	if index >= raw.size():
		return fallback
	return DictRead.to_float(raw[index])


## Every row back to its declared default, and the whole screen redrawn - this is the one action
## that changes rows other than the focused one.
func _on_reset() -> void:
	Settings.reset_to_defaults()
	refresh()
