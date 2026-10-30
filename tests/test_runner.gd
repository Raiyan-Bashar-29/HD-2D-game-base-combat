extends Node
## Rung 4 of the verification ladder: headless integration tests with the real autoloads live.
## This file is a dispatcher. The assertions live in tests/unit/, one file per area.
##
## RUN:
##     godot_console --headless res://tests/test_runner.tscn --quit-after 400
##
## Exit code 0 if every assertion passes, 1 otherwise, so this gates a commit or CI.
##
## WHY THIS IS A SCENE AND NOT A --script TOOL
## Under `--headless --script foo.gd` the autoload *nodes* are created, but the autoload
## *identifiers* (Log, Flags, SaveSystem) fail to compile - proven, the error is
## `Compile Error: Identifier not found: Log`. So no test that touches a system can be a
## --script tool. It has to be a scene, entered positionally.
##
## WHY THE SUITE IS SPLIT
## This file reached 184 of its 250 code lines with its largest case at 35 of the 40 allowed
## per function. Rather than raise the budget - the move that turns a file into 3,983 lines
## twenty reasonable lines at a time - the cases moved into tests/unit/ behind a TestCase base.
##
## THE FOUR WAYS A SUITE PASSES WITHOUT TESTING ANYTHING, and what stops each (T1.3):
## 1. A case CRASHES. A GDScript runtime error aborts only the innermost frame, so the runner
##    sees a case that returned normally. Caught TWICE, because one is not enough: the declared
##    plan catches every crash that swallows an assertion, and `ErrorWatch` - an `OS.add_logger`
##    Logger counting ERROR_TYPE_SCRIPT - catches the rest, including a crash in a leaf helper
##    with nothing asserted after it, which the plan provably does not see.
## 2. A case RETURNS EARLY, or a block is commented out. Same plan, same shortfall.
## 3. A case asserts NOTHING. A plan of zero, or no plan at all, is a failure here.
## 4. A FILE IS NEVER RUN because nobody added it to CASES. `_manifest_is_complete()` scans the
##    directory and fails on a file that exists and is not listed. Gotcha 22 is this failure
##    one layer down: a file that does not parse is invisible to a green run.
##
## AND ONE WAY A SUITE PASSES WHILE DOING HARM (T6.12): a case saves without
## `SaveFixture.activate()`. Before every case the store is parked in a scratch directory, so the
## write cannot reach a real save, and `_saves_were_claimed()` fails the case that made it. Why it
## takes both halves is in `tests/framework/save_fixture.gd`'s header.
##
## OWNS: discovering cases, tallying them, enforcing the plans and the exit code.
## MUST NOT: contain assertions of its own, or any game logic.

const CASE_DIR: String = "res://tests/unit"
## The language the suite runs in, read from the project rather than assumed.
const FALLBACK_LOCALE: String = "internationalization/locale/fallback"

