extends TestCase
## THE HEADLINE ASSERTION IS `_every_setting_has_a_consumer()`, and it is this package's answer
## to a question the ladder's six checkers cannot ask.
##
## WHY THIS IS AN ASSERTION AND NOT A SEVENTH CHECKER. T5.4 added three gates that each ask
## "does a declared thing have a consumer?", and none of them can see a SETTING: a setting is a
## string key in a Dictionary read through `get_bool` / `get_float`, not a `class_name`, not a
## `signal`, not a CSV row. So the question had to be asked somewhere new. It is asked here
## rather than in `tools/` because of what the two places can reach. A `check_*` tool reads text
## off disk and would have to reconstruct the key list by parsing `settings.gd`; a test has
## `Settings.DEFAULTS` as the engine actually loaded it. Where the subject of a rule is available
## at RUNTIME, the assertion is the truer place, and T5.4's three went to tools for the mirror
## reason - which layer a path is in, and what a `.tscn` contains, no running game can see.
## CI runs the suite as its own step, so the coverage is identical either way.
##
## THERE ARE THREE WAYS TO BE A CONSUMER, and writing the assertion is what found the third:
##
##   1. NAME THE KEY. Every consumer wired by T5.5 does, as a `const` on itself - which is
##      `PlayerController.PACE`'s convention applied to settings, so a setting nobody reads has
##      nowhere to be written down.
##   2. NAME THE SECTION. `audio_director.gd` handles `section == "audio"` wholesale and then
##      builds each key as `"audio/%s" % bus_name.to_lower()`. The five volume keys therefore
##      appear NOWHERE as literals and no scan can ever find them - the same computed-key
##      situation as the settings screen's own row labels and the prompt's verb keys, and
##      handled the way this project already handles those: mechanically, not by text.
##   3. BE APPLIED BY `settings.gd` ITSELF. Five keys are - the window mode, vsync, the fps cap,
##      the render scale and the shadow atlas - and that file's header gives the reason: nothing
##      else owns the window, the viewport or the shadow atlas, so a "consumer" elsewhere would
##      be a listener invented to set one property on a node it does not own. For that file
##      alone ONE mention is not enough, because the declaration in DEFAULTS is a mention. Two
##      are required, so the second has to be an application.
##
## AND `settings_screen.gd` IS NEVER A CONSUMER. It names nine keys in its ranges and choices,
## and it is generated FROM `DEFAULTS` - it is the thing that made twelve dead settings visible
## to the player in the first place. Counting it would make this assertion pass on the exact
## state it exists to forbid. Whole-line comments do not count either, in any file: a scan that
## a `##` block can satisfy is a scan a stale comment can keep green.
##
## OWNS: assertions that a setting reaches something, and that the nine wired by T5.5 do.
## MUST NOT: assert how a setting is PRESENTED. `options_test.gd` owns the screen.

const DECLARATION: String = "res://src/core/state/settings.gd"
## Generated from DEFAULTS, so naming a key here proves nothing. See the header.
const GENERATED_SCREEN: String = "res://src/ui/screens/settings_screen.gd"
const SRC: String = "res://src"
## Where the running game gets its one `UiAccessibility` from. Asserted, because every other
## assertion in this file builds its own and would pass without it.
const GAME_ROOT: String = "res://scenes/boot/game_root.tscn"
const ACCESSIBILITY_SCRIPT: String = "res://src/ui/root/ui_accessibility.gd"
## The fade has no `class_name` — it is a script on one node in one scene — so the const it names
## its setting with is reached through the script itself, and `new()` builds the ColorRect.
const FADE_SCRIPT: String = "res://src/ui/hud/screen_fade.gd"
const FADE: GDScript = preload("res://src/ui/hud/screen_fade.gd")
## Where the running game gets its one autosave policy from, for `TestCase.parent_of_script`. Same
## reason as `ACCESSIBILITY_SCRIPT`: every other autosave assertion builds its own.
const AUTOSAVE_SCRIPT: String = "res://src/systems/autosave/autosave.gd"
## An area id that stands a run up without naming any content. The policy asks whether a run
## EXISTS, never which area it is in, so any id at all does the job.
const FIXTURE_AREA: StringName = &"fixture_area"


func run() -> void:
	plan(80)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	_every_setting_has_a_consumer()
	_the_autosave_policy_is_in_the_running_game_and_subscribed_to_both_occasions()
	_reset_puts_the_language_back()
	_the_setting_vetoes_depth_of_field_and_the_author_still_decides()
	_a_hold_floor_applies_to_an_object_that_asked_for_none()
	_text_scale_moves_the_theme_and_never_compounds()
	_only_a_rebindable_action_may_be_rebound()
	_there_is_no_jump_action()
	_reduce_motion_reaches_every_motion_this_template_has()
	_tear_down()


