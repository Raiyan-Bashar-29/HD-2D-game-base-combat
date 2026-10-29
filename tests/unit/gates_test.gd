extends TestCase
## The three enforcement gates T5.4 added and the method gate T5.13 added, and the one
## structural question none of the four older gates asked: DOES A DECLARED THING HAVE A
## CONSUMER?
##
## WHY A CASE AT ALL, WHEN THE GATES ARE ALREADY IN THE LADDER. A checker that runs is not a
## checker that WORKS. Each of the three was proved red by planting a real violation and green
## by removing it, and both results are in DEVLOG.md — but a plant is a one-off, and the thing
## that rots afterwards is the CLASSIFIER: the four lines that decide whether a reference is an
## emit or a connect, whether a path is core or ui, whether a key names content. Those are
## static, pure, and take strings, so they are assertable here, at every run, forever. This is
## gotcha 42's lesson applied to the tools themselves: assert the mechanism, not the fact that
## the file exists.
##
## THE METHOD TRAP IS THE ASSERTION THAT MATTERS MOST. Three quest signals are dispatched
## INDIRECTLY, as first-class `Signal` values handed to a helper that calls `.emit` on them, so
## a naive scan for `quest_started.emit` finds zero sites and would report three false
## positives. Measured, at the time of writing: 0, 0 and 0 direct sites for `quest_started`,
## `quest_advanced` and `quest_completed`. The dispatch-role classifier is what tells them
## apart from a genuinely dead declaration, and it is asserted below in both directions.
##
## NO FIXTURE CONTENT IS ACTIVATED and no demo name appears: every string below is synthetic
## GDScript written for the assertion, which is what lets `check_boundary.gd` scan this file.
##
## THE FOURTH GATE, T5.13, ASKS THE SAME QUESTION OF A PUBLIC METHOD, and its classifiers are
## here for the same reason: what counts as a declaration, what counts as a reference, and the
## two kinds of line — prose and a declaration header — that must be thrown away before either
## is counted. Both of those last two were real defects in a draft of that tool.
##
## OWNS: the classifiers of all four consumer gates, and the fact that each tool own gate is
## wired into the ladder.
## MUST NOT: run a checker (they call quit(), which would end the suite), name demo content, or
## assert a violation COUNT — that is a property of today's tree, not a contract.

const LAYERS_TOOL = preload("res://tools/check_layers.gd")
const SIGNALS_TOOL = preload("res://tools/check_signals.gd")
const METHODS_TOOL = preload("res://tools/check_methods.gd")
const BOUNDARY_TOOL = preload("res://tools/check_boundary.gd")
const REGISTRY: String = "res://src/core/events/events.gd"
const WORKFLOW: String = "res://.github/workflows/ladder.yml"

## Every checker in the ladder, and the CI step that must run it. A gate nobody runs is a
## document, which is the state the layer rule was in until this package.
const LADDER: Array[String] = [
	"tools/check_budgets.gd", "tools/check_content.gd", "tools/check_boundary.gd",
	"tools/check_strings.gd", "tools/check_layers.gd", "tools/check_signals.gd",
	"tools/check_methods.gd",
]

## Where the checkers live, scanned so LADDER cannot silently fall behind the directory.
const TOOL_DIR: String = "res://tools"
## THE JOBS THE LADDER RUNS. A checker wired into the full job and not the stripped one is wired
## into half a ladder — and the stripped job is the half that proves the template stands up with
## no game present, so it is the half a template cannot afford to skip.
const JOBS: Array[String] = ["ladder", "stripped"]

## Where the method gate looks for its exemption phrase. Unlike the signal registry there is no
## one file to read, so the phrase is counted over the whole engine tree.
const METHOD_ROOT: String = "res://src"
## THE OPAQUE DISPATCH SAMPLE, IN TWO HALVES ON PURPOSE. The method gate's precondition fires
## on a LINE that both dispatches and builds a string, and this file writing the sample out
## whole would trip it — which it did, on the first run after these assertions were added. The
## gate was right and the test was the violation; splitting the sample is the honest fix,
## because a line that only quotes half of it is not a dispatch site.
const OPAQUE_HEAD: String = "\to.call("
const OPAQUE_TAIL: String = "\"fetch_\" + kind)"


