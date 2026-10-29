extends SceneTree
## Signal gate: FAILS if a signal declared in the registry has no emitter anywhere.
##
## RUN:  godot_console --headless --script tools/check_signals.gd
## Exit 0 if clean, 1 on any violation. Sits in the ladder next to check_boundary.gd.
##
## THE STRUCTURAL HOLE THIS CLOSES. Four gates already stood — content, budgets, strings, the
## demo boundary — and NOT ONE OF THEM ASKED WHETHER A DECLARED THING HAS A CONSUMER. That is
## why "correct code with no consumer" has now been found seven times, every time through a
## fully green ladder. `item_used` and `debug_command` were both declared, both typed, both
## documented, and neither was ever emitted; this gate would have said so on the day each
## landed. It is the cheapest possible instance of the general rule, because the registry is
## ONE file and every declaration in it is one line.
##
## WHY A STATIC SCAN IS SOUND HERE, and the two preconditions it checks rather than assumes:
## there are zero `[connection]` blocks in any .tscn in the repository, and zero
## `emit_signal("name")` string calls. Either would let a signal be used without the text
## `Events.<name>` ever appearing, and the gate would then be measuring nothing. Both are
## asserted below, so the gate fails the day its own reasoning stops holding — the same shape
## as check_boundary.gd's debug-gate precondition.
##
## THE METHOD TRAP, which a naive grep for `<name>.emit` walks straight into. Several signals
## are dispatched INDIRECTLY, as first-class `Signal` values: the quest tracker passes
## `Events.quest_started` into a helper that calls `fact.emit`, and two screens return an
## `Array[Signal]` and connect to each member generically. A grep for `.emit` finds neither,
## so `quest_started` would read as dead. So a bare `Events.<name>` reference is resolved by
## what its FILE does with a `Signal`-typed identifier: a file that calls `.emit` on one is an
## emitter, a file that calls `.connect` on one is a listener. See _dispatch_role.
##
## MUST NOT: reference the `Events` autoload, or any autoload. The registry is read as TEXT,
## deliberately — a gate that needed the game booted could not run before the game boots.

const REGISTRY: String = "res://src/core/events/events.gd"
const SCAN_ROOTS: Array[String] = ["res://src", "res://tests"]
const SCENE_ROOT: String = "res://scenes"
const BUS: String = "Events."

## What makes a neighbouring character part of an identifier. Same alphabet check_boundary.gd
## uses, spelled out rather than shared, because importing it would make this gate depend on
## that one loading — and a gate with a dependency has a way to be silently switched off.
const WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

## THE ESCAPE HATCH, AND WHY IT IS A PHRASE IN THE DOC COMMENT RATHER THAN A LIST HERE.
## A signal with no emitter is not always a defect: `item_used` is a RESERVED NAME the template
## declares for a consuming game to emit from its own item script, which is Tier 2 in
## docs/ARCHITECTURE.md. That is a real decision and it deserves to be recorded — but next to
## the declaration, where the next reader is already looking, not in a list in a tool nobody
## opens. So the exemption is granted by writing this phrase in the signal's own `##` block,
## and a signal that both carries it AND has an emitter fails too, because a stale exemption
## is how a gate rots into decoration.
const RESERVED: String = "NO EMITTER"

var _violations: int = 0
## HOW MANY FILES THIS RUN ACTUALLY OPENED, counted in the collector so it cannot drift
## from the scan. A gate that scanned NOTHING reports PASS, and `CHANGELOG.md` says of
## doc gates that one passing because it found nothing to check is worse than no gate.
## That rule was never applied to these tools until T5.27.
var _scanned: int = 0
var _signals: Dictionary[String, String] = {}
var _emitters: Dictionary[String, int] = {}
var _listeners: Dictionary[String, int] = {}


func _initialize() -> void:
	print("")
	print("Signal check — every declared signal has an emitter")
	print("=".repeat(78))
	_check_preconditions()
	_read_registry()
	_scan_all()
	_report()
	print("=".repeat(78))
	if _violations > 0:
		print("FAIL — %d signal violation(s)" % _violations)
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


## THE GATE'S OWN REASONING, CHECKED RATHER THAN ASSUMED. If either of these ever appears, a
## signal can be wired without the text this tool searches for, and a green run would then mean
## nothing at all. Failing loudly is the only honest response to that.
func _check_preconditions() -> void:
	var scenes: Array[String] = []
	_collect_files(SCENE_ROOT, ".tscn", scenes)
	for path: String in scenes:
		if FileAccess.get_file_as_string(path).contains("[connection "):
			_fail("%s wires a signal in the scene file — this gate cannot see that" % path)
	var scripts: Array[String] = _all_scripts()
	for path: String in scripts:
		if path == REGISTRY:
			continue
		if FileAccess.get_file_as_string(path).contains("emit_signal("):
			_fail("%s calls emit_signal() by name — this gate cannot see that" % path)
	print("  preconditions: %d scenes and %d scripts checked" % [scenes.size(), scripts.size()])


func _all_scripts() -> Array[String]:
	var scripts: Array[String] = []
	for root: String in SCAN_ROOTS:
		_collect_files(root, ".gd", scripts)
	return scripts