## The assertion this whole package exists to make impossible to break again.
func _every_setting_has_a_consumer() -> void:
	var sources: Dictionary[String, String] = _sources()
	equal("there are scripts under src/ to scan", sources.size() > 50, true)
	for path: String in Settings.DEFAULTS:
		equal("something consumes '%s'" % path, _is_consumed(sources, path), true)


## `reset_to_defaults` wrote `locale = "en"` and left the UI in whatever language it was, because
## it re-applied the display and not the locale. One missing line, and invisible to every other
## rung: the file on disk was correct, so nothing but the screen could tell.
func _reset_puts_the_language_back() -> void:
	var default_locale: String = Settings.DEFAULTS[Settings.LOCALE]
	# The pseudolocale `en_XA` shares its language subtag with the default, so this compares the
	# WHOLE tag. `begins_with` here would pick the default back out and assert nothing.
	var other: String = ""
	for locale: String in TranslationServer.get_loaded_locales():
		if locale != default_locale:
			other = locale
			break
	equal("a second language exists, so this is testable", other != "", true)
	Settings.set_value(Settings.LOCALE, other)
	var switched: String = TranslationServer.get_locale()
	equal("switching moved TranslationServer", switched != default_locale, true)
	Settings.reset_to_defaults()
	equal("the stored value went back to the default", Settings.get_string(Settings.LOCALE), default_locale)
	equal("AND TranslationServer went with it, which it did not before T5.5",
			TranslationServer.get_locale() != switched, true)
	equal("landing on the default", TranslationServer.get_locale(), default_locale)


## `set_dof_enabled()` had no caller at all. It has one now, and the rig still remembers what the
## area author asked for, so the setting is a veto rather than a blanket yes.
func _the_setting_vetoes_depth_of_field_and_the_author_still_decides() -> void:
	var rig := HD2DCameraRig.new()
	rig.dof_enabled = true
	attach(rig)
	equal("an authored-on rig starts on", rig.dof_enabled, true)
	Settings.set_value(HD2DCameraRig.DOF_SETTING, false)
	equal("and the setting turns it off without touching the area scene", rig.dof_enabled, false)
	Settings.set_value(HD2DCameraRig.DOF_SETTING, true)
	equal("and back on", rig.dof_enabled, true)
	rig.queue_free()

	var author_off := HD2DCameraRig.new()
	author_off.dof_enabled = false
	attach(author_off)
	equal("an authored-off rig starts off", author_off.dof_enabled, false)
	Settings.set_value(HD2DCameraRig.DOF_SETTING, false)
	Settings.set_value(HD2DCameraRig.DOF_SETTING, true)
	equal("and turning the setting on does NOT override the author", author_off.dof_enabled, false)
	author_off.queue_free()


## The player's floor under the author's per-object value, and one function so the progress the
## prompt draws cannot disagree with the threshold that fires.
func _a_hold_floor_applies_to_an_object_that_asked_for_none() -> void:
	# THE REAL PATH, DRIVEN FROM OUTSIDE, and no test-only setter added to do it: an Interactable
	# IS an Area3D, so emitting the sensor's own `area_entered` makes it a candidate, and emitting
	# the target's `availability_changed` is the one handler that re-selects without waiting for a
	# physics frame - `run()` is synchronous, so `_physics_process` never comes. Asserted through
	# `_current` rather than against a pure function on the side, because T5.3's gotcha 54 was two
	# green assertions either side of a wire that did not exist.
	var target := Interactable.new()
	target.name = "HoldTarget"
	# A fixture key, so the Interactable does not warn about a blank prompt on the way in.
	target.label_key = "fixture.hold.label"
	target.hold_seconds = 0.0
	attach(target)
	var sensor := InteractionSensor.new()
	attach(sensor)
	sensor.area_entered.emit(target)
	target.availability_changed.emit()
	Settings.set_value(InteractionSensor.HOLD_TO_CONFIRM, false)
	equal("the target is the sensor's current one", sensor.current() == target, true)
	equal("a press object needs no hold by default", is_equal_approx(sensor.hold_needed(), 0.0), true)
	equal("so the prompt draws no progress bar", is_equal_approx(sensor.hold_progress(), 0.0), true)
	Settings.set_value(InteractionSensor.HOLD_TO_CONFIRM, true)
	equal("and needs the floor when the player asked for one",
			is_equal_approx(sensor.hold_needed(), InteractionSensor.FLOOR_SECONDS), true)
	target.hold_seconds = 1.5
	equal("while an object that asked for longer keeps its own value",
			is_equal_approx(sensor.hold_needed(), 1.5), true)
	Settings.set_value(InteractionSensor.HOLD_TO_CONFIRM, false)
	equal("and keeps it with the setting off too", is_equal_approx(sensor.hold_needed(), 1.5), true)
	sensor.queue_free()
	target.queue_free()


