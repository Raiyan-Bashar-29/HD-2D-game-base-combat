extends TestCase
## The two developer tools: the four commands behind the console, the console screen over them,
## and the performance overlay beside the HUD.
##
## WHAT THIS CASE CAN AND CANNOT SEE. `TestCase.run()` is synchronous (TESTING.md rule 2), so
## nothing here presses F1, types into the LineEdit or watches a frame time move — those are the
## windowed probe and the capture quoted in DEVLOG.md for WP-14b. What IS assertable is
## everything below the key: that a typed line reaches the right verb, that a malformed argument
## is refused rather than half-applied, that the transcript is bounded, and that the release gate
## is present in every one of the three places it has to be.
##
## THE RELEASE GATE IS ASSERTED BY READING THE SOURCE, and that is deliberate rather than lazy.
## `OS.is_debug_build()` is true in every context the suite can ever run in, so no assertion can
## exercise the false branch — the honest proof is the exported release build, whose log is
## quoted in DEVLOG.md. What a text scan CAN do is fail the day somebody deletes a guard in a
## refactor, which is the failure this project actually keeps having (gotcha 22's family). Same
## mechanism `tools/check_boundary.gd` uses for the debug directory's own precondition, and
## proved red by deleting a real guard — see DEVLOG.md.
##
## NO FIXTURE CONTENT IS ACTIVATED. Every command below is driven with an ABSTRACT name, because
## a console command takes its argument from whoever typed it: `flag fixture/thing:true` proves
## the same thing a demo id would, and `check_boundary.gd` scans this directory.
##
## OWNS: the command vocabulary, the console's transcript, the overlay's readout and the gate.
## MUST NOT: name demo content, assert a frame time's VALUE (it is a machine's number, not a
## contract), or reach into a private field to arrange state a public call could.

const STAGE_PATH: String = "res://src/systems/debug/dev_stage.gd"
const SCREENS_PATH: String = "res://src/systems/debug/dev_screens.gd"
const FLAG_A: StringName = &"fixture/console/set"
const FLAG_B: StringName = &"fixture/console/count"
## THE THREE PLACES A DEV TOOL CAN BE REACHED, and the EXACT code each must carry.
##
## Not "the file mentions OS.is_debug_build somewhere", which is the assertion gotcha 42 exists
## to warn about: `screen_keys.gd` explains its gate in a comment and holds three guards, so a
## whole-file scan for the bare call would stay green with the binding's own guard deleted. Each
## row below names one site by a fragment that appears nowhere else in its file, and the scan
## skips comment lines the way `check_boundary.gd` and `check_strings.gd` do.
const GATE_SITES: Array[Array] = [
	## The F1 binding, in ScreenKeys.toggle_console.
	["res://src/ui/root/screen_keys.gd", "if not OS.is_debug_build():"],
	## `--open-menu=console` / ScreenKeys.menu_for, which is the other way in.
	["res://src/ui/root/screen_keys.gd",
		"DebugConsoleScreen.SCREEN_ID and OS.is_debug_build()"],
	## The overlay, which arms itself rather than being opened by anything.
	["res://src/ui/hud/perf_overlay.gd", "if not OS.is_debug_build():"],
]


func run() -> void:
	plan(63)
	_the_verbs_are_the_command_lines_own()
	_a_malformed_argument_is_refused_whole()
	_the_console_runs_a_line_and_keeps_a_transcript()
	_the_overlay_reads_the_engines_own_counters()
	_every_dev_tool_is_gated_on_a_debug_build()
	_staging_that_draws_waits_for_a_settled_area()
	_every_debug_flag_has_a_node_to_parse_it()
	_no_flag_is_dispatched_by_two_nodes()
	_a_debug_launch_never_saves_over_the_real_store()
	_a_debug_launch_never_writes_the_real_settings()


