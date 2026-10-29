extends TestCase
## The two screens that CHANGE something the player keeps: settings and key bindings.
##
## THE HEADLINE ASSERTION IS _rebinding_replaces_one_half_and_persists(). It rebinds an action,
## re-declares the default over the top of it exactly as a fresh boot does, and then asks the
## override file to put it back. Nothing else in the ladder can catch a binding that is applied
## but never written, or written but never read: the boot run is clean either way, and a capture
## shows the row saying whatever the player just pressed regardless.
##
## THE SECOND IS _settings_covers_every_row(). The screen is generated from `Settings.DEFAULTS`,
## so this asserts the thing that generation is FOR: no setting can be declared, saved, and left
## with nowhere to change it. Seventeen of the twenty-three had exactly that shape until now.
##
## Driven by direct calls, never by simulated input: TestCase.run() is synchronous, so an input
## event never reaches the frame that would deliver it. The real key path - ui_left/ui_right on
## a focused row, and press-then-press to rebind - is proved by a temporary probe in
## dev_capture.gd, run windowed, read in the log, and then removed.
##
## THIS CASE WRITES THE SETTINGS AND BINDINGS FILES, and puts both back at tear-down. Both are the
## run's own scratch copies, T6.11 and T6.13; until T6.13 the bindings one was the player's real
## `user://input.cfg`, and the reset below deleted it on every run. Putting them back still
## matters inside a run: every later case reads the same two files.
##
## OWNS: assertions about stepping a setting and rebinding an action, and the computed keys both
## screens draw.
## MUST NOT: assert what raises a menu or what a slot header says. menus_test.gd owns those.

## Section headings plus the reset row: what the settings screen draws beyond one row per
## setting. Five sections, because `locale` has no slash and lands under "general".
const SETTINGS_EXTRA_ROWS: int = 6

var _stack: UiRoot = null


func run() -> void:
	plan(158)
	_stack = UiRoot.new()
	attach(_stack)
	_settings_covers_every_row()
	_a_press_changes_a_row_and_wraps()
	_floats_step_and_wrap()
	_rebinding_replaces_one_half_and_persists()
	_rebinding_listens_one_row_at_a_time()
	_every_computed_key_exists()
	_tear_down()


## Generated from DEFAULTS, so a setting cannot be declared, saved and left unreachable.
func _settings_covers_every_row() -> void:
	Settings.reset_to_defaults()
	var screen := SettingsScreen.new()
	equal("the settings screen opens", _stack.open(screen), true)
	var rows: Array[String] = screen.row_texts()
	equal("every setting has a row", rows.size(), Settings.DEFAULTS.size() + SETTINGS_EXTRA_ROWS)
	for path: String in Settings.DEFAULTS:
		equal("a row for %s" % path, rows.has(screen.row_text(path)), true)
	equal("the first line is a section heading", rows[0], tr("%svideo" % SettingsScreen.SECTION_PREFIX))
	equal("the last is the reset row", rows[rows.size() - 1], tr(SettingsScreen.RESET_KEY))
	equal("and something has focus, so a gamepad can reach it", _focused_text(screen) != "", true)


