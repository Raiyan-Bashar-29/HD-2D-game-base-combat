extends SceneTree
## Method gate: FAILS if a public method declared under src/ is called by nothing, anywhere.
##
## RUN:  godot_console --headless --script tools/check_methods.gd
## Exit 0 if clean, 1 on any violation. Sits in the ladder next to check_signals.gd.
##
## THE FOURTH CONSUMER QUESTION, and the last of the four with no enforcement. T5.4 built three
## gates for the "declared and read by nothing" class and T5.5 asked it of the settings in the
## suite; a PUBLIC METHOD was still declarable-and-dead with nothing saying so. That is how
## `AudioDirector.duck()` survived three phases uncalled and — when finally wired at T5.11 —
## turned out to be WRONG as well as unused, ducking to an absolute -8 dB and so making the
## music LOUDER for a player who had turned it down. CODE WITH NO CONSUMER IS NOT MERELY
## UNUSED, IT IS UNVERIFIED. This gate is proved against that exact case: at the commit before
## T5.11, `duck`, `unduck` and `stop_music` had zero references outside their own declarations,
## so this tool would have failed the build on the day each of them landed.
##
## WHAT IT IS ASKED OF, WHICH IS THE WHOLE DESIGN. Every `func name` and `static func name` at
## column 0 under src/ whose name does not begin with an underscore. The question asked of each
## is deliberately the NARROWEST one a text scan can answer soundly: does the name appear, as a
## whole word, on a non-comment line ANYWHERE in the repository other than its own declaration
## header? Not "is it called on a value of the right type" — a scan cannot know a variable's
## static type, and does not need to, because it is not trying to resolve the call, only to find
## out whether anybody wrote the name down at all.
##
## AND WHAT IT IS DELIBERATELY NOT ASKED, WHICH MATTERS AS MUCH. "Has a caller in the suite" is
## not "has a caller in the game", and the distinction is real here: 86 of the 316 public
## methods are reached only from tests/ or tools/. It is REPORTED and never failed, for
## check_signals.gd's reason for listeners exactly — a template declares accessors a consuming
## game calls and this repository never will, so failing on them would train everybody to write
## a fake caller, and a gate that starts out mostly exemptions is decoration. The count is
## printed so it cannot quietly grow.
##
## WHICH DIRECTION IT ERRS IN. A local variable, a parameter or another class's method sharing a
## name makes a dead method look alive, so the gate UNDER-reports; 37 names are declared in more
## than one file and are treated as one name. It cannot invent a violation, which is the right
## way round for something that fails a build. Declaration headers are dropped before scanning,
## so a parameter named after a method is not mistaken for a call to it.
##
## MUST NOT: load a class, instantiate a scene, or reference an autoload. Pure text, like the
## three gates beside it, so it still runs in a checkout whose data/ has been deleted.

const SRC_ROOT: String = "res://src"
const CODE_ROOTS: Array[String] = ["res://src", "res://tests", "res://tools"]
const DATA_ROOTS: Array[String] = ["res://scenes", "res://data"]
const DATA_EXTENSIONS: Array[String] = [".tscn", ".tres"]

## Same alphabet as check_boundary.gd and check_signals.gd, spelled out rather than shared for
## the reason recorded there: a gate with a dependency has a way to be silently switched off.
const WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

## THE ONE CALL FORM THIS GATE CANNOT SEE, checked rather than assumed. A name that appears in
## the source is found wherever it is written — inside a string, inside a `Callable(o, "name")`,
## inside a .tscn property — because the scan reads text and does not care what the text is for.
## The single form that would hide a name completely is one BUILT at runtime, `o.call("fetch_"
## + kind)`. There are none today: every dispatch site in the repository names its method in
## full. If one ever appears this gate stops measuring what it claims to, so it fails loudly
## instead of quietly — check_boundary.gd's debug-gate precondition, in this file's terms.
const DISPATCH: Array[String] = ["call(", "callv(", "call_deferred(", "Callable(", "has_method("]
const BUILDS_A_NAME: Array[String] = ["\" +", "+ \"", "\" %", ".format("]

## THE ESCAPE HATCH, and it is a phrase in the method's own `##` block for check_signals.gd's
## reason: a real decision deserves recording next to the declaration, where the next reader is
## already looking, and not in a list inside a tool nobody opens. A method that carries the
## phrase AND has a caller fails too, because a stale exemption is how a gate rots into
## decoration. Every one carrying it today had to be argued in writing to earn it.
const RESERVED: String = "NO CALLER"

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _exempt: int = 0
var _declared: Dictionary[String, PackedStringArray] = {}
var _docs: Dictionary[String, String] = {}
var _refs: Dictionary[String, int] = {}


func _initialize() -> void:
	print("")
	print("Method check — every public method under src/ is called by something")
	print("=".repeat(78))
	var sources: Array[String] = _scripts_under(SRC_ROOT)
	for path: String in sources:
		_read_declarations(path)
	print("  public methods declared: %d over %d files" % [_declared.size(), sources.size()])
	_check_preconditions()
	_scan_group("src", sources)
	_scan_group("tests", _scripts_under("res://tests"))
	_scan_group("tools", _scripts_under("res://tools"))
	_scan_group("data", _data_files())
	_report()
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d method violation(s)" % _violations)
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