## The vocabulary, and that a typed line reaches the verb it names. `run()` takes the SAME
## argument the matching `--verb=` takes, which is the whole reason there is one parser.
func _the_verbs_are_the_command_lines_own() -> void:
	# A COUNT, and deliberately a number somebody has to edit: a verb added without a thought
	# about testing it should fail here exactly once. T5.1 added `save` and `load`, and this
	# is where that showed up - which is the assertion doing its job, not being in the way.
	equal("the vocabulary is six verbs", DevCommands.VERBS.size(), 6)
	# THE PART THAT CANNOT ROT. A count says how many there are; this says every one of them
	# is wired, which is what a seventh verb declared in VERBS and forgotten in `run` breaks.
	equal("every verb in the vocabulary dispatches", _every_verb_dispatches(), true)
	equal("the usage line names every verb", _usage_names_all(), true)
	equal("an empty line asks for nothing", DevCommands.run(""), "")
	equal("an unknown verb is reported, not run",
		DevCommands.run("teleport somewhere").begins_with("no such command"), true)

	Flags.erase_flag(FLAG_A)
	var said: String = DevCommands.run("flag %s:true" % FLAG_A)
	equal("`flag` writes the flag it names", Flags.get_bool(FLAG_A), true)
	equal("and reports what it wrote", said.contains("true"), true)
	equal("a value that is not true or false is read as an integer",
		_flag_int("flag %s:7" % FLAG_B), 7)

	var day: int = Clock.day
	var hour: int = Clock.hour
	var minute: int = Clock.minute
	DevCommands.run("time 18:40")
	equal("`time` moves the clock", Vector2i(Clock.hour, Clock.minute), Vector2i(18, 40))
	Clock.set_time(day, hour, minute)

	equal("`give` refuses with no player in the tree, rather than crashing",
		DevCommands.run("give fixture/thing").contains("no inventory"), true)


## A BAD ARGUMENT MUST CHANGE NOTHING. Half-applying one is the failure mode that costs an hour:
## the report says it failed and the state says it partly did not.
func _a_malformed_argument_is_refused_whole() -> void:
	Flags.erase_flag(FLAG_A)
	equal("`flag` with no colon is refused",
		DevCommands.run("flag %s" % FLAG_A).begins_with("flag expects"), true)
	equal("and wrote nothing", Flags.has_flag(FLAG_A), false)

	var before: Vector2i = Vector2i(Clock.hour, Clock.minute)
	equal("`time` with no colon is refused",
		DevCommands.run("time later").begins_with("time expects"), true)
	equal("and the clock did not move", Vector2i(Clock.hour, Clock.minute), before)

	equal("`goto` with no area is refused",
		DevCommands.run("goto"), "goto needs an area id")


## The screen, driven through `submit()` — which is exactly what `text_submitted` calls, so this
## is the enter key's own path minus the key nothing here can press.
func _the_console_runs_a_line_and_keeps_a_transcript() -> void:
	var screen := DebugConsoleScreen.new()
	attach(screen)
	Flags.erase_flag(FLAG_A)
	var answer: String = screen.submit("flag %s:true" % FLAG_A)
	equal("a submitted line runs the command", Flags.get_bool(FLAG_A), true)
	equal("and its answer comes back", answer.contains(String(FLAG_A)), true)
	equal("the transcript holds the echo and the answer", screen.transcript().size(), 2)
	equal("an empty line is not transcribed", screen.submit("   "), "")
	equal("so the transcript did not grow", screen.transcript().size(), 2)
	for index: int in 20:
		screen.submit("flag %s:%d" % [FLAG_B, index])
	equal("the transcript is bounded", screen.transcript().size(),
		DebugConsoleScreen.KEPT_LINES)
	equal("the console stops the world", screen.pauses_world, true)
	screen.queue_free()


## The overlay reports the engine's counters and never enters the stack. The NUMBERS are a
## machine's, so what is asserted is that the readout is built and that it names every counter —
## a threshold would be an assertion about this laptop.
func _the_overlay_reads_the_engines_own_counters() -> void:
	var overlay := PerfOverlay.new()
	attach(overlay)
	# Through a `Node` local, because `overlay is UiScreen` on a `PerfOverlay` is a PARSE ERROR
	# rather than a false assertion — "Expression is of type PerfOverlay so it can't be of type
	# UiScreen". The compiler proving the claim is a better outcome than the assertion, and this
	# runtime form is what keeps the claim visible in the case that owns it.
	var as_node: Node = overlay
	equal("the overlay never enters the screen stack", as_node is UiScreen, false)
	equal("it starts hidden", overlay.visible, false)
	equal("the toggle shows it", overlay.toggle(), true)
	var line: String = overlay.last_line()
	equal("and it drew a readout at once", line.contains("ms/frame"), true)
	equal("naming draw calls and nodes",
		line.contains("draw calls") and line.contains("nodes"), true)
	equal("the toggle hides it again", overlay.toggle(), false)
	overlay.queue_free()


