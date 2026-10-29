extends SceneTree
## Boundary gate: FAILS if any file under src/, tests/framework/ or tests/unit/ names demo content,
## or if localization/strings.csv translates content that does not exist.
##
## RUN:  godot_console --headless --script tools/check_boundary.gd
## Exit 0 if clean, 1 on any violation. Sits in the ladder next to check_content.gd.
##
## WHY IT IS A SEPARATE TOOL. It began inside check_content.gd, which is where T1.2's brief put
## it, and check_budgets.gd refused the result at 252 of the 250 allowed code lines. The seam was
## already there: check_content.gd validates that the DEMO is well formed — real items, real
## keys, no duplicate ids — and this validates that the ENGINE does not know the demo exists.
## Those two answer opposite questions, and this one loads nothing: it is pure text, so it keeps
## working when the content it is scanning for has been deleted, which is precisely the state a
## new game starts in. Fourth time the budget checker has exposed a split that was already in the
## reasoning, after the three-way split of the debug surface.
##
## MUST NOT: load a content class, instantiate a scene, or reference an autoload. If it needed
## either it would stop working the moment a consuming game deleted data/, which is the one
## moment it most needs to run.

const SRC_ROOT: String = "res://src"
const DATA_ROOT: String = "res://data"
const AREA_ROOT: String = "res://scenes/areas"
const CSV: String = "res://localization/strings.csv"

## THE FOUR KEY NAMESPACES WHOSE SECOND SEGMENT IS A CONTENT ID. `area.courtyard.name` names an
## area, `item.rose_key.name` an item, `talk.<id>` a conversation, `quest.<id>` a quest — every
## one of them a name this file already derives from data/ and scenes/areas/. The other two
## content namespaces, `object.` and `action.`, are NOT here and cannot be: an object's label
## key is authored freely and its `object_id` in the area scene is a different string, so there
## is nothing to compare. They are counted in the prune surface below and not gated. Stated so
## nobody reads a green run as "the CSV holds no demo content".
const ID_NAMESPACES: Array[String] = ["area", "item", "talk", "quest"]

## Every content namespace, for the REPORT rather than the gate. `item.category.*` is the one
## row family inside a content namespace that is engine: the eight item categories are an enum's
## worth of labels, not content, and NEW_GAME.md already carves them out by name.
const CONTENT_NAMESPACES: Array[String] = ["area", "item", "talk", "quest", "object", "action"]
const ENGINE_ROWS: String = "item.category."
## The suite too, as of T1.3. It used to be exempt because a third of its assertions named demo
## content and unwelding it was T1.3's own job; now that the fixtures exist, scanning it is what
## stops the welding growing back one convenient literal at a time.
const TEST_ROOTS: Array[String] = ["res://tests/framework", "res://tests/unit"]

## The one exemption from the rule. Justified at _scan_script below.
const DEBUG_DIR: String = "res://src/systems/debug/"

## What makes a neighbouring character part of a LONGER word. See names_whole_word.
const WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _exempted: int = 0


func _initialize() -> void:
	print("")
	print("Boundary check — no file under src/ may name demo content")
	print("=".repeat(78))
	_check_boundary()
	_check_debug_gate()
	_check_localization()
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d boundary violation(s)" % _violations)
		quit(1)
		return
	if _scanned == 0:
		print("FAIL — nothing was scanned, so this gate could only ever pass")
		quit(1)
		return
	print("PASS")
	quit(0)


func _fail(message: String) -> void:
	_violations += 1
	print("  !! %s" % message)