func _collect(directory: String, extension: String, into: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect("%s/%s" % [directory, sub], extension, into)
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(extension):
			into.append("%s/%s" % [directory, file_name])
			_scanned += 1


func _scripts_under(root: String) -> Array[String]:
	var found: Array[String] = []
	_collect(root, ".gd", found)
	return found


func _data_files() -> Array[String]:
	var found: Array[String] = []
	for root: String in DATA_ROOTS:
		for extension: String in DATA_EXTENSIONS:
			_collect(root, extension, found)
	return found


## THE GATE'S OWN REASONING, CHECKED RATHER THAN ASSUMED. A dispatch line that also builds a
## string can name a method this tool will never see, and a green run would then say nothing
## about that method at all. Failing loudly is the only honest response to that.
func _check_preconditions() -> void:
	var checked: int = 0
	for root: String in CODE_ROOTS:
		for path: String in _scripts_under(root):
			checked += 1
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				if line.strip_edges().begins_with("#") or not _has_any(line, DISPATCH):
					continue
				if _has_any(line, BUILDS_A_NAME):
					_fail("%s dispatches by a BUILT name — this gate cannot see that: %s"
						% [path, line.strip_edges()])
	print("  preconditions: %d scripts checked for a name built at runtime" % checked)


static func _has_any(line: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if line.contains(needle):
			return true
	return false


## Every public method, mapped to the `##` block immediately above it, which is where the
## RESERVED phrase lives. The block is accumulated and cleared on any non-comment line, so a doc
## comment attaches to exactly the declaration it precedes. A name declared in more than one
## file — `perform` is on eleven — is ONE entry, so the phrase on any of them exempts all of
## them: honest for an override family, and stated in the header as a limit.
func _read_declarations(path: String) -> void:
	var block: String = ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("##"):
			block += line
			continue
		var name: String = _declared_name(line)
		if name != "" and not name.begins_with("_"):
			var owners: PackedStringArray = _declared.get(name, PackedStringArray())
			owners.append(path)
			_declared[name] = owners
			_docs[name] = _docs.get(name, "") + block
		block = ""


static func _declared_name(line: String) -> String:
	if line.begins_with("func "):
		return line.substr(5).get_slice("(", 0).strip_edges()
	if line.begins_with("static func "):
		return line.substr(12).get_slice("(", 0).strip_edges()
	return ""


func _scan_group(group: String, paths: Array[String]) -> void:
	for path: String in paths:
		var code: String = _code_of(FileAccess.get_file_as_string(path))
		for name: String in _declared:
			var hits: int = _hits(code, name)
			if hits == 0:
				continue
			var bucket: String = "self" if _declared[name].has(path) else group
			_refs[name + "|" + bucket] = _refs.get(name + "|" + bucket, 0) + hits


## Comment lines and declaration HEADERS removed. Both matter. A method named in prose is not a
## caller — `## Undo duck() by re-reading the settings` was the only other place the word `duck`
## appeared in this repository before T5.11 — and a parameter named after a method is not a call
## to it either.
static func _code_of(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#") or _declared_name(line) != "":
			continue
		kept.append(line)
	return "\n".join(kept)


static func _hits(source: String, name: String) -> int:
	var found: int = 0
	var at: int = source.find(name)
	while at >= 0:
		var before: String = "" if at == 0 else source.substr(at - 1, 1)
		var after: String = source.substr(at + name.length(), 1)
		var left_clear: bool = before == "" or not WORD_CHARS.contains(before)
		var right_clear: bool = after == "" or not WORD_CHARS.contains(after)
		if left_clear and right_clear:
			found += 1
		at = source.find(name, at + 1)
	return found


func _count(name: String, bucket: String) -> int:
	return _refs.get(name + "|" + bucket, 0)


## A METHOD REACHED ONLY FROM tests/ OR tools/ IS REPORTED AND NOT FAILED, and the asymmetry is
## deliberate — check_signals.gd's for a signal with no listener, in this file's terms. The
## template declares accessors for a consuming game to call, and this repository is not that
## game; failing here would be answered with a fake caller, which is worse than the disease.
func _report() -> void:
	var suite_only: int = 0
	var shared: int = 0
	for name: String in _declared:
		if _declared[name].size() > 1:
			shared += 1
		var game: int = _count(name, "src") + _count(name, "data")
		var harness: int = _count(name, "tests") + _count(name, "tools")
		var doc: String = _docs.get(name, "")
		var reserved: bool = doc.contains(RESERVED)
		if reserved:
			_exempt += 1
		_judge(name, _count(name, "self") + game + harness, reserved)
		if game == 0 and harness > 0:
			suite_only += 1
	print("  exempted by '%s' in their own ## block: %d" % [RESERVED, _exempt])
	print("  names declared in more than one file, treated as one: %d" % shared)
	print("  reached only from tests/ or tools/ (reported, not failed): %d" % suite_only)


func _judge(name: String, total: int, reserved: bool) -> void:
	var owners: String = str(_declared[name])
	if total == 0 and not reserved:
		_fail("%s() is declared and called by nothing — %s (say '%s' in its ## block if that "
			% [name, owners, RESERVED] + "is deliberate)")
	if total > 0 and reserved:
		_fail("%s() is marked '%s' and has %d reference(s) — the exemption is stale: %s"
			% [name, RESERVED, total, owners])
