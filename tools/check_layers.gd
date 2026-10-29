extends SceneTree
## Layer gate: FAILS if a file under src/ references a symbol from a HIGHER layer.
##
## RUN:  godot_console --headless --script tools/check_layers.gd
## Exit 0 if clean, 1 on any violation. Sits in the ladder next to check_boundary.gd.
##
## THE RULE IS docs/ARCHITECTURE.md's CENTRAL INVARIANT, AND UNTIL NOW NOTHING ENFORCED IT:
##
##     core -> content -> systems -> gameplay -> ui, downward only.
##
## Four gates already stood — content, budgets, strings, the demo boundary — and the one
## architectural rule the whole tree is shaped around had none. That is the same shape as
## `const FIRST_AREA := &"courtyard"` sitting in core before T1.2: it passed every rung
## because no rule forbade it. The tree is clean today, which is exactly why gating it is
## cheap; the cost of a gate is paid when the first violation arrives, not now.
##
## HOW A REFERENCE IS SEEN. Two ways, because there are two ways to couple upward:
##   1. A `class_name` global. Every one under src/ is mapped to its own file's layer, so
##      an interactable base IS gameplay and a systems file naming it is a violation.
##   2. A `res://src/<layer>/` path literal, which is how preload() and load() couple without
##      ever naming a class.
## Whole-word matching, borrowed from check_boundary.names_whole_word for the reason recorded
## there: substring matching failed on the word "appeared" once already.
##
## MUST NOT: load a content class, instantiate a scene, or reference an autoload. Pure text, so
## it keeps working in a checkout whose data/ has been deleted — the state a new game starts in.

const SRC_ROOT: String = "res://src"
const PROJECT_FILE: String = "res://project.godot"
const BOUNDARY = preload("res://tools/check_boundary.gd")

## The direction, written once. Index IS the layer number, so a comparison is `>`.
const LAYERS: Array[String] = ["core", "content", "systems", "gameplay", "ui"]

## THE TWO EXEMPTIONS, written down rather than silently applied, and COUNTED AND REPORTED
## rather than skipped, so neither can quietly grow.
##
## 1. THE COMPOSITION ROOT. The game root is the node that BUILDS the tree: it lives in core
##    because it must boot before anything else, and it hands control to the scene director,
##    which is systems. Something has to know both ends or nothing is ever assembled — that is
##    what a composition root IS, and the alternative is a GameManager, which has an ADR
##    against it. One file, one upward reference.
##
## 2. THE DEVELOPMENT HARNESS, src/systems/debug/. Same directory check_boundary.gd exempts,
##    for the same reason and on the same precondition: those files exist to DRIVE the whole
##    game from outside — stage a screen, probe a component, photograph a frame — so they
##    reach across every layer by definition, and there is no layer above ui to put them in.
##    They are not the engine; deleting all four must not break the game, which their own
##    headers already require, and since T1.2 their argument parsing is behind
##    `OS.is_debug_build()`, so they are not reachable in a shipped build at all. That gate is
##    the precondition, and check_boundary.gd already fails if it is ever removed.
##
## The five autoloads under src/systems/ need NO exemption and deliberately do not get one:
## they sit at layer 2, so a gameplay or ui file calling them is already downward and legal.
## Their layer is DERIVED from the script path in project.godot's [autoload] block, so moving
## one moves what may call it, with no edit here.
const EXEMPT: Dictionary[String, String] = {
	"res://src/core/boot/game_root.gd":
		"the composition root — it assembles the tree and must know what it assembles",
	"res://src/systems/debug/":
		"the development harness — it drives every layer and is gated on a debug build",
}

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _exempted: int = 0
var _symbols: Dictionary[String, int] = {}
var _sources: Dictionary[String, String] = {}


func _initialize() -> void:
	print("")
	print("Layer check — %s, downward only" % " -> ".join(LAYERS))
	print("=".repeat(78))
	_map_symbols()
	_check_layers()
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d upward reference(s)" % _violations)
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


## The layer a path belongs to, or -1 for anything outside src/. Derived from the path alone,
## so a file moved between directories changes what it may see with no edit here.
static func layer_of(path: String) -> int:
	for index: int in LAYERS.size():
		if path.begins_with("%s/%s/" % [SRC_ROOT, LAYERS[index]]):
			return index
	return -1