## Scaled from the AUTHORED size every time, never from the live one: multiplying the current
## value compounds and rounds, so walking the row up and back would not return to where it was.
func _text_scale_moves_the_theme_and_never_compounds() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	equal("there is a project theme to scale", theme != null, true)
	if theme == null:
		return
	var access := UiAccessibility.new()
	attach(access)
	var types: PackedStringArray = theme.get_font_size_type_list()
	equal("and it declares font sizes by role", types.size() > 0, true)
	var role: String = types[0]
	var size_name: String = theme.get_font_size_list(role)[0]
	var authored: int = access.scaled_size(role, size_name, 1.0)
	equal("scale 1.0 is the authored size",
			theme.get_font_size(StringName(size_name), StringName(role)), authored)

	Settings.set_value(UiAccessibility.TEXT_SCALE, 2.0)
	equal("doubling doubles it",
			theme.get_font_size(StringName(size_name), StringName(role)), authored * 2)
	Settings.set_value(UiAccessibility.TEXT_SCALE, 1.5)
	Settings.set_value(UiAccessibility.TEXT_SCALE, 2.0)
	equal("and getting there the long way lands on the same number, so it does not compound",
			theme.get_font_size(StringName(size_name), StringName(role)), authored * 2)
	Settings.set_value(UiAccessibility.TEXT_SCALE, 1.0)
	equal("and 1.0 restores the shared theme for every case after this one",
			theme.get_font_size(StringName(size_name), StringName(role)), authored)
	access.queue_free()

	# AND THE WIRE, not just the two ends of it. Everything above builds its own node, so all of
	# it stays green in a checkout where nothing ever instances one - which is gotcha 54 exactly.
	# `game_root.tscn` is the only place the running game gets one from.
	#
	# READ THROUGH `SceneState`, NOT AS TEXT. The first version of this assertion searched the
	# .tscn for the script path and for `parent="UILayer"` - and it stayed GREEN when the node
	# was deleted, because the `[ext_resource]` line survives a node's removal and eight other
	# nodes carry that parent. Planted and measured. The engine's own parse cannot be fooled
	# that way: a script is a PROPERTY of a node here, and the node either exists or does not.
	equal("and the running game actually has one, under UILayer",
			parent_of_script(GAME_ROOT, ACCESSIBILITY_SCRIPT), "./UILayer")


## The gate was `InputMap.has_action`, so an action outside REBINDABLE could be overridden and
## written to input.cfg - and `reset_bindings()` re-declares only the rebindable groups, so
## nothing ever put the erased default back.
func _only_a_rebindable_action_may_be_rebound() -> void:
	var event: InputEventKey = KeyBindings.event_for_key(KEY_F12)
	equal("the console key exists as an action", InputMap.has_action(Actions.DEBUG_CONSOLE), true)
	equal("but is not rebindable", Actions.REBINDABLE.has(Actions.DEBUG_CONSOLE), false)
	equal("so rebinding it is refused", KeyBindings.rebind(Actions.DEBUG_CONSOLE, event), false)
	equal("and nothing was written for it",
			KeyBindings.text_for(Actions.DEBUG_CONSOLE, false).contains("F12"), false)
	equal("while a rebindable action still binds", KeyBindings.rebind(Actions.INTERACT, event), true)
	KeyBindings.forget_all()
	Actions.reset_bindings()


## Declared, bound to Space, listed in REBINDABLE and drawn as a rebinding row for a verb the
## template says three times over it does not have. Nothing polled it.
func _there_is_no_jump_action() -> void:
	equal("no 'jump' action is defined", InputMap.has_action(&"jump"), false)
	for action: StringName in Actions.REBINDABLE:
		equal("every rebindable action is real: %s" % action, InputMap.has_action(action), true)
	var csv: String = FileAccess.get_file_as_string("res://localization/strings.csv")
	equal("and the CSV no longer offers a row for one", csv.contains("ui.action.jump"), false)


## The three ways, in the header's order. Quoted and whole, so `video/bloom` cannot be satisfied
## by a longer key that contains it.
func _is_consumed(sources: Dictionary[String, String], key: String) -> bool:
	var needle: String = "\"%s\"" % key
	var section: String = "section == \"%s\"" % key.get_slice("/", 0)
	for path: String in sources:
		if path == GENERATED_SCREEN:
			continue
		var code: String = sources[path]
		if path == DECLARATION:
			if code.count(needle) >= 2:
				return true
			continue
		if code.contains(needle) or code.contains(section):
			return true
	return false


## Every script under src/, with its whole-line comments stripped.
func _sources() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	_walk(SRC, out)
	return out