## THE GATE, in all three places it has to be. See the header for why this reads source text.
func _every_dev_tool_is_gated_on_a_debug_build() -> void:
	for site: Array in GATE_SITES:
		var path: String = site[0]
		var fragment: String = site[1]
		equal("%s gates on `%s`" % [path.get_file(), fragment],
			_code_contains(path, fragment), true)


## True when the fragment appears on a CODE line — a line whose first non-whitespace character
## is not `#`. The same definition the two text checkers use, and the reason is theirs: a
## comment quoting the guard is documentation, and a scan that counted it would pass over a
## deleted guard while reading its own explanation back to itself.
func _code_contains(path: String, fragment: String) -> bool:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		if line.contains(fragment):
			return true
	return false


func _usage_names_all() -> bool:
	var usage: String = DevCommands.usage()
	for verb: StringName in DevCommands.VERBS:
		if not usage.contains(String(verb)):
			return false
	return true


func _flag_int(line: String) -> int:
	DevCommands.run(line)
	return Flags.get_int(FLAG_B)


## EVERY STAGING FLAG THAT PUTS SOMETHING ON SCREEN WAITS FOR A SETTLED AREA, NOT MERELY FOR
## "an area". Gotcha 35, and `dev_stage.gd`'s own header states the rule — but `--stand-by` did
## not follow it until T4.2, and no assertion could have shown that, because `_wait_for_area`
## returns on the same frame `--goto` asks to travel and the run stays green either way. What it
## cost: `--goto=<new area> --stand-by=<object in it>` resolved the NAME IN THE DEPARTURE AREA,
## so no object in an authored area could be photographed at all.
##
## THE SCAN IS FUNCTION-SCOPED AND HAS TO BE. `_settle_stable(SETTLE_FRAMES)` appears three
## times in that file, so a whole-file scan is satisfied by any one of them and would have stayed
## green with the `--stand-by` call deleted — gotcha 43's rule, that a scan-for-a-guard must
## anchor on a fragment appearing exactly once, met here by narrowing the TEXT rather than the
## fragment.
## EACH ROW CARRIES ITS OWN PATH, and it has to since T5.20 split the staging surface: two of
## these three functions moved to `dev_screens.gd` when `dev_stage.gd` ran out of budget. Same
## shape as GATE_SITES above, and for the same reason — the row names the file it is about.
##
## THE PRESENCE ASSERTION IS WHAT MADE THAT SPLIT SAFE, and it was proved rather than assumed:
## pointing `_console`'s row back at `dev_stage.gd` fails TWO assertions, "is present" first and
## the settle guard second, because `_function_body` returns "" for a function that is not in
## the file. So a split that moved a function and forgot this list could not have passed
## quietly — which is the opposite of gotcha 2's family and the reason the first assertion is
## not redundant with the second. The honest repair is to follow the function to its new file,
## never to delete the row.
const SETTLE_SITES: Array[Array] = [
	[STAGE_PATH, "func _stand_by(node_name: String) -> void:"],
	[SCREENS_PATH, "func _console(script: String) -> void:"],
	[SCREENS_PATH, "func _open_menu(list: String) -> void:"],
]


func _staging_that_draws_waits_for_a_settled_area() -> void:
	for site: Array in SETTLE_SITES:
		var path: String = site[0]
		var signature: String = site[1]
		var body: String = _function_body(path, signature)
		equal("%s is present in %s" % [signature.get_slice("(", 0), path.get_file()],
			body.is_empty(), false)
		equal("%s settles rather than only waiting for an area"
			% signature.get_slice("(", 0),
			body.contains("_settle_stable(SETTLE_FRAMES)"), true)


## The CODE lines of one function: from its signature to the next line that starts in column
## zero. Comments are dropped for `_code_contains`'s reason — a body that merely DESCRIBES the
## call it should make must not satisfy a scan for that call.
func _function_body(path: String, signature: String) -> String:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var body: String = ""
	var inside: bool = false
	for line: String in lines:
		if line == signature:
			inside = true
			continue
		if not inside:
			continue
		if not line.is_empty() and not line.begins_with("\t"):
			break
		if line.strip_edges().begins_with("#"):
			continue
		body += line + "\n"
	return body