func _collect_files(directory: String, extension: String, into: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_files("%s/%s" % [directory, sub], extension, into)
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(extension):
			into.append("%s/%s" % [directory, file_name])
			_scanned += 1


func _quoted_after(line: String, marker: String) -> String:
	var at: int = line.find(marker)
	if at < 0:
		return ""
	var rest: String = line.substr(at + marker.length())
	var end: int = rest.find("\"")
	return rest.substr(0, end) if end > 0 else ""


## THE ENGINE/DEMO BOUNDARY GATE (T1.2). docs/TEMPLATE.md states the rule:
##
##     No file under src/ may name demo content.
##
## The names are DERIVED, never listed here, so the gate cannot go stale when content is added:
## every folder under scenes/areas, and the `id` of every .tres under data/, plus that id's last
## segment (`schedule/keeper` also forbids the bare `keeper`).
##
## THE RULE ABOUT COMMENTS, decided deliberately. A line whose first non-whitespace character is
## `#` is a comment and is NOT scanned; everything else is. Same definition check_budgets.gd
## uses, and the reason is that a `##` line saying `data/items/rose_key.tres must declare
## id = &"item/rose_key"` is TEACHING BY EXAMPLE — it is how the file-name-is-the-id rule is
## explained, it changes no behaviour, and forbidding it would push the documentation into
## abstraction nobody can follow. A `const FIRST_AREA := &"courtyard"` changes behaviour, and
## that is the whole difference.
##
## WHAT IT CANNOT SEE, stated so nobody mistakes a green run for a proof:
##   - a name assembled at runtime, "item/" + kind
##   - a demo name that appears in NEITHER data/ nor scenes/areas/: a waypoint marker, a node
##     name inside an area scene, a flag namespace invented in code
##   - anything outside src/*.gd — the prefabs in scenes/objects/ are not scanned
## A trailing comment on a code line IS scanned, deliberately: that is stricter than the rule
## needs, and stricter is the safe direction for a gate.
func _check_boundary() -> void:
	var demo: Dictionary[String, String] = _demo_names()
	print("  demo names derived: %d — %s" % [demo.size(), str(demo.keys())])
	var scripts: Array[String] = []
	_collect_files(SRC_ROOT, ".gd", scripts)
	for root: String in TEST_ROOTS:
		_collect_files(root, ".gd", scripts)
	print("  engine scripts scanned: %d, over src/ and %s (%s is exempt)" % [
		scripts.size(), str(TEST_ROOTS), DEBUG_DIR,
	])
	for path: String in scripts:
		_scan_script(path, demo)
	print("  demo names inside the exempt debug surface: %d" % _exempted)


## Every folder under scenes/areas and every id under data/, with where each came from so a
## violation can say WHY the name is demo content.
func _demo_names() -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for directory: String in DirAccess.get_directories_at(AREA_ROOT):
		found[directory] = "%s/%s" % [AREA_ROOT, directory]
	_collect_ids(DATA_ROOT, found)
	return found


func _collect_ids(root: String, into: Dictionary[String, String]) -> void:
	for directory: String in DirAccess.get_directories_at(root):
		_collect_ids("%s/%s" % [root, directory], into)
	for file_name: String in DirAccess.get_files_at(root):
		if not file_name.ends_with(".tres"):
			continue
		var path: String = "%s/%s" % [root, file_name]
		var id: String = _resource_id(path)
		if id == "":
			continue
		into[id] = path
		var parts: PackedStringArray = id.split("/")
		into[parts[parts.size() - 1]] = path


## Text-scanned rather than loaded, so it works for a .tres of any type and needs no class to
## be registered. Anchored at the start of the line on purpose: `node_id = &"..."` and
## `schedule_id = &"..."` are references, not declarations, and would poison the list.
func _resource_id(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var id: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("id = &\""):
			id = _quoted_after(line, "id = &\"")
			break
	file.close()
	return id


## The exemption for src/systems/debug/, and why it is written down rather than silently applied.
## Those three files EXIST to drive the demo: --give=item/rose_key stages a photograph, and a
## probe that travelled to an abstract area would verify nothing. They are the development
## harness, not the engine — deleting all three must not break the game, which their own headers
## already require — and since T1.2 their argument parsing is behind OS.is_debug_build(), so they
## are not reachable in a shipped build at all. The exemption is COUNTED and REPORTED above
## rather than skipped, so a new game can see how much rewriting the harness needs.
func _scan_script(path: String, demo: Dictionary[String, String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % path)
		return
	var exempt: bool = path.begins_with(DEBUG_DIR)
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		if line.strip_edges().begins_with("#"):
			continue
		for name: String in demo:
			if not names_whole_word(line, name):
				continue
			if exempt:
				_exempted += 1
				continue
			_fail("%s:%d names demo content '%s' (from %s)" % [path, line_number, name, demo[name]])
	file.close()


## A CONTENT ID IS MATCHED AS A WHOLE WORD, AND THE SUBSTRING VERSION WAS A REAL DEFECT.
## T4.2 authored an item called 'pear' — nothing exotic — and this gate failed on
## tests/unit/menus_test.gd's "and Load has appeared under it", because "appeared" contains it.
## A consuming game cannot fix that line, and AUTHORING.md's gate table told it the fault was
## "a bug in the engine, not in your content", so the author is sent to file a bug rather than to
## rename. Gotcha 44's shape: green in the full demo and green in the stripped template, red only
## in a consumer's hands, because the collision needs an id this repository does not have.
## An id may contain "/" (item/pear), so only the ENDS are checked; the neighbours that would
## make this a longer word are the identifier characters.
static func names_whole_word(line: String, name: String) -> bool:
	var from: int = 0
	while true:
		var at: int = line.find(name, from)
		if at < 0:
			return false
		var after: int = at + name.length()
		var before_char: String = line.substr(at - 1, 1) if at > 0 else ""
		var after_char: String = line.substr(after, 1) if after < line.length() else ""
		if not _is_word_char(before_char) and not _is_word_char(after_char):
			return true
		from = at + 1
	return false


static func _is_word_char(character: String) -> bool:
	return character != "" and WORD_CHARS.contains(character)


## THE DEBUG EXEMPTION HAS A PRECONDITION, AND THIS IS IT. src/systems/debug/ is allowed to name
## demo content because it is the development harness and is not reachable in a shipped build —
## so if it ever becomes reachable, the exemption is no longer justified and this must fail.
## Until T1.2 only the F12 hotkey was gated: --give=, --standing= and --goto= all answered a
## release export, which meant the exemption above would have been granted to code a player
## could drive. An exemption and the condition it rests on belong in the same file.
func _check_debug_gate() -> void:
	var scripts: Array[String] = []
	_collect_files(DEBUG_DIR.trim_suffix("/"), ".gd", scripts)
	print("  debug scripts checked for a release gate: %d" % scripts.size())
	for path: String in scripts:
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("func _parse_arguments()"):
			continue
		if not source.contains("if not OS.is_debug_build():"):
			_fail("%s parses command-line arguments with no OS.is_debug_build() guard" % path)


## GOTCHA 48, CLOSED: UNTIL NOW NO GATE READ localization/ FOR DEMO CONTENT AT ALL.
## check_content.gd and check_strings.gd both open this file, and both ask only whether a key
## a script names has a row and whether the row has two columns. Neither asks the opposite
## question — whether a ROW names content that exists — and the boundary gate above scans only
## src/ and tests/. So a translation for deleted content is nobody's error: nothing loads it,
## nothing complains, and it ships.
##
## THAT IS NOT HYPOTHETICAL. T4.3 forked this template, followed NEW_GAME.md's prune list, and
## shipped `quest.keepers_errand.*` — "The Keeper's Errand", "three rose petals" — inside its
## own game, with all four checkers and the whole suite green, because the list predated WP-08
## and never learned the word `quest.`.
##
## WHY THIS ONE HALF FAILS AND THE OTHER HALF ONLY REPORTS, decided rather than defaulted.
## The template legitimately ships its own demo rows: 51 of them, against 159 engine rows and
## 8 `item.category.*` rows that only look like content. Failing on their PRESENCE would fail
## this repository forever, which means the gate would have to be switched off here — and a
## gate that is off where it lives is decoration. So presence is REPORTED, as a prune surface a
## forker can read a number off.
##
## What FAILS is the ORPHAN: a row naming content that is not there. That is the actual defect
## T4.3 found, it is wrong in the template and wrong in every game built on it, and it is the
## exact state a half-finished prune leaves behind — delete data/quests/ and keep the rows, and
## this goes red. A fork that authored its own quest keeps its own data, so it stays green.
func _check_localization() -> void:
	var demo: Dictionary[String, String] = _demo_names()
	var file: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		print("  localization: no %s in this checkout" % CSV)
		return
	var counts: Dictionary[String, int] = {}
	var rows: int = 0
	## The first line is the column header, not a translation. Skipped by position rather than
	## by matching its text, because the column names are check_content.gd's business.
	var header: bool = true
	while not file.eof_reached():
		var key: String = file.get_line().get_slice(",", 0).strip_edges()
		if key == "":
			continue
		if header:
			header = false
			continue
		rows += 1
		var space: String = key.get_slice(".", 0)
		if not CONTENT_NAMESPACES.has(space) or key.begins_with(ENGINE_ROWS):
			continue
		counts[space] = counts.get(space, 0) + 1
		_check_row(key, space, demo)
	file.close()
	print("  localization rows: %d, of which %d are content namespace — %s" % [
		rows, _total(counts), str(counts),
	])


## The second segment IS the content id, and it is looked up in the same derived set the src/
## scan uses. `item.rose_key.name` asks about `rose_key`, which `data/items/rose_key.tres`
## put there as the last segment of `item/rose_key`.
func _check_row(key: String, space: String, demo: Dictionary[String, String]) -> void:
	if not ID_NAMESPACES.has(space):
		return
	var id: String = key.get_slice(".", 1)
	if id == "" or demo.has(id):
		return
	_fail("%s translates %s '%s', which exists in neither data/ nor scenes/areas/" % [
		CSV, space, id,
	])


static func _total(counts: Dictionary[String, int]) -> int:
	var sum: int = 0
	for space: String in counts:
		sum += counts[space]
	return sum