## Every `class_name` under src/, plus every autoload name in project.godot, mapped to the
## layer of the file that declares it.
func _map_symbols() -> void:
	var scripts: Array[String] = []
	_collect_files(SRC_ROOT, ".gd", scripts)
	for path: String in scripts:
		var declared: String = _class_name_in(path)
		if declared == "":
			continue
		_symbols[declared] = layer_of(path)
		_sources[declared] = path
	_map_autoloads()
	print("  symbols mapped: %d over %d scripts" % [_symbols.size(), scripts.size()])


func _class_name_in(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var found: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("class_name "):
			found = line.substr(11).strip_edges().split(" ")[0]
			break
	file.close()
	return found


## AUTOLOADS ARE READ FROM project.godot RATHER THAN LISTED, which is what makes the "the five
## systems autoloads are globals" carve-out automatic instead of a comment somebody has to
## maintain. An entry of the form Name="*res://src/systems/.../file.gd" says layer 2 outright.
func _map_autoloads() -> void:
	var file: FileAccess = FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % PROJECT_FILE)
		return
	var inside: bool = false
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("["):
			inside = line == "[autoload]"
			continue
		if not inside or not line.contains("=\"*res://"):
			continue
		var autoload_name: String = line.get_slice("=", 0)
		var path: String = line.get_slice("\"*", 1).trim_suffix("\"")
		_symbols[autoload_name] = layer_of(path)
		_sources[autoload_name] = path
	file.close()


func _check_layers() -> void:
	var scripts: Array[String] = []
	_collect_files(SRC_ROOT, ".gd", scripts)
	print("  scripts scanned: %d" % scripts.size())
	for path: String in scripts:
		_scan_script(path, layer_of(path))
	print("  exempted upward references: %d" % _exempted)
	for path: String in EXEMPT:
		print("  exempt: %s — %s" % [path, EXEMPT[path]])


## An EXEMPT key ending in "/" covers a directory; anything else is one exact file. Two forms
## rather than one because the two exemptions are genuinely different shapes: the composition
## root is a single file and must stay one, and the harness is a whole directory whose file
## count changes as tooling is split.
static func _is_exempt(path: String) -> bool:
	for key: String in EXEMPT:
		if path == key or (key.ends_with("/") and path.begins_with(key)):
			return true
	return false


func _scan_script(path: String, layer: int) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % path)
		return
	var own: String = _class_name_in(path)
	var exempt: bool = _is_exempt(path)
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		if line.strip_edges().begins_with("#"):
			continue
		for symbol: String in _symbols:
			if symbol == own or _symbols[symbol] <= layer:
				continue
			if not names_whole_word(line, symbol):
				continue
			if exempt:
				_exempted += 1
				continue
			_fail("%s:%d (%s) names %s, which is %s — %s" % [
				path, line_number, LAYERS[layer], symbol,
				LAYERS[_symbols[symbol]], _sources[symbol],
			])
		_scan_path_literal(path, layer, line, line_number, exempt)
	file.close()


## THE SECOND WAY TO COUPLE UPWARD, and the one a class-name scan cannot see. `preload()` and
## `load()` take a string, so a core file can reach a ui script without ever naming a class.
func _scan_path_literal(path: String, layer: int, line: String, line_number: int,
		exempt: bool) -> void:
	for index: int in LAYERS.size():
		if index <= layer:
			continue
		var prefix: String = "%s/%s/" % [SRC_ROOT, LAYERS[index]]
		if not line.contains(prefix):
			continue
		if exempt:
			_exempted += 1
			continue
		_fail("%s:%d (%s) contains the path %s, which is %s" % [
			path, line_number, LAYERS[layer], prefix, LAYERS[index],
		])


## Borrowed rather than re-derived: check_boundary.gd already learned, at a cost, that a
## substring match fails on real words. One definition of "names this identifier" for both
## gates, so a fix to one is a fix to both.
static func names_whole_word(line: String, symbol: String) -> bool:
	return BOUNDARY.names_whole_word(line, symbol)