## One press moves one value, every row wraps, and the button on screen follows.
##
## `video/window_mode` is deliberately never stepped here. `Settings._apply_display` acts on it
## immediately, and a suite that left it at 2 would make the next windowed capture open
## exclusive-fullscreen.
func _a_press_changes_a_row_and_wraps() -> void:
	var screen: SettingsScreen = _top()
	equal("bloom starts on", screen.value_text("video/bloom"), tr(SettingsScreen.ON_KEY))
	screen.step("video/bloom", 1)
	equal("one press turns it off", Settings.get_bool("video/bloom"), false)
	equal("and the row says so", screen.value_text("video/bloom"), tr(SettingsScreen.OFF_KEY))
	equal("and the button on screen followed", _row_for(screen, "video/bloom"), screen.row_text("video/bloom"))
	screen.step("video/bloom", 1)
	equal("a second press turns it back on", Settings.get_bool("video/bloom"), true)

	equal("the frame cap starts uncapped", Settings.get_int("video/max_fps"), 0)
	equal("and reads as such", screen.value_text("video/max_fps"), tr(SettingsScreen.UNLIMITED_KEY))
	screen.step("video/max_fps", 1)
	equal("one press caps it", Settings.get_int("video/max_fps"), 30)
	equal("and the row prints the number", screen.value_text("video/max_fps"), "30")
	screen.step("video/max_fps", -1)
	equal("and back", Settings.get_int("video/max_fps"), 0)
	screen.step("video/max_fps", -1)
	equal("stepping below the first choice wraps to the last", Settings.get_int("video/max_fps"), 240)
	equal("a named int row reads as a name, not a number",
		screen.value_text("video/vsync"), tr("%s.1" % SettingsScreen.label_key("video/vsync")))


func _floats_step_and_wrap() -> void:
	var screen: SettingsScreen = _top()
	equal("master volume starts at 0.9", is_equal_approx(Settings.get_float("audio/master"), 0.9), true)
	equal("and reads as a percentage", screen.value_text("audio/master"),
		tr(SettingsScreen.PERCENT_KEY).format({"percent": 90}))
	screen.step("audio/master", 1)
	equal("one press raises it to the top", is_equal_approx(Settings.get_float("audio/master"), 1.0), true)
	screen.step("audio/master", 1)
	equal("past the top it wraps to the bottom", is_equal_approx(Settings.get_float("audio/master"), 0.0), true)
	screen.step("audio/master", -1)
	equal("and below the bottom back to the top", is_equal_approx(Settings.get_float("audio/master"), 1.0), true)

	equal("a multiplier row is not drawn as a percentage", screen.value_text("gameplay/text_speed"),
		tr(SettingsScreen.MULTIPLIER_KEY).format({"value": "1.00"}))
	equal("the language row shows the loaded locale", screen.value_text("locale"), Settings.get_string("locale"))
	screen.step("no/such/setting", 1)
	equal("a path DEFAULTS never heard of changes nothing", Settings.get_bool("video/bloom"), true)
	equal("cleanup", _stack.close_top(), true)


## THE HEADLINE. See the file header.
func _rebinding_replaces_one_half_and_persists() -> void:
	var screen := RebindScreen.new()
	equal("the controls screen opens", _stack.open(screen), true)
	equal("a row per rebindable action, plus reset", screen.row_texts().size(), Actions.REBINDABLE.size() + 1)
	equal("nothing is listening yet", screen.listening(), &"")

	var pad_before: String = KeyBindings.text_for(Actions.INVENTORY, true)
	equal("the inventory has a default key", _has_key(Actions.INVENTORY, KEY_I), true)
	equal("and a default pad button", pad_before != "", true)

	equal("rebinding it to K is accepted",
		KeyBindings.rebind(Actions.INVENTORY, KeyBindings.event_for_key(KEY_K)), true)
	equal("K is bound", _has_key(Actions.INVENTORY, KEY_K), true)
	equal("I is gone", _has_key(Actions.INVENTORY, KEY_I), false)
	equal("the pad half is untouched", KeyBindings.text_for(Actions.INVENTORY, true), pad_before)
	equal("and an analogue stick is never erased", _has_axis(Actions.MOVE_UP), true)
	equal("the row on screen names the new key", screen.row_text(Actions.INVENTORY).contains("K"), true)
	_a_fresh_boot_puts_it_back()

	equal("a mouse button cannot be bound",
		KeyBindings.rebind(Actions.INVENTORY, InputEventMouseButton.new()), false)
	equal("nor can an action nobody declared",
		KeyBindings.rebind(&"not_an_action", KeyBindings.event_for_key(KEY_K)), false)

	Actions.reset_bindings()
	equal("reset puts the default back", _has_key(Actions.INVENTORY, KEY_I), true)
	equal("and forgets the override", _has_key(Actions.INVENTORY, KEY_K), false)
	equal("and removes the file", FileAccess.file_exists(KeyBindings.file_path), false)


