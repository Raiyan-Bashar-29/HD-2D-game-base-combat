class_name UiAccessibility
extends Node
## The consumer of `accessibility/text_scale`, and the reason that setting is not a game's
## problem to wire.
##
## WHY THIS FILE EXISTS AT ALL. `accessibility/*` was declared in `settings.gd` from WP-01,
## drawn to the player by `settings_screen.gd` since it was written, translated in both
## languages, and read by nothing. That is the characteristic defect of this project, but it is
## worse than the usual instance: a game forked from this base **could not** wire an
## accessibility setting without editing `src/`, because the thing that has to change is the
## project theme every screen in `src/ui/` already draws from. So it was a TEMPLATE defect, not
## a missing feature of a game, and the fix belongs here.
##
## IT SCALES THE THEME, NOT THE WINDOW. `Window.content_scale_factor` is the one-line
## alternative and it is wrong: it magnifies every pixel of the UI including the HUD's layout
## and the dialogue frame's margins, so a player who wants larger text gets a larger everything
## and less of the world on screen. Scaling only `font_size` is what "text size" means.
##
## AND IT SCALES FROM A CACHED BASE, NEVER FROM THE CURRENT VALUE. Multiplying the live size
## compounds - two steps to 1.5 would land on 2.25 - and rounds to integers on the way, so
## walking the row up and down would not return to where it started. The authored sizes are read
## once, before anything is touched.
##
## OWNS: the project theme's font sizes at runtime.
## MUST NOT: know which screens exist, or reach into a Control. A theme change propagates
## through `theme_changed` on its own; that is what a project theme is for.

const TEXT_SCALE: String = "accessibility/text_scale"
const SECTION: String = "accessibility"

var _theme: Theme = null
## "<theme type>/<font size name>" -> the size the .tres file authored.
var _base: Dictionary[String, int] = {}
var _base_default: int = 0


func _ready() -> void:
	_theme = ThemeDB.get_project_theme()
	if _theme == null:
		Log.warn("ui", "No project theme — accessibility/text_scale has nothing to scale")
		return
	_cache_base()
	Events.setting_changed.connect(_on_setting_changed)
	apply()


## Public because no assertion can press a settings row, and because the suite has to be able to
## put the theme back: a test that scales the shared project theme and leaves it scaled would
## change every assertion that runs after it.
func apply() -> void:
	if _theme == null:
		return
	var scale: float = clampf(Settings.get_float(TEXT_SCALE), 0.5, 3.0)
	for path: String in _base:
		var parts: PackedStringArray = path.split("/", false, 1)
		if parts.size() != 2:
			continue
		_theme.set_font_size(StringName(parts[1]), StringName(parts[0]), _scaled(path, scale))
	_theme.default_font_size = maxi(1, roundi(float(_base_default) * scale))
	Log.debug("ui", "Text scale -> %.2f over %d font size(s)" % [scale, _base.size()])


## The size one entry lands on at `scale`. Public so a test asserts the same arithmetic the
## screen gets rather than re-deriving it.
func scaled_size(theme_type: String, size_name: String, scale: float) -> int:
	return _scaled("%s/%s" % [theme_type, size_name], scale)


## `default_font_size` is -1 in the authored theme, meaning "use the engine's". Resolving it to
## the fallback here is what lets a Control with no `theme_type_variation` scale too - and there
## are such Controls, because the toast and the prompt are plain Labels.
func _cache_base() -> void:
	for theme_type: String in _theme.get_font_size_type_list():
		for size_name: String in _theme.get_font_size_list(theme_type):
			_base["%s/%s" % [theme_type, size_name]] = _theme.get_font_size(
					StringName(size_name), StringName(theme_type))
	var authored: int = _theme.default_font_size
	_base_default = authored if authored > 0 else ThemeDB.get_fallback_font_size()


func _scaled(path: String, scale: float) -> int:
	if not _base.has(path):
		return 1
	return maxi(1, roundi(float(_base[path]) * scale))


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == SECTION and "%s/%s" % [section, key] == TEXT_SCALE:
		apply()