## Every declared verb reaches a body. Called with no argument on purpose: each verb answers with
## its own usage line and changes nothing, so this asks "is it wired" without posing any state.
func _every_verb_dispatches() -> bool:
	for verb: StringName in DevCommands.VERBS:
		if DevCommands.run(String(verb)).begins_with("no such command"):
			return false
	return true


## EVERY DEBUG SCRIPT THAT READS THE COMMAND LINE HAS A NODE IN `game_root.tscn`, and without
## one it is not a broken tool, it is an ABSENT one: no node, no `_ready`, no argument parsing,
## and every flag it documents silently ignored. Nothing anywhere is red - the file parses, the
## budget checker counts it, `check_boundary.gd` finds its release gate, and the run that used
## the flag simply prints the log of a game that was never asked to do anything.
##
## THAT IS THE SHAPE THIS PROJECT KEEPS HITTING (gotcha 2's family, and T5.7's unwired `@export`
## exactly), and T5.12 was the row that could have suffered it: the fifth debug file was written,
## typed and green a full minute before its node existed. The scan is over the DIRECTORY rather
## than a list, so a sixth file is covered on the day it is written and not on the day somebody
## remembers to add a row here.
const DEBUG_DIR: String = "res://src/systems/debug/"
const GAME_ROOT: String = "res://scenes/boot/game_root.tscn"


func _every_debug_flag_has_a_node_to_parse_it() -> void:
	var wired: int = 0
	for path: String in _debug_scripts():
		if not FileAccess.get_file_as_string(path).contains("OS.get_cmdline_user_args()"):
			continue
		wired += 1
		equal("%s has a node in game_root.tscn" % path.get_file(),
			parent_of_script(GAME_ROOT, path), ".")
	equal("every debug script that reads the command line was checked", wired, 7)


## NO TWO DEBUG FILES DISPATCH THE SAME FLAG, AND T5.20 IS WHY THIS EXISTS. That package split
## the staging surface, moving five flags out of `dev_stage.gd` into `dev_screens.gd` — and the
## failure mode of an edit like that is not a crash, it is leaving the branch behind in BOTH
## parsers. One `--open-menu=map` then dispatches twice and pushes the screen twice. Nothing
## anywhere goes red: both files parse, both budgets are fine, both nodes exist, and the capture
## comes back looking very nearly right. Gotcha 2's family again, in the shape a split makes.
##
## THE ONE SHARED FLAG IS `--new-game`, and it is shared for a stated reason rather than by
## accident: `dev_stage.gd` ACTS on it by starting the game, while `dev_screens.gd` only READS it
## to learn whether it must wait for an arriving area first. So the assertion is not "no flag is
## shared" — which would be false — but "the shared set is EXACTLY this", which is the form that
## makes a new sharer announce itself instead of slipping in under a blanket exemption.
const SHARED_FLAGS: Array[String] = ["--new-game"]


func _no_flag_is_dispatched_by_two_nodes() -> void:
	var owners: Dictionary[String, int] = {}
	for path: String in _debug_scripts():
		for flag: String in _parsed_flags(path):
			owners[flag] = owners.get(flag, 0) + 1
	var shared: Array[String] = []
	for flag: String in owners:
		if owners[flag] > 1:
			shared.append(flag)
	shared.sort()
	equal("the only flag two debug nodes both read is the one that is meant to be",
		shared, SHARED_FLAGS)
	# Guards the scan itself: an extractor that silently matched nothing would satisfy the
	# assertion above with an empty dictionary, which is gotcha 43's rule applied to a counter.
	equal("and the extractor actually found the flag surface", owners.size() > 20, true)


## The flag literals one debug file's `_parse_arguments` names. Reads the FUNCTION rather than the
## file, because every one of these files also documents its flags in a `##` header — and a scan
## that counted those would report every flag as shared between its parser and its own prose.
func _parsed_flags(path: String) -> Array[String]:
	var found: Array[String] = []
	var body: String = _function_body(path, "func _parse_arguments() -> void:")
	for piece: String in body.split("\""):
		if piece.begins_with("--") and not found.has(piece):
			found.append(piece)
	return found