func run() -> void:
	## COMPUTED rather than typed, for `record_shape_test.gd`'s reason: wiring an eighth checker
	## should not mean editing a number, and a number that has to be edited is a number that gets
	## edited to whatever the run reported.
	var on_disk: Array[String] = _checker_files()
	plan(42 + JOBS.size() + LADDER.size() * 2 + on_disk.size())
	_the_layer_of_a_path_comes_from_the_path()
	_an_indirect_signal_reference_is_read_from_its_files_dispatch()
	_a_whole_word_match_is_shared_by_both_gates()
	_a_reserved_signal_says_so_where_the_reader_is_looking()
	_a_declaration_is_read_from_the_line_it_is_on()
	_a_reference_is_a_whole_word_and_is_counted()
	_prose_and_declaration_headers_are_not_callers()
	_a_name_built_at_runtime_trips_the_precondition()
	_a_reserved_method_says_so_where_the_reader_is_looking()
	_every_checker_is_wired_into_the_ladder(on_disk)


## LAYER IS DERIVED, NEVER LISTED, which is what stops the gate going stale when a file moves.
## The index IS the ordering, so the whole rule reduces to one integer comparison.
func _the_layer_of_a_path_comes_from_the_path() -> void:
	var tool_script := LAYERS_TOOL
	equal("core is layer 0", tool_script.layer_of("res://src/core/log/log.gd"), 0)
	equal("content is layer 1", tool_script.layer_of("res://src/content/item/thing.gd"), 1)
	equal("systems is layer 2", tool_script.layer_of("res://src/systems/audio/a.gd"), 2)
	equal("gameplay is layer 3", tool_script.layer_of("res://src/gameplay/world/b.gd"), 3)
	equal("ui is layer 4", tool_script.layer_of("res://src/ui/hud/c.gd"), 4)
	equal("outside src/ is not a layer", tool_script.layer_of("res://tests/unit/d.gd"), -1)


## THE TRAP, ASSERTED IN BOTH DIRECTIONS. A file that calls `.emit` on a `Signal`-typed
## identifier is an emitter and its bare bus references are emit sites; a file that calls
## `.connect` on one is a listener. A file that does neither returns 0, and a bare reference in
## it is counted as nothing — the conservative direction, because it can only ever produce a
## reported failure, never a missed violation.
func _an_indirect_signal_reference_is_read_from_its_files_dispatch() -> void:
	var tool_script := SIGNALS_TOOL
	var emitter: String = "func f(fact: Signal, a: Array) -> void:\n\tfact.emit.callv(a)\n"
	var listener: String = "func g() -> void:\n\tfor fact: Signal in _f():\n\t\tfact.connect(h)\n"
	equal("a helper that emits a Signal parameter is an emitter",
		tool_script._dispatch_role(emitter), 1)
	equal("a loop that connects a Signal is a listener",
		tool_script._dispatch_role(listener), -1)
	equal("a file with no Signal-typed identifier has no role",
		tool_script._dispatch_role("func h() -> void:\n\tpass\n"), 0)
	equal("a Signal declared and never used has no role",
		tool_script._dispatch_role("func i(fact: Signal) -> void:\n\tpass\n"), 0)


## ONE DEFINITION OF "NAMES THIS IDENTIFIER" FOR BOTH GATES, so a fix to one is a fix to both.
## The substring version was a real defect: an item called `pear` failed on the word `appeared`.
func _a_whole_word_match_is_shared_by_both_gates() -> void:
	var boundary := BOUNDARY_TOOL
	var layers := LAYERS_TOOL
	equal("a bare identifier matches", boundary.names_whole_word("var x: Thing = null", "Thing"),
		true)
	equal("a longer word does not",
		boundary.names_whole_word("var x: ThingBase = null", "Thing"), false)
	equal("a prefixed word does not",
		boundary.names_whole_word("var x: SubThing = null", "Thing"), false)
	equal("the layer gate uses the same definition",
		layers.names_whole_word("var x: ThingBase = null", "Thing"), false)
	equal("and agrees on a real match",
		layers.names_whole_word("load(\"res://a/Thing.gd\")", "Thing"), true)


