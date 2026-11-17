extends TestCase
## A game's own settings, added with `Settings.game.add` (T7.4), are settings like the built-in
## ones: read, written, saved, announced, reset, and drawn on the settings screen where a player
## can change them.
##
## THE BOOT ORDER IS ASSERTED, as T7.3's was for key bindings. `Settings` reads the file before any
## game code runs, so a value the player chose must come back when the game adds its setting
## afterwards, and not be replaced by the default. The case forgets the setting and adds it again,
## which is what a fresh boot does.
##
## THE CASE NEVER TOUCHES THE REAL LIST. It swaps a fresh `GameSettings` into `Settings.game` and
## puts the old one back at the end, so a game's settings, if any were added before it ran, are
## neither seen nor lost. It writes the settings file, the run's scratch copy (T6.11), and resets it.
##
## OWNS: assertions about `GameSettings`, `Settings.default_of`, and a game's rows on the settings
## screen.
## MUST NOT: name a game's setting. The ones here are made up for the case.

const SECTION: String = "game_settings_test"
const FLAG: String = "game_settings_test/flag"
const MODE: String = "game_settings_test/mode"
const LEVEL: String = "game_settings_test/level"
const SPEED: String = "game_settings_test/speed"
## In a built-in section, so its row must join that section rather than open a second one.
const SHARE: String = "gameplay/game_settings_test_share"
const MODES: Array = ["", "slow/low", "fast"]

var _real: GameSettings = null
var _stack: UiRoot = null
var _heard: Array[Array] = []


func run() -> void:
	plan(55)
	_real = Settings.game
	Settings.game = GameSettings.new(Settings.DEFAULTS)
	Settings.reset_to_defaults()
	Events.setting_changed.connect(_on_changed)
	_stack = UiRoot.new()
	attach(_stack)
	_refusals_add_nothing()
	_adding_lists_them_in_their_sections()
	_values_are_read_written_and_saved()
	_a_saved_value_survives_a_boot()
	_a_reset_puts_every_default_back()
	_the_screen_draws_and_steps_them()
	_tear_down()


func _refusals_add_nothing() -> void:
	var game: GameSettings = Settings.game
	equal("a built-in path is refused", game.add("video/bloom", false), false)
	equal("and keeps its own default", Settings.default_of("video/bloom"), true)
	equal("an empty path is refused", game.add("", true), false)
	equal("a kind a file cannot step is refused", game.add(FLAG, [true]), false)
	equal("an int with no choices is refused", game.add(LEVEL, 2), false)
	equal("a String with no choices is refused", game.add(MODE, ""), false)
	equal("a choice of another kind is refused", game.add(MODE, "", ["", 3]), false)
	equal("a default not among the choices is refused", game.add(LEVEL, 5, [1, 2, 3]), false)
	equal("so nothing was added", game.every().size(), Settings.DEFAULTS.size())
	equal("and an unknown path has no default", Settings.default_of(FLAG), null)


func _adding_lists_them_in_their_sections() -> void:
	var game: GameSettings = Settings.game
	equal("a bool is added", game.add(FLAG, true), true)
	equal("a String with choices is added", game.add(MODE, "", MODES), true)
	equal("an int with choices is added", game.add(LEVEL, 2, [1, 2, 3]), true)
	equal("a float with choices is added", game.add(SPEED, 1.0, [0.5, 1.0, 2.0]), true)
	equal("a float without them is added", game.add(SHARE, 0.5), true)
	game.add(FLAG, false)
	var every: Array[String] = game.every()
	equal("adding again lists it once", every.size(), Settings.DEFAULTS.size() + 5)
	equal("and changes its default", Settings.default_of(FLAG), false)
	equal("a new section comes after the built-ins, in the order added",
			every.slice(every.size() - 4), [FLAG, MODE, LEVEL, SPEED])
	equal("a built-in section's row comes at that section's end",
			every[every.find(SHARE) + 1].begins_with("accessibility/"), true)
	equal("a bool keeps no choices", game.choices_of(FLAG), [])
	equal("the choices are kept in order", game.choices_of(MODE), MODES)


func _values_are_read_written_and_saved() -> void:
	equal("the default is read", Settings.get_bool(FLAG), false)
	_heard.clear()
	Settings.set_value(FLAG, true)
	equal("a value is written", Settings.get_bool(FLAG), true)
	equal("and announced", _heard.has([SECTION, "flag", true]), true)
	Settings.set_value(FLAG, 3)
	equal("a value of another kind is refused", Settings.get_bool(FLAG), true)
	Settings.set_value(LEVEL, 3)
	equal("an int is written", Settings.get_int(LEVEL), 3)
	var file := ConfigFile.new()
	file.load(Settings.file_path)
	equal("and both are in the file", [file.get_value(SECTION, "flag", false),
			file.get_value(SECTION, "level", 0)], [true, 3])
	equal("a path nobody added still reads as nothing", Settings.get_value("%s/nobody" % SECTION), null)