## Every `signal <name>(` in the registry, mapped to the `##` block immediately above it, which
## is where the RESERVED phrase lives. The block is accumulated and cleared on any non-comment
## line, so a doc comment attaches to exactly the declaration it precedes.
func _read_registry() -> void:
	var file: FileAccess = FileAccess.open(REGISTRY, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % REGISTRY)
		return
	var block: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("##"):
			block += line
			continue
		if line.begins_with("signal "):
			_signals[line.substr(7).get_slice("(", 0).strip_edges()] = block
		block = ""
	file.close()
	print("  signals declared: %d" % _signals.size())


func _scan_all() -> void:
	for path: String in _all_scripts():
		if path == REGISTRY:
			continue
		_scan_script(path)


## ROLES ARE COUNTED PER LINE, not per file, so one file emitting and listening to the same
## signal is reported honestly instead of collapsing into one tally.
func _scan_script(path: String) -> void:
	var source: String = FileAccess.get_file_as_string(path)
	if not source.contains(BUS):
		return
	var indirect: int = _dispatch_role(source)
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		for name: String in _signals:
			var at: int = line.find(BUS + name)
			if at < 0:
				continue
			## The whole-word rule, for the reason check_boundary.gd learned at a cost: no
			## signal here is a prefix of another today, and a gate resting on that staying
			## true is a gate with a trap in it.
			var rest: String = line.substr(at + BUS.length() + name.length())
			if rest != "" and WORD_CHARS.contains(rest.substr(0, 1)):
				continue
			_tally(name, rest, indirect)


## What a single reference does, from the characters that FOLLOW it. `.emit` covers both
## `x.emit(...)` and the quest tracker's `x.emit.callv(args)`, which takes no parenthesis.
## Anything else is the first-class-Signal case and inherits the file's dispatch role.
func _tally(name: String, rest: String, indirect: int) -> void:
	if rest.begins_with(".emit"):
		_emitters[name] = _emitters.get(name, 0) + 1
	elif rest.begins_with(".connect") or rest.begins_with(".is_connected") \
			or rest.begins_with(".disconnect"):
		_listeners[name] = _listeners.get(name, 0) + 1
	elif indirect > 0:
		_emitters[name] = _emitters.get(name, 0) + 1
	elif indirect < 0:
		_listeners[name] = _listeners.get(name, 0) + 1


## THE METHOD TRAP, RESOLVED. A file that hands `Events.quest_started` to something is doing
## one of two things, and which one is visible in the same file: it either calls `.emit` on a
## `Signal`-typed identifier somewhere, or it calls `.connect` on one. Returns 1 for emit, -1
## for connect, 0 when the file does neither — in which case a bare reference is counted as
## nothing at all, which is the conservative direction: it can only ever cause a FAILURE to be
## reported, never a violation to be missed.
static func _dispatch_role(source: String) -> int:
	var names: Dictionary[String, bool] = {}
	for line: String in source.split("\n"):
		var at: int = line.find(": Signal")
		while at > 0:
			names[_identifier_before(line, at)] = true
			at = line.find(": Signal", at + 1)
	for identifier: String in names:
		if identifier == "" or not source.contains(identifier + "."):
			continue
		if source.contains(identifier + ".emit"):
			return 1
		if source.contains(identifier + ".connect"):
			return -1
	return 0


## The identifier immediately left of a `: Signal` annotation, walked backwards over word
## characters. Splitting on spaces is what the first version did and it was wrong on the case
## that matters: `func f(fact: Signal, ...)` has no space before `fact`, only a bracket, so the
## name came out as `f(fact` and the file's role read as none. The suite caught it.
static func _identifier_before(line: String, at: int) -> String:
	var start: int = at
	while start > 0 and WORD_CHARS.contains(line.substr(start - 1, 1)):
		start -= 1
	return line.substr(start, at - start)


## A SIGNAL WITH NO LISTENER IS REPORTED AND NOT FAILED, and the asymmetry is deliberate. The
## template declares facts a consuming game listens to — `player_state_changed`, `game_saved`
## and `equipment_changed` all say so in their own doc blocks — so a missing listener is the
## normal state of a template and failing on it would train everyone to add a dead listener.
## A missing EMITTER is different: nothing downstream can supply it, because the emit site is
## engine code, so the signal is inert in every game built on this base.
func _report() -> void:
	var quiet: Array[String] = []
	for name: String in _signals:
		var emits: int = _emitters.get(name, 0)
		var reserved: bool = _signals[name].contains(RESERVED)
		if emits == 0 and not reserved:
			_fail("%s is declared and never emitted (say '%s' in its ## block if that is "
				% [name, RESERVED] + "deliberate)")
		if emits > 0 and reserved:
			_fail("%s is marked '%s' and has %d — the exemption is stale"
				% [name, RESERVED, emits])
		if _listeners.get(name, 0) == 0:
			quiet.append(name)
	print("  emitters found: %d references over %d signals"
		% [_tally_total(_emitters), _emitters.size()])
	print("  no listener in this checkout (reported, not failed): %d — %s"
		% [quiet.size(), str(quiet)])


static func _tally_total(counts: Dictionary[String, int]) -> int:
	var total: int = 0
	for name: String in counts:
		total += counts[name]
	return total