## The directory as it is on disk, not a list to keep in step with it.
func _debug_scripts() -> Array[String]:
	var found: Array[String] = []
	var directory: DirAccess = DirAccess.open(DEBUG_DIR)
	if directory == null:
		return found
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			found.append(DEBUG_DIR + file_name)
	found.sort()
	return found


## A DEBUG LAUNCH SAVES TO SCRATCH, T6.10. The rule is asserted and not the redirect, because the
## suite's own process has no user arguments: the redirect is proved by the sentinel run quoted
## in DEVLOG.md, where a capture left a planted `autosave.json` byte-identical.
func _a_debug_launch_never_saves_over_the_real_store() -> void:
	var none: PackedStringArray = PackedStringArray()
	equal("a plain launch keeps the real store", DevSaves.save_dir_for(none), "")
	equal("the ladder's capture saves to scratch",
		DevSaves.save_dir_for(PackedStringArray(["--new-game", "--shot=a.png"])),
		DevSaves.SCRATCH_DIR)
	# A probe that shoots nothing still deletes the slot it used, so `--shot` is not the trigger.
	equal("so does a probe with no shutter",
		DevSaves.save_dir_for(PackedStringArray(["--save-state=2"])), DevSaves.SCRATCH_DIR)
	equal("and the opt-out keeps the real store",
		DevSaves.save_dir_for(PackedStringArray(["--new-game", DevSaves.REAL_SAVES_FLAG])), "")
	equal("scratch is not the real store",
		DevSaves.SCRATCH_DIR != SaveSystem.DEFAULT_SAVE_DIR, true)
	# `SaveFixture.activate()` empties its directory; shared, a suite in another session would
	# delete the file a two-process probe pair left for its second half. Outside EVERY run's
	# directory, T6.13, not only this one's: `RunScratch.begin()` prunes the dead runs' ones.
	equal("nor any suite run's",
		DevSaves.SCRATCH_DIR.begins_with(RunScratch.PARENT), false)
	var scene: String = FileAccess.get_file_as_string(GAME_ROOT)
	var at: int = scene.find("[node name=\"DevSaves\"")
	equal("the redirect is the first debug node", at >= 0 and at == scene.find("[node name=\"Dev"),
		true)


## AND SETTINGS, T6.11. Here the REDIRECT itself is asserted, not only the rule: `apply` is static,
## so the suite hands it the ladder's arguments and reads both paths back, then writes one setting
## to prove `save()` goes where the path says. Both are put back, because the runner's own
## redirect must hold for every case after this one.
func _a_debug_launch_never_writes_the_real_settings() -> void:
	equal("the suite itself writes its settings to scratch", Settings.file_path,
		SaveFixture.settings_path())
	var store: String = SaveSystem.save_dir
	var settings: String = Settings.file_path
	equal("a plain launch redirects nothing", DevSaves.apply(PackedStringArray()), false)
	equal("and leaves the settings file where it was", Settings.file_path, settings)

	DevSaves.apply(PackedStringArray(["--new-game", "--locale=en_XA"]))
	equal("a capture's settings go to scratch", Settings.file_path, DevSaves.SCRATCH_SETTINGS)
	equal("and its saves go with them", SaveSystem.save_dir, DevSaves.SCRATCH_DIR)
	# THE WRITE IS PROVED ON THIS RUN'S OWN PATH, T6.13, not on `SCRATCH_SETTINGS`: that file is
	# shared by every suite and debug launch on the machine, so deleting it and asking whether the
	# write brought it back failed whenever a second suite deleted it in between. The question was
	# only ever whether `save()` writes where `file_path` says, and any path answers it.
	var probe: String = RunScratch.path("dev_settings_probe.cfg")
	Settings.file_path = probe
	Settings.set_value(Settings.LOCALE, Settings.get_string(Settings.LOCALE))
	equal("and a setting it changes is written where the path says",
		FileAccess.file_exists(probe), true)
	SaveSystem.save_dir = store
	Settings.file_path = settings

	equal("the opt-out redirects nothing",
		DevSaves.apply(PackedStringArray(["--new-game", DevSaves.REAL_SAVES_FLAG])), false)
	equal("scratch is not the player's file",
		DevSaves.SCRATCH_SETTINGS != Settings.PATH, true)
	equal("nor any suite run's", DevSaves.SCRATCH_SETTINGS.begins_with(RunScratch.PARENT), false)