const CASES: Array[String] = [
	"res://tests/unit/core_test.gd",
	"res://tests/unit/save_recovery_test.gd",
	"res://tests/unit/save_dir_test.gd",
	"res://tests/unit/run_scratch_test.gd",
	"res://tests/unit/world_test.gd",
	"res://tests/unit/interaction_test.gd",
	"res://tests/unit/items_test.gd",
	"res://tests/unit/pickups_test.gd",
	"res://tests/unit/traversal_test.gd",
	"res://tests/unit/ui_test.gd",
	"res://tests/unit/screens_test.gd",
	"res://tests/unit/row_styles_test.gd",
	"res://tests/unit/transitions_test.gd",
	"res://tests/unit/dialogue_test.gd",
	"res://tests/unit/dialogue_speed_test.gd",
	"res://tests/unit/npc_test.gd",
	"res://tests/unit/npc_reach_test.gd",
	"res://tests/unit/path_actions_test.gd",
	"res://tests/unit/presentation_test.gd",
	"res://tests/unit/menus_test.gd",
	"res://tests/unit/options_test.gd",
	"res://tests/unit/export_test.gd",
	"res://tests/unit/art_contract_test.gd",
	"res://tests/unit/character_swap_test.gd",
	"res://tests/unit/sheet_facings_test.gd",
	"res://tests/unit/quests_test.gd",
	"res://tests/unit/quest_chain_test.gd",
	"res://tests/unit/equipment_test.gd",
	"res://tests/unit/world_map_test.gd",
	"res://tests/unit/character_depth_test.gd",
	"res://tests/unit/content_scan_test.gd",
	"res://tests/unit/item_count_test.gd",
	"res://tests/unit/area_look_test.gd",
	"res://tests/unit/smoke_test.gd",
	"res://tests/unit/dev_tools_test.gd",
	"res://tests/unit/version_test.gd",
	"res://tests/unit/docs_test.gd",
	"res://tests/unit/bag_mirror_test.gd",
	"res://tests/unit/facing_test.gd",
	"res://tests/unit/turn_test.gd",
	"res://tests/unit/gaits_test.gd",
	"res://tests/unit/idle_break_test.gd",
	"res://tests/unit/doc_counts_test.gd",
	"res://tests/unit/record_shape_test.gd",
	"res://tests/unit/combat_record_test.gd",
	"res://tests/unit/stat_sheet_test.gd",
	"res://tests/unit/vitals_test.gd",
	"res://tests/unit/damage_formula_test.gd",
	"res://tests/unit/status_set_test.gd",
	"res://tests/unit/combatant_test.gd",
	"res://tests/unit/strike_target_test.gd",
	"res://tests/unit/turn_scheduler_test.gd",
	"res://tests/unit/ctb_scheduler_test.gd",
	"res://tests/unit/skill_test.gd",
	"res://tests/unit/battle_test.gd",
	"res://tests/unit/battle_ai_test.gd",
	"res://tests/unit/encounter_test.gd",
	"res://tests/unit/battle_screen_test.gd",
	"res://tests/unit/combat_content_test.gd",
	"res://tests/unit/skill_use_test.gd",
	"res://tests/unit/status_behaviour_test.gd",
	"res://tests/unit/hit_reaction_test.gd",
	"res://tests/unit/meters_test.gd",
	"res://tests/unit/weakness_test.gd",
	"res://tests/unit/battle_menu_test.gd",
	"res://tests/unit/battle_readout_test.gd",
	"res://tests/unit/combat_input_test.gd",
	"res://tests/unit/move_timeline_test.gd",
	"res://tests/unit/hitbox_test.gd",
	"res://tests/unit/party_rewards_test.gd",
	"res://tests/unit/gates_test.gd",
	"res://tests/unit/settings_consumers_test.gd",
	"res://tests/unit/settings_effects_test.gd",
	"res://tests/unit/audio_duck_test.gd",
	"res://tests/unit/selection_test.gd",
	"res://tests/unit/time_flags_test.gd",
	"res://tests/unit/input_device_test.gd",
	"res://tests/unit/confirm_test.gd",
	"res://tests/unit/slot_header_test.gd",
	"res://tests/unit/focus_loss_test.gd",
	"res://tests/unit/font_chain_test.gd",
	"res://tests/unit/forgotten_list_test.gd",
	"res://tests/unit/plural_count_test.gd",
]

var _passed: int = 0
## Engine script errors already blamed on a named case, so the backstop can tell which ones
## nothing accounted for.
var _attributed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _failures: Array[String] = []
var _skips: Array[String] = []
var _watch: ErrorWatch = null
## Saves and loads the running case made in a directory it never claimed. Cleared before each case.
var _unclaimed_uses: Array[String] = []


