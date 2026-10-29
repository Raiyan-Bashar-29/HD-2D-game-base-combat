extends SceneTree
## Localization gate: FAILS if a player-facing string literal reaches the screen, or if a
## localization key declared in code has no row in the CSV.
##
## RUN:  godot_console --headless --script tools/check_strings.gd
## Exit 0 if clean, 1 on any violation. Sits in the ladder next to check_boundary.gd.
##
## THIS IS THE "HARD-CODED-STRING AUDIT" WP-14 ASKED FOR, AND IT IS DELIBERATELY NOT THE ONE
## check_content.gd REFUSED. That file's header says a general audit needs "semantics a text
## scan does not have", and it is right: nothing in a line of text says whether "world" is a log
## category, a flag namespace or a sentence meant for a player. So this tool does not guess. It
## checks the two things a scan really can see, and both are anchored at a SINK or at a
## DECLARATION rather than by inspecting a literal and wondering what it is for.
##
## MUST NOT: load a content class, instantiate a scene, or reference an autoload. Same reason as
## check_boundary.gd — it is pure text, so it keeps working in a checkout whose data/ has been
## deleted, which is the state a new game starts in.

const SRC_ROOT: String = "res://src"
const CSV: String = "res://localization/strings.csv"

## The properties that put text in front of a player. Every one verified against --doctool for
## 4.7.2: `text` on Label/Button/LineEdit/RichTextLabel, `tooltip_text` on Control,
## `placeholder_text` on LineEdit, `title` on Window. Matched with a trailing " = " so
## `text_direction` and `text_overrun_behavior`, which are enums and not text, are not swept in.
const SINKS: Array[String] = [
	".text = ", ".tooltip_text = ", ".placeholder_text = ", ".title = ",
]

## A const whose name ends in this holds a WHOLE localization key, by project convention — 67 of
## them at the time of writing. `*_PREFIX` deliberately does not qualify: a prefix is completed
## at runtime and is the unfollowable case described at _check_key.
const KEY_SUFFIX: String = "_KEY"

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _keys: Dictionary[String, bool] = {}
var _checked_keys: int = 0
var _patterns: int = 0
var _sink_lines: int = 0


func _initialize() -> void:
	print("")
	print("String check — no player-facing literal, and every declared key exists")
	print("=".repeat(78))
	_load_keys()
	var scripts: Array[String] = []
	_collect_files(SRC_ROOT, ".gd", scripts)
	print("  engine scripts scanned: %d" % scripts.size())
	for path: String in scripts:
		_scan(path)
	print("  text sinks found: %d" % _sink_lines)
	print("  key declarations checked against the CSV: %d" % _checked_keys)
	print("  key PATTERNS a text scan cannot follow, reported not skipped: %d" % _patterns)
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d string violation(s)" % _violations)
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


## The CSV is parsed as text, for the same two reasons check_content.gd gives: the engine's
## translation system is not available under --script, and a missing key has to be detectable
## even when strings.en.translation has not been regenerated.
func _load_keys() -> void:
	var file: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % CSV)
		return
	var first: bool = true
	while not file.eof_reached():
		var line: String = file.get_line()
		if first:
			first = false
			continue
		var comma: int = line.find(",")
		if comma <= 0:
			continue
		_keys[line.substr(0, comma)] = true
	file.close()
	print("  CSV rows loaded: %d" % _keys.size())


func _scan(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % path)
		return
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		# Comments are exempt, code is not — the same line check_boundary.gd and
		# check_budgets.gd draw, for the same reason: a `##` line teaching
		# `label.text = tr(SOME_KEY)` changes no behaviour.
		if line.strip_edges().begins_with("#"):
			continue
		_check_sink(path, line_number, line)
		_check_key(path, line_number, line)
	file.close()


## CHECK ONE — THE SINK RULE, and why it is a sink rule rather than a literal rule.
##
## Non-negotiable #3 is "no player-facing string literals", and the reason check_content.gd
## refused a general audit is that a literal cannot be classified by looking at it. A SINK can:
## whatever reaches `.text` is on the screen by construction, whatever its content. So the rule
## is
##
##     the right-hand side of a text assignment either passes through tr(), or contains no
##     string literal at all
##
## which is checkable, has no false positives on the sinks in the project today, and never
## requires the tool to have an opinion about an individual string.
## `label.text = text_value` passes because it holds no literal;
## `button.text = tr(A if held else B).format({"item": x})` passes on the tr(), which is what
## makes the `.format()` dictionary key harmless rather than something the scan must parse.
##
## WHAT IT CANNOT SEE, stated so nobody reads a green run as more than it is:
##   - a literal that reaches a sink through a VARIABLE assigned on an earlier line
##   - a sink outside src/*.gd, so a .tscn authoring `text = "Play"` directly is not scanned
##   - a literal handed to an API that draws text without going through a property:
##     draw_string(), set_tooltip_text(), an OS dialog
##   - whether the key tr() was handed is the RIGHT key. A wrong key that exists renders the
##     wrong sentence, which is gotcha 2's shape and is not a text-scan problem
func _check_sink(path: String, line_number: int, line: String) -> void:
	for sink: String in SINKS:
		if not line.contains(sink):
			continue
		_sink_lines += 1
		var rhs: String = line.substr(line.find(sink) + sink.length())
		if rhs.contains("tr(") or not rhs.contains("\""):
			continue
		_fail("%s:%d assigns a literal to %s with no tr(): %s" % [
			path, line_number, sink.strip_edges().trim_suffix(" ="), rhs.strip_edges(),
		])


## CHECK TWO — EVERY KEY DECLARED IN CODE EXISTS, and this is the half with teeth.
##
## 67 `*_KEY` consts under src/ name a CSV row, and nothing checked any of them until now:
## check_content.gd validates the keys authored in .tres content, and the enum loop in
## tests/unit/items_test.gd covers the two COMPUTED families (verb.*, refusal.*). A const key
## sat in neither. A typo in one renders the raw key on screen — `notify.item_takne` — which is
## gotcha 2's shape in its least visible form, because tr() returning its own argument is not an
## error and every rung stays green over it.
##
## A key holding `%` is a PATTERN completed at runtime (`weather.%s`), which no text scan can
## follow. It is COUNTED AND PRINTED rather than silently skipped, on check_boundary.gd's
## precedent: a gate that quietly ignores part of its input reads as a gate that covered
## everything.
func _check_key(path: String, line_number: int, line: String) -> void:
	var trimmed: String = line.strip_edges()
	if not trimmed.begins_with("const "):
		return
	var colon: int = trimmed.find(":")
	if colon < 0:
		return
	var const_name: String = trimmed.substr(6, colon - 6).strip_edges()
	if not const_name.ends_with(KEY_SUFFIX):
		return
	var key: String = _first_quoted(trimmed)
	if key == "":
		return
	if key.contains("%"):
		_patterns += 1
		print("  .. %s:%d %s is the pattern '%s'" % [path, line_number, const_name, key])
		return
	_checked_keys += 1
	if not _keys.has(key):
		_fail("%s:%d %s = '%s' has no row in %s" % [path, line_number, const_name, key, CSV])


func _first_quoted(line: String) -> String:
	var opened: int = line.find("\"")
	if opened < 0:
		return ""
	var rest: String = line.substr(opened + 1)
	var closed: int = rest.find("\"")
	return rest.substr(0, closed) if closed > 0 else ""