## THE ESCAPE HATCH IS A PHRASE IN THE DECLARATION'S OWN DOC BLOCK, not a list inside the tool,
## so the next reader of the signal sees the decision without opening anything. Two signals
## carry it today and both say WHY in the same breath; this asserts the mechanism is present
## and spelled the one way the gate reads, because a typo in it silently un-exempts a signal.
func _a_reserved_signal_says_so_where_the_reader_is_looking() -> void:
	var tool_script := SIGNALS_TOOL
	var phrase: String = tool_script.RESERVED
	var source: String = FileAccess.get_file_as_string(REGISTRY)
	equal("the phrase is not empty", phrase.is_empty(), false)
	equal("the registry loads", source.is_empty(), false)
	equal("the registry declares at least one reserved signal", source.contains(phrase), true)
	var reserved: int = source.split(phrase).size() - 1
	equal("and the phrase is uppercase, so prose cannot grant an exemption by accident",
		phrase, phrase.to_upper())
	equal("every use of it sits in a comment", _all_uses_are_comments(source, phrase), reserved)


func _all_uses_are_comments(source: String, phrase: String) -> int:
	var found: int = 0
	for line: String in source.split("\n"):
		if line.contains(phrase) and line.strip_edges().begins_with("#"):
			found += 1
	return found


## WHAT COUNTS AS A DECLARATION, which is the method gate's first classifier and the one that
## decides what it is even asked of. Column 0 only, `static` included, and the underscore rule
## is applied by the caller so the classifier itself stays a pure reading of the line.
func _a_declaration_is_read_from_the_line_it_is_on() -> void:
	var tool_script := METHODS_TOOL
	equal("a plain declaration", tool_script._declared_name("func alpha() -> void:"), "alpha")
	equal("a static one", tool_script._declared_name("static func beta(x: int) -> int:"), "beta")
	equal("a private one is still a declaration, and the caller drops it",
		tool_script._declared_name("func _gamma() -> void:"), "_gamma")
	equal("an indented line is not one — GDScript has no nested function",
		tool_script._declared_name("\tfunc delta() -> void:"), "")
	equal("and a variable is not one", tool_script._declared_name("var epsilon: int = 0"), "")


## A REFERENCE IS A WHOLE WORD, for check_boundary.gd's reason at its own cost: a substring
## match would let a method called `travel` be kept alive by an unrelated `travel_to`.
func _a_reference_is_a_whole_word_and_is_counted() -> void:
	var tool_script := METHODS_TOOL
	equal("a bare call counts", tool_script._hits("\tself.alpha()", "alpha"), 1)
	equal("a longer name does not", tool_script._hits("\tself.alphabet()", "alpha"), 0)
	equal("a suffixed name does not", tool_script._hits("\tself.my_alpha()", "alpha"), 0)
	equal("two sites count twice", tool_script._hits("\talpha()\n\tvar x := alpha", "alpha"), 2)


## THE TWO LINES A SCAN MUST THROW AWAY BEFORE IT COUNTS ANYTHING, and each was a real defect
## in an earlier draft of the tool. A method named in PROSE is not a caller — the word `duck`
## appeared exactly once outside its own declaration before T5.11, in a doc comment saying what
## `unduck` undid — and a PARAMETER named after a method is not a call to it either.
func _prose_and_declaration_headers_are_not_callers() -> void:
	var tool_script := METHODS_TOOL
	equal("a doc comment mentioning it is dropped",
		tool_script._hits(tool_script._code_of("## undo alpha() later\n\tpass"), "alpha"), 0)
	equal("the declaration header itself is dropped",
		tool_script._hits(tool_script._code_of("func alpha() -> void:\n\tpass"), "alpha"), 0)
	equal("but a call in the body survives",
		tool_script._hits(tool_script._code_of("func beta() -> void:\n\talpha()"), "alpha"), 1)


## THE PRECONDITION CLASSIFIER. A dispatch line that also BUILDS its name hides a method from
## this gate completely, so the tool fails on one rather than reporting a green it cannot back.
func _a_name_built_at_runtime_trips_the_precondition() -> void:
	var tool_script := METHODS_TOOL
	equal("a dispatch site is recognised",
		tool_script._has_any("\to.call(f)", tool_script.DISPATCH), true)
	equal("an ordinary call is not",
		tool_script._has_any("\to.alpha(f)", tool_script.DISPATCH), false)
	equal("and concatenation is what makes a dispatch site opaque",
		tool_script._has_any(OPAQUE_HEAD + OPAQUE_TAIL, tool_script.BUILDS_A_NAME), true)
	equal("while a line that only dispatches is not opaque",
		tool_script._has_any(OPAQUE_HEAD, tool_script.BUILDS_A_NAME), false)