## The exit code is ARMED TO FAILURE on the first line and only cleared at the end. quit() sets
## the code and quits at the end of the frame, and a later call overwrites it - both probed. So
## if a crash ever aborts this function itself, the run still exits 1 instead of reporting a
## clean sweep it never finished.
func _ready() -> void:
	get_tree().quit(1)
	_watch = ErrorWatch.new()
	OS.add_logger(_watch)
	Events.game_saved.connect(_on_store_used.bind("saved"))
	Events.game_loaded.connect(_on_store_used.bind("loaded"))
	Log.info("test", "=== test run starting ===")
	# Determinism: a clock that advances mid-assertion makes time assertions flaky.
	Clock.paused = true
	# EVERYTHING THIS RUN WRITES IS UNDER ITS OWN DIRECTORY, T6.13, named for this process, so two
	# suites in two worktrees - which share one user:// - cannot empty each other's. First, before
	# any path below is read. `tests/framework/run_scratch.gd` has the measurement.
	RunScratch.begin()
	# NOR THE KEY BINDINGS, T6.13: `options_test` rebinds and then resets, which DELETED the file.
	KeyBindings.file_path = RunScratch.path("input.cfg")
	# NO CASE WRITES THE DEVELOPER'S SETTINGS FILE, T6.11. Before the first case, not per case:
	# SaveFixture.gd says why. The real file was already READ, so the pin below is still needed.
	Settings.file_path = SaveFixture.settings_path()
	# AND SO IS THE LANGUAGE, for the same reason one step further out. Several cases compare
	# `tr()` output, so a developer who left the pseudolocale selected - or any consuming
	# game whose default is not English - would fail assertions that have nothing to do with
	# their change. T5.1 hit exactly that: a `--locale=en_XA` capture PERSISTED the setting, and
	# the next suite run failed in four unrelated cases. A capture writes scratch since T6.11,
	# but a PLAYER'S language choice still persists, as it should, and the suite reads that file.
	# The fallback is read rather than hard-coded, so this pins the project's own language.
	var declared: Dictionary = {"locale": ProjectSettings.get_setting(FALLBACK_LOCALE, "en")}
	TranslationServer.set_locale(DictRead.get_string(declared, "locale", "en"))
	if not Fixtures.has_demo_content():
		Log.info("test", "no demo content in this checkout — demo-only cases will skip")

	_manifest_is_complete()
	for path: String in CASES:
		_run_case(path)

	_no_unattributed_errors()
	_report()
	RunScratch.finish()
	get_tree().quit(1 if _failed > 0 else 0)


func _report() -> void:
	Log.info("test", "=== %d passed, %d failed, %d skipped ===" % [
		_passed, _failed, _skipped,
	])
	for entry: String in _skips:
		Log.info("test", "SKIPPED: %s" % entry)
	if _skipped > 0:
		Log.info("test", "%d assertion(s) were skipped: this run covers less than a full one"
			% _skipped)
	for failure: String in _failures:
		Log.error("test", "FAILED: %s" % failure)


## A suite file that nobody listed is never run, and every rung stays green. This is gotcha 22's
## shape one layer up: not a file that fails to parse, but a file that is never asked to.
func _manifest_is_complete() -> void:
	for file_name: String in DirAccess.get_files_at(CASE_DIR):
		if not file_name.ends_with(".gd"):
			continue
		var path: String = "%s/%s" % [CASE_DIR, file_name]
		if not CASES.has(path):
			_record_failure("%s exists but is not listed in CASES, so it never runs" % path)