## A boot, in miniature: the default re-declared, then the override loaded over the top of it.
## This is the half of persistence that a single process can still prove honestly.
func _a_fresh_boot_puts_it_back() -> void:
	InputMap.action_erase_events(Actions.INVENTORY)
	InputMap.action_add_event(Actions.INVENTORY, KeyBindings.event_for_key(KEY_I))
	equal("the default is back in place", _has_key(Actions.INVENTORY, KEY_K), false)
	equal("the file has at least one override in it", KeyBindings.load_all() >= 1, true)
	equal("REBINDING PERSISTS: K came back from disk", _has_key(Actions.INVENTORY, KEY_K), true)


func _rebinding_listens_one_row_at_a_time() -> void:
	var screen: RebindScreen = _stack.top() as RebindScreen
	equal("the controls screen is still on top", screen != null, true)
	screen.listen(Actions.RUN)
	equal("pressing a row starts it listening", screen.listening(), Actions.RUN)
	equal("and that row says so", screen.row_text(Actions.RUN),
		tr(RebindScreen.LISTENING_KEY).format({"action": tr(RebindScreen.action_key(Actions.RUN))}))
	equal("while another row still shows its binding", screen.row_text(Actions.SNEAK).contains("/"), true)
	screen.listen(Actions.SNEAK)
	equal("listening follows the row pressed last", screen.listening(), Actions.SNEAK)
	equal("cleanup", _stack.close_top(), true)


## Every label these two screens draw is computed from a setting path or an action name, so no
## text scan could ever find one. They are asserted mechanically instead, exactly as the prompt's
## verb keys and the inventory's category keys are.
func _every_computed_key_exists() -> void:
	for path: String in Settings.DEFAULTS:
		_key_exists(SettingsScreen.label_key(path))
		var head: String = path.get_slice("/", 0) if path.contains("/") else SettingsScreen.GENERAL
		_key_exists("%s%s" % [SettingsScreen.SECTION_PREFIX, head])
	for path: String in SettingsScreen.NAMED:
		for value: Variant in DictRead.get_array(SettingsScreen.CHOICES, path):
			_key_exists("%s.%d" % [SettingsScreen.label_key(path), DictRead.to_float(value) as int])
	for action: StringName in Actions.REBINDABLE:
		_key_exists(RebindScreen.action_key(action))
	for key: String in [
		SettingsScreen.TITLE_KEY, SettingsScreen.HINT_KEY, SettingsScreen.ROW_KEY,
		SettingsScreen.ON_KEY, SettingsScreen.OFF_KEY, SettingsScreen.UNLIMITED_KEY,
		SettingsScreen.PERCENT_KEY, SettingsScreen.MULTIPLIER_KEY, SettingsScreen.RESET_KEY,
		RebindScreen.TITLE_KEY, RebindScreen.HINT_KEY, RebindScreen.ROW_KEY,
		RebindScreen.LISTENING_KEY, RebindScreen.NONE_KEY, RebindScreen.RESET_KEY,
	]:
		_key_exists(key)


func _key_exists(key: String) -> void:
	equal("key %s is translated" % key, tr(key) != key, true)


func _top() -> SettingsScreen:
	return _stack.top() as SettingsScreen


func _row_for(screen: SettingsScreen, path: String) -> String:
	for text_value: String in screen.row_texts():
		if text_value.begins_with(tr(SettingsScreen.label_key(path))):
			return text_value
	return ""


func _focused_text(screen: MenuScreen) -> String:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and button.has_focus():
			return button.text
	return ""


func _has_key(action: StringName, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == code:
			return true
	return false


func _has_axis(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return true
	return false


func _tear_down() -> void:
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	# Everything this case moved goes back. Leaving a changed setting or a live override behind
	# would make the next run of the suite, or the next capture, a different run.
	Settings.reset_to_defaults()
	Actions.reset_bindings()