func _walk(dir_path: String, out: Dictionary[String, String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for child: String in dir.get_directories():
		_walk("%s/%s" % [dir_path, child], out)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			var path: String = "%s/%s" % [dir_path, file_name]
			out[path] = _code_only(FileAccess.get_file_as_string(path))


## Whole-line comments only. A trailing `# 0 = uncapped` after real code is left alone, because
## removing that would mean deciding whether a `#` sits inside a string literal.
func _code_only(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


func _tear_down() -> void:
	Settings.reset_to_defaults()
	Actions.reset_bindings()


## THE THREE MOTIONS, NAMED IN ONE PLACE. T5.5 wired `accessibility/reduce_motion` to the
## typewriter and said in its own DEVLOG that one consumer makes a setting honest and not
## complete. A screen fade and a lagging camera are the other two motions this template draws,
## and a preference that spares a player one of three has told them something untrue.
##
## Each consumer names the key on ITSELF, which is what makes `_is_consumed` decidable rather
## than a heuristic - so this asserts the three consts agree with the declaration, because three
## copies of a string are three chances to typo one into a key nothing sets.
func _reduce_motion_reaches_every_motion_this_template_has() -> void:
	var key: String = DialogueScreen.REDUCE_MOTION
	equal("the setting is declared", Settings.DEFAULTS.has(key), true)
	equal("the typewriter names it", DialogueScreen.REDUCE_MOTION, key)
	equal("the fade names the same one", FADE.REDUCE_MOTION, key)
	equal("and so does the camera rig", HD2DCameraRig.REDUCE_MOTION, key)
	# AND THE WIRE, read through `SceneState` rather than as text - gotcha 56. Every fade
	# assertion below builds its own ColorRect and would stay green in a checkout where the
	# running game instances none.
	equal("and the running game has a fade, under UILayer",
			parent_of_script(GAME_ROOT, FADE_SCRIPT), "./UILayer")
	equal("the shake scale is a setting in its own right", Settings.DEFAULTS.has(HD2DCameraRig.SHAKE_SETTING), true)
	# AND THE ASK HAS A LISTENER, which is the one half `tools/check_signals.gd` deliberately
	# will not fail on: that gate requires an EMITTER and only REPORTS a signal nothing hears.
	# `Events.camera_shake_requested` is where a gate's ask meets the camera, so the connection
	# is the wire, and a rig that stopped subscribing would leave both ends of it green.
	var rig := HD2DCameraRig.new()
	attach(rig)
	equal("and a rig in the tree is listening for a shake request",
			Events.camera_shake_requested.is_connected(rig.shake), true)
	rig.queue_free()



## GOTCHA 54, AIMED AT DELIBERATELY FOR THE THIRD TIME. `settings_effects_test.gd` builds its own
## `Autosave` and drives `request()` directly, so every one of its assertions stays green in a
## checkout where the running game instances none and nothing is ever connected to either
## occasion — the policy would be perfect and would never once fire. Only these four can notice.
##
## READ THROUGH `SceneState`, NOT AS TEXT, which is gotcha 56: an `[ext_resource]` line survives
## the deletion of every node that used it, so a search of the .tscn would stay green after the
## node was removed. `TestCase.parent_of_script` asks the engine's own parse instead, where a script is a
## property of a node and the node either exists or does not.
func _the_autosave_policy_is_in_the_running_game_and_subscribed_to_both_occasions() -> void:
	equal("the setting is declared", Settings.DEFAULTS.has(Autosave.AUTOSAVE_SETTING), true)
	equal("and the running game has an Autosave under the root",
			parent_of_script(GAME_ROOT, AUTOSAVE_SCRIPT), ".")
	var policy := Autosave.new()
	attach(policy)
	equal("a policy in the tree is listening for the quit that ends a session",
			Events.game_ending.is_connected(policy._on_game_ending), true)
	equal("and for arrival in a new area",
			Events.area_entered.is_connected(policy._on_area_entered), true)
	# NOT A DIRECT CALL, and this is the assertion that pins the one-frame deferral in place.
	# `Director` emits `area_entered` two statements BEFORE it clears `_transitioning`, so a
	# synchronous handler would hit the transition refusal every time and the feature would never
	# fire once. `run()` is synchronous, so no frame ever arrives here — an arrival therefore
	# writes NOTHING inside this call, and a handler that had been "simplified" to call
	# `request()` on the spot would write a file and fail this.
	_clear_autosave()
	Settings.set_value(Autosave.AUTOSAVE_SETTING, true)
	Director.current_area_id = FIXTURE_AREA
	Events.area_entered.emit(FIXTURE_AREA)
	equal("and an arrival does not write inside the emit, because the transition is not over yet",
			SaveSystem.has_slot(SaveSystem.AUTOSAVE_SLOT), false)
	Director.current_area_id = &""
	_clear_autosave()
	policy.queue_free()


func _clear_autosave() -> void:
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE_SLOT)