## What a boot does: the file was read before the game added anything, so the setting is unknown
## until it is added, and then reads the player's value rather than the default.
func _a_saved_value_survives_a_boot() -> void:
	Settings.game = GameSettings.new(Settings.DEFAULTS)
	equal("before the game adds it, the setting is unknown", Settings.get_value(FLAG), null)
	Settings.game.add(FLAG, false)
	equal("once added, the saved value wins over the default", Settings.get_bool(FLAG), true)
	Settings.game.add(MODE, "", MODES)
	Settings.game.add(LEVEL, 2, [1, 2, 3])
	Settings.game.add(SPEED, 1.0, [0.5, 1.0, 2.0])
	Settings.game.add(SHARE, 0.5)
	equal("and the int too", Settings.get_int(LEVEL), 3)


func _a_reset_puts_every_default_back() -> void:
	_heard.clear()
	Settings.reset_to_defaults()
	equal("a reset puts a game's bool back", Settings.get_bool(FLAG), false)
	equal("and its int", Settings.get_int(LEVEL), 2)
	equal("and announces the game's default too", _heard.has([SECTION, "level", 2]), true)


func _the_screen_draws_and_steps_them() -> void:
	var screen := SettingsScreen.new()
	equal("the settings screen opens", _stack.open(screen), true)
	var rows: Array[String] = screen.row_texts()
	equal("a game's section has a heading", rows.has(tr("%s%s" % [SettingsScreen.SECTION_PREFIX, SECTION])), true)
	equal("and a row for each of its settings", rows.has(screen.row_text(MODE)), true)
	var heading: int = rows.find(tr("%saccessibility" % SettingsScreen.SECTION_PREFIX))
	equal("a row in a built-in section is drawn in it", rows.find(screen.row_text(SHARE)) == heading - 1, true)
	equal("a String value reads through its key", screen.value_text(MODE),
			tr(SettingsScreen.value_key(MODE, "")))
	equal("an empty value's key ends in none", SettingsScreen.value_key(MODE, "").ends_with(".mode.none"), true)
	equal("a slash in a value reads as a dot", SettingsScreen.value_key(MODE, "slow/low"),
			"ui.settings.game_settings_test.mode.slow.low")
	screen.step(MODE, 1)
	equal("a press walks a String's choices", Settings.get_string(MODE), "slow/low")
	screen.step(MODE, -1)
	screen.step(MODE, -1)
	equal("and wraps backwards", Settings.get_string(MODE), "fast")
	equal("and the row follows", screen.row_texts().has(screen.row_text(MODE)), true)
	Settings.set_value(LEVEL, 2.0)
	equal("an int stored as a float still reads as its number", screen.value_text(LEVEL), "2")
	screen.step(LEVEL, 1)
	equal("an int walks its choices", Settings.get_int(LEVEL), 3)
	equal("and reads as its number", screen.value_text(LEVEL), "3")
	screen.step(LEVEL, 1)
	equal("and wraps", Settings.get_int(LEVEL), 1)
	screen.step(SPEED, 1)
	equal("a float walks its choices", Settings.get_float(SPEED), 2.0)
	equal("and above 1.0 reads as a multiplier", screen.value_text(SPEED),
			tr(SettingsScreen.MULTIPLIER_KEY).format({"value": "2.00"}))
	screen.step(SHARE, 1)
	equal("a float without choices steps by a tenth", is_equal_approx(Settings.get_float(SHARE), 0.6), true)
	equal("and reads as a percentage", screen.value_text(SHARE),
			tr(SettingsScreen.PERCENT_KEY).format({"percent": 60}))
	screen.step(FLAG, 1)
	equal("a bool toggles", Settings.get_bool(FLAG), true)
	equal("the built-ins keep their own choices", screen.choices("video/vsync"), [0, 1, 2, 3])
	equal("cleanup", _stack.close_top(), true)


func _on_changed(section: String, key: String, value: Variant) -> void:
	_heard.append([section, key, value])


func _tear_down() -> void:
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	Events.setting_changed.disconnect(_on_changed)
	Settings.game = _real
	Settings.reset_to_defaults()