## THE FOURTH ESCAPE HATCH, SPELLED THE SAME WAY AS THE SIGNAL GATE'S. There is no single
## registry to read here, so the phrase is counted over the whole engine tree; the assertion is
## that the mechanism is present, uppercase and only ever granted from a comment, because a
## phrase appearing in live code would exempt a method nobody meant to exempt.
func _a_reserved_method_says_so_where_the_reader_is_looking() -> void:
	var phrase: String = METHODS_TOOL.RESERVED
	equal("the phrase is not empty", phrase.is_empty(), false)
	equal("and is uppercase, so prose cannot grant an exemption by accident",
		phrase, phrase.to_upper())
	equal("it is not the signal gate's phrase, because they gate different things",
		phrase == SIGNALS_TOOL.RESERVED, false)
	var uses: int = 0
	var in_comments: int = 0
	for path: String in _engine_scripts(METHOD_ROOT):
		var source: String = FileAccess.get_file_as_string(path)
		for line: String in source.split("\n"):
			if not line.contains(phrase):
				continue
			uses += 1
			if line.strip_edges().begins_with("#"):
				in_comments += 1
	equal("at least one method carries it", uses > 0, true)
	equal("and every use of it sits in a comment", in_comments, uses)


func _engine_scripts(root: String) -> Array[String]:
	var found: Array[String] = []
	for sub: String in DirAccess.get_directories_at(root):
		found.append_array(_engine_scripts("%s/%s" % [root, sub]))
	for file_name: String in DirAccess.get_files_at(root):
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [root, file_name])
	return found

## SEVEN CHECKERS NOW, NOT FOUR, AND CI MUST NAME EACH ONE AS ITS OWN STEP so a failure says
## which gate failed rather than "the ladder". This is the assertion that would have caught a
## gate written, committed, and never wired — which is the defect the whole package is about,
## applied to the package itself.
## `workflow.contains(checker)` WAS TRUE OF A COMMENT, AND THIS FILE'S OWN HEADER ASKED FOR MORE
## THAN THAT — "as its own step", and there are two jobs. Three things it could not tell apart:
## a checker named only in a `#` comment, a checker wired into the full job and missing from the
## stripped one, and a checker wired twice into one job and not at all into the other. All three
## are a gate that does not run, which is the state this function exists to make red. So the
## count is of INVOCATIONS — a non-comment line naming the checker and `--script` — and it must
## equal the number of jobs. Same defect as T5.25's, one file over: the assertion was reading a
## string rather than the thing the string was standing for.
func _every_checker_is_wired_into_the_ladder(on_disk: Array[String]) -> void:
	var workflow: String = FileAccess.get_file_as_string(WORKFLOW)
	equal("the workflow loads", workflow.is_empty(), false)
	## The job names are asserted rather than assumed, because every count below is compared
	## against JOBS.size() and a silently renamed job would make that number a fiction.
	for job: String in JOBS:
		equal("the workflow declares the %s job" % job, workflow.contains("\n  %s:" % job), true)
	for checker: String in LADDER:
		equal("%s exists" % checker, FileAccess.file_exists("res://" + checker), true)
		equal("every job invokes %s, once each" % checker,
			_script_invocations(workflow, checker), JOBS.size())
	## THE LIST ITSELF WAS THE HOLE. LADDER named seven checkers and nothing said it named ALL of
	## them, so an eighth written and never wired was invisible to the case whose whole subject is
	## a gate nobody runs. `test_runner.gd` closed the identical hole for `CASES` at T2.2 by
	## scanning the directory; this is that pattern, and the reason is the same.
	for path: String in on_disk:
		equal("%s is listed in LADDER, so it is checked at all" % path, LADDER.has(path), true)


## A checker EXECUTES only where it is named beside `--script` on a line that is not a comment.
## Comments in this workflow do name the checkers — deliberately, they carry the reasoning — so
## reading past them is the whole point rather than an edge case.
func _script_invocations(workflow: String, checker: String) -> int:
	var count: int = 0
	for line: String in workflow.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or not trimmed.contains(checker):
			continue
		if trimmed.contains("--script"):
			count += 1
	return count


## Derived from the directory rather than listed, for `check_boundary.gd`'s reason: a list of
## what to check is a list that rots, and this one rotting is the defect above.
func _checker_files() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TOOL_DIR):
		if file_name.begins_with("check_") and file_name.ends_with(".gd"):
			found.append("tools/%s" % file_name)
	return found