func _run_case(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		_record_failure("%s could not be loaded" % path)
		return
	# A SCRIPT THAT DOES NOT PARSE IS NOT NULL. `load()` hands back a GDScript that exists and
	# cannot be instantiated, so this function used to walk straight into `script.new()` - whose
	# failure is a runtime error, and gotcha 24 says that aborts only THIS frame. The
	# `does not extend TestCase` failure below was therefore never reached, the loop in `_ready`
	# moved on, and a LISTED case that did not compile reported `0 failed` and exit 0 - the same
	# false green `_manifest_is_complete` exists to close, through the one door it does not watch.
	# Found by performing `docs/TESTING.md`, whose rule 5 already named this failure shape.
	if not script.can_instantiate():
		_record_failure("%s is listed but does not parse, so it never ran" % path)
		return
	# Object, then a cast: casting a Variant directly would trip the unsafe_cast warning.
	var instance: Object = script.new()
	var test_case: TestCase = instance as TestCase
	if test_case == null:
		_record_failure("%s does not extend TestCase" % path)
		return

	test_case.name = path.get_file().get_basename()
	# Before every case: a run that goes quiet for `STALE_SECONDS` is one another run may prune.
	RunScratch.beat()
	SaveFixture.park()
	_unclaimed_uses.clear()
	add_child(test_case)
	Log.debug("test", "--- %s ---" % test_case.name)
	var before: int = _watch.script_errors
	test_case.run()
	_no_script_errors(test_case.name, before)
	_saves_were_claimed(test_case.name)
	_tally(test_case)
	# Free explicitly: anything left alive at exit fills the log with leaked-RID errors, and
	# that noise is how a real error gets lost.
	test_case.free()
	# Unconditionally, even for a case that never switched: a case that crashed part way
	# through its fixtures would otherwise hand the next one a redirected content root.
	Fixtures.deactivate()
	# Same discipline for the save store, which was the sixth content root and the only one
	# nothing repointed until T5.22.
	SaveFixture.deactivate()


## THE SAVE CHECK. It listens for `game_saved` and `game_loaded` instead of diffing a directory:
## T6.9 found that a diff cannot see a write followed by a delete in an empty directory, and empty
## is the normal state on CI. Both signals already exist for a game's own listeners, so no seam
## was added to `src/`. A LOAD counts because a case that plants a file by hand and deletes it
## never saves, and on the old default its load read whatever the developer had in that slot.
## Only a load with a FILE behind it counts: `item_count_test` emits `game_loaded` by hand to stand
## in for one, and that touches no disk. A file planted and left behind is announced by neither
## signal, so leftovers are counted too.
func _on_store_used(slot: int, verb: String) -> void:
	if not SaveFixture.is_unclaimed(SaveSystem.save_dir) or not SaveSystem.has_slot(slot):
		return
	var use: String = "%s slot %d in %s" % [verb, slot, SaveSystem.save_dir]
	if not _unclaimed_uses.has(use):
		_unclaimed_uses.append(use)


func _saves_were_claimed(case_name: String) -> void:
	for file_name: String in SaveFixture.unclaimed_files():
		_unclaimed_uses.append("%s left in %s" % [file_name, SaveFixture.unclaimed()])
	if _unclaimed_uses.is_empty():
		return
	_record_failure("%s used the save store without SaveFixture.activate(): %s" % [
		case_name, ", ".join(_unclaimed_uses),
	])


func _tally(test_case: TestCase) -> void:
	_passed += test_case.passed
	_failed += test_case.failed
	_skipped += test_case.skipped
	_failures.append_array(test_case.failures)
	for entry: String in test_case.skips:
		_skips.append("%s: %s" % [test_case.name, entry])
	Log.debug("test", "--- %s: %d/%d ---" % [
		test_case.name, test_case.outcomes(), test_case.planned,
	])
	_plan_holds(test_case)


## THE CRASH CHECK. A GDScript runtime error aborts only the innermost frame, so a crash in a
## leaf helper with no assertion after it meets its plan exactly and reports a clean pass —
## measured, with the plan already in place, before this was added. `ErrorWatch` is the only
## thing that sees it, and the count is read PER CASE so the failure names the case that crashed.
func _no_script_errors(case_name: String, before: int) -> void:
	var raised: int = _watch.script_errors - before
	if raised == 0:
		return
	_attributed += raised
	_record_failure("%s raised %d engine script error(s): %s" % [
		case_name, raised, str(_watch.descriptions),
	])


## THE BACKSTOP FOR AN ERROR RAISED OUTSIDE A CASE. `_no_script_errors` is read per case from
## inside `_run_case`, AFTER `run()` returns - so an engine script error raised on the way in,
## while loading or instantiating, is counted by the watch and read by nobody. That is precisely
## how the parse-error hole stayed open for the life of the suite: the watch saw the error and
## nothing ever asked it. Guarding `can_instantiate()` closes the case that was found; this
## closes the CLASS, because the next one will not be a parse error.
func _no_unattributed_errors() -> void:
	var unattributed: int = _watch.script_errors - _attributed
	if unattributed <= 0:
		return
	_record_failure("%d engine script error(s) were raised outside any case: %s" % [
		unattributed, str(_watch.descriptions),
	])


## Checks the plan. It catches every crash that swallows an assertion, an early return, a block
## commented out and a case that asserts nothing. See TestCase.plan().
func _plan_holds(test_case: TestCase) -> void:
	if test_case.planned < 0:
		_record_failure("%s declared no plan, so a crash in it would be invisible"
			% test_case.name)
		return
	if test_case.planned == 0:
		_record_failure("%s planned zero outcomes, which is not a test" % test_case.name)
		return
	if test_case.outcomes() == test_case.planned:
		return
	_record_failure("%s planned %d outcomes and produced %d — a crash, an early return or a stale plan" % [
		test_case.name, test_case.planned, test_case.outcomes(),
	])


func _record_failure(message: String) -> void:
	_failed += 1
	_failures.append(message)
	Log.error("test", message)
