extends SceneTree
## Mechanical enforcement of the size and hygiene rules in docs/ARCHITECTURE.md.
##
## WHY THIS TOOL EXISTS AT ALL
## The previous project's `main.gd` reached 3,983 lines. Nobody decided to write a
## 3,983-line file; it grew twenty lines at a time, each of them reasonable. A rule that is
## only written in a document does not stop that. A rule that fails the build does.
##
## RUN:  godot_console --headless --script tools/check_budgets.gd
## Exit code 0 if clean, 1 if any budget is exceeded. Safe to wire into a commit hook.
##
## Budgets count CODE lines: blank lines and comments are excluded. Documentation is
## encouraged and must never push a file over its limit.
##
## MUST NOT: be given an exemption to make a violation go away. An exemption is a design
## decision and belongs in OVERRIDES with a reason, or the file needs splitting.

const DEFAULT_FILE_BUDGET: int = 250
const FUNCTION_BUDGET: int = 40
const SCAN_DIRS: Array[String] = ["res://src", "res://tools", "res://tests"]

## Tighter limits where a file has a specific reason to stay small. An autoload that owns one
## concern does not need 250 lines, and the game root must never grow at all.
const OVERRIDES: Dictionary = {
	"res://src/core/boot/game_root.gd": 60,
	"res://src/core/log/log.gd": 150,
	"res://src/core/events/events.gd": 150,
	"res://src/core/state/flags.gd": 150,
	"res://src/core/state/settings.gd": 150,
	"res://src/core/save/save_system.gd": 180,
	"res://src/systems/input/actions.gd": 150,
	"res://src/systems/world_clock/clock.gd": 150,
	"res://src/systems/weather/weather.gd": 150,
	"res://src/systems/audio/audio_director.gd": 150,
	## Raised from 180 to 190 by WP-14, deliberately and with the reasoning in
	## docs/ARCHITECTURE.md § Line budgets: Director gained the shutdown drain for its own
	## loader thread, which is inside its stated OWNS and cannot live anywhere else, and
	## splitting the project's one guarded transition path to save seven lines would trade
	## real safety for a number. Still 60 under the 250 default.
	"res://src/systems/scene_director/director.gd": 190,
}

## print() is the logger's job everywhere except: the tools and tests, which run before the
## autoloads exist, and the logger itself, which is what actually does the printing.
const PRINT_ALLOWED: Array[String] = ["res://tools/", "res://tests/", "res://src/core/log/"]

## Files that are pure constants or data shapes have nothing to be forbidden from knowing,
## so the boundary-note reminder would just be noise.
const BOUNDARY_EXEMPT: Array[String] = ["res://src/core/util/"]

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _warnings: int = 0
var _files: int = 0
var _code_lines: int = 0


func _initialize() -> void:
	print("")
	print("Budget check — code lines exclude blanks and comments")
	print("=".repeat(78))

	var scripts: Array[String] = []
	for directory: String in SCAN_DIRS:
		_collect(directory, scripts)
	scripts.sort()
	for path: String in scripts:
		_check(path)

	print("=".repeat(78))
	print("%d files, %d code lines, %d warnings, %d violations" % [
		_files, _code_lines, _warnings, _violations,
	])
	if _violations > 0:
		print("FAIL — split the file, or justify a new budget in docs/ARCHITECTURE.md")
		quit(1)
		return
	if _scanned == 0:
		print("FAIL — nothing was scanned, so this gate could only ever pass")
		quit(1)
		return
	print("PASS")
	quit(0)


func _collect(directory: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [directory, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(full, into)
		elif entry.ends_with(".gd"):
			into.append(full)
			_scanned += 1
		entry = dir.get_next()
	dir.list_dir_end()


func _check(path: String) -> void:
	var text: String = _read(path)
	if text == "":
		return
	_files += 1

	var offenders: Array[String] = []
	var report: Dictionary = _scan(path, text.split("\n"), offenders)
	var code: int = DictRead.get_int(report, "code")
	var budget: int = OVERRIDES.get(path, DEFAULT_FILE_BUDGET)
	var over: bool = code > budget

	_code_lines += code
	if over:
		_violations += 1
	_violations += offenders.size()

	print("  %s %-52s %4d / %4d" % ["OVER" if over else "ok  ", path.trim_prefix("res://"), code, budget])
	for offender: String in offenders:
		print("       !! %s" % offender)
	_report_doc_warnings(path, DictRead.get_bool(report, "doc"), DictRead.get_bool(report, "boundary"))


## One pass over the file, gathering everything at once. Returns code line count and whether
## the header documents the file and states its boundary.
func _scan(path: String, lines: PackedStringArray, offenders: Array[String]) -> Dictionary:
	var code: int = 0
	var doc: bool = false
	var boundary: bool = false
	var function: String = ""
	var length: int = 0
	var start: int = 0

	for index: int in lines.size():
		var raw: String = lines[index]
		var trimmed: String = raw.strip_edges()

		if trimmed.begins_with("##"):
			doc = true
			if trimmed.to_upper().contains("MUST NOT"):
				boundary = true
			continue
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		code += 1
		if raw.begins_with("func ") or raw.begins_with("static func "):
			_close(function, length, start, offenders)
			function = trimmed.get_slice("(", 0).replace("static ", "").replace("func ", "")
			length = 0
			start = index + 1
		elif function != "":
			length += 1

		if trimmed.begins_with("print(") and not _prefixed(path, PRINT_ALLOWED):
			offenders.append("line %d uses print(); use Log instead" % (index + 1))

	_close(function, length, start, offenders)
	return {"code": code, "doc": doc, "boundary": boundary}


## Documentation expectations are warnings, not failures. Blocking on a boundary note would
## only encourage writing one thoughtlessly, which defeats the point of having it.
func _report_doc_warnings(path: String, has_doc: bool, has_boundary: bool) -> void:
	if not has_doc:
		_warnings += 1
		print("       -- no file docstring (## after `extends`)")
		return
	if has_boundary or not path.begins_with("res://src/"):
		return
	if _prefixed(path, BOUNDARY_EXEMPT):
		return
	_warnings += 1
	print("       -- no MUST NOT boundary stated in the header")


func _close(name: String, length: int, start_line: int, offenders: Array[String]) -> void:
	if name == "" or length <= FUNCTION_BUDGET:
		return
	offenders.append("%s() is %d lines (limit %d), starting line %d" % [
		name, length, FUNCTION_BUDGET, start_line,
	])


func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("  ?? cannot open %s" % path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _prefixed(path: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if path.begins_with(prefix):
			return true
	return false
