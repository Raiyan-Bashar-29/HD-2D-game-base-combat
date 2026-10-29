extends TestCase
## THE SHAPE OF THE RECORD, CHECKED AGAINST THE RECORD.
##
## WHY THIS IS NOT `docs_test.gd` OR `doc_counts_test.gd`
## Three gates now watch the documents and each owns one kind of fact, because each has a
## different countable thing behind it. `docs_test.gd` owns what a document claims EXISTS - a
## `res://` path, a field in a worked example - and its MUST NOT line forbids asserting anything
## about what the prose SAYS. `doc_counts_test.gd` owns ONE number, the gotcha list's length, and
## its MUST NOT line forbids growing a second. Neither can hold what is here, and widening either
## would break a boundary a package wrote down on purpose. So this is a third case.
##
## WHAT IS HERE IS STRUCTURE, WHICH IS THE PART OF A DOCUMENT THAT IS NOT PROSE AT ALL.
## A file either opens with its own title or it does not. A package either has a row on the board
## or it does not. Neither question has a reading, an interpretation or a tone - which is exactly
## why they are assertable when the sentences around them are not.
##
## WHAT WENT WRONG WITHOUT IT
## T5.15 appended its `Row styles` row to `SYSTEMS_INVENTORY.md` at LINE 1, above the document's
## own `# Systems Inventory` heading. The row was the only copy, so the system it described was
## missing from the table it belonged in AND the file rendered with a stray table fragment before
## its title, and both survived three packages and a green ladder. T5.17 then shipped with no row
## on the board at all - the board's own closing checklist item 6 says "This file marks the
## package DONE with its commit" - and that survived too, because nothing counts the rows.
##
## T5.17 CONCLUDED "NOTHING GATES A PROSE CLAIM, AND NOTHING CAN", AND THAT IS RIGHT ABOUT PROSE.
## It is not right about a heading or a row, and the distinction is the whole justification for
## this file: five of that package's six defects were sentences and would defeat any tool, and
## the sixth was a count, which `doc_counts_test.gd` already gates. Structure is the third kind.
##
## THE PLAN IS COMPUTED from what the scan found, for `docs_test.gd`'s reason: adding a document
## or a package should not mean editing a number.
##
## OWNS: that every document opens with its own title, and that every package the log records is
##   findable in BOTH the board and the roadmap.
## MUST NOT: assert the wording of any prose, the ORDER of anything, or what a row SAYS. A row
##   that exists and is wrong is a review problem; a row that does not exist is this one.
##   Nor may it require a package to be recorded in any PARTICULAR shape — a row, a tick beside a
##   criterion and a parenthesis in a Done list are all recording; see the roadmap check.

const DOC_DIR: String = "res://docs"
const EXTRA_DOCS: Array[String] = ["res://CLAUDE.md"]
const BOARD: String = "res://docs/WORK_PACKAGES.md"
const ROADMAP: String = "res://docs/ROADMAP.md"
const LOG: String = "res://docs/DEVLOG.md"

## A log heading is `## <date> — <id> · <title>`. Only a WELL-FORMED package id is a package:
## `T5.17` and `WP-09b` are rows on the board, while `Audit`, `Phase` and `Work` open entries
## that are narrative and were never packages. Matching the id's SHAPE rather than listing the
## exceptions is what keeps this from becoming a list that rots - the same reasoning
## `check_boundary.gd` uses to derive its namespaces instead of naming them.
const HEADING_PATTERN: String = "^## [0-9-]{10} — (T[0-9]+[.][0-9]+|WP-[0-9]+[a-z]?)"

var _docs: Array[String] = []
var _packages: Array[String] = []


func run() -> void:
	_gather()
	plan(_docs.size() + _packages.size() * 2 + 2)
	equal("docs/ carries documents to check", _docs.size() > 0, true)
	equal("the log records packages to check", _packages.size() > 0, true)
	_every_document_opens_with_its_title()
	_every_recorded_package_has_a_board_row()
	_every_recorded_package_is_findable_in_the_roadmap()


## A markdown file whose first content is not its heading has had something appended to the wrong
## end, and the appended thing is then invisible in every reader that renders a title.
func _every_document_opens_with_its_title() -> void:
	for path: String in _docs:
		var opens: bool = _first_content_line(path).begins_with("# ")
		equal("%s opens with its title" % path.get_file(), opens, true)


## The board is the index of what this project did. A package with no row on it is work that
## happened and cannot be found from the one file `CLAUDE.md` sends a reader to.
func _every_recorded_package_has_a_board_row() -> void:
	var board: String = FileAccess.get_file_as_string(BOARD)
	for id: String in _packages:
		equal("%s has a row on the board" % id, _is_recorded_in(board, id), true)



## The roadmap is where a package's PLACE in the plan is recorded and the board is where its WORK
## is. A package findable on neither is work whose reason cannot be reconstructed; a package
## findable on the board alone is a thing that was built with no trace of what it was for.
##
## FINDABLE, not "has a package-log row" — deliberately, and it is the choice T5.19 made for the
## board one function above. The roadmap records a package in whichever of three shapes fits: a
## package-log row under a phase, a tick beside an exit criterion — T5.14 is only ever the latter
## — or a parenthesis in a phase's Done list, which is WP-02 and WP-04. A stricter rule would fail
## packages that are genuinely recorded, and "recorded in the file a reader is sent to" is the
## property that matters.
##
## T5.16 DECLINED TO TOUCH THE ROADMAP AND GAVE A REASON, AND THE REASON WAS ABOUT CRITERIA:
## "no exit criterion covers a defect fix, and inventing one to have something to tick would be
## the ticking-without-proving this project spent T5.1 undoing". That is right about the criteria
## list and says nothing about the package log, which is a different list in the same file
## answering a different question. Separating the two is what makes this assertable rather than a
## matter of editorial taste.
func _every_recorded_package_is_findable_in_the_roadmap() -> void:
	var roadmap: String = FileAccess.get_file_as_string(ROADMAP)
	for id: String in _packages:
		equal("%s is findable in the roadmap" % id, _is_recorded_in(roadmap, id), true)


## FINDABLE MEANS THE ID ITSELF, NOT A PREFIX OF A LONGER ONE, AND `contains()` COULD NOT TELL
## THE DIFFERENCE - WHICH MADE FOUR OF THE ASSERTIONS ABOVE UNFALSIFIABLE.
## `"T5.1"` is a substring of `T5.10` through `T5.19`, `"T5.2"` of `T5.20` through `T5.24`,
## `"WP-09"` of `WP-09b` and `"WP-14"` of `WP-14b`. For those four, deleting every genuine trace
## of the package from either file left BOTH assertions green, because a sibling's own row spells
## the prefix. The gate T5.24 wrote to stop a package going missing could not see the four
## packages most likely to go missing quietly.
##
## A word boundary is the entire fix, and it is exact rather than approximate: `\bWP-09\b` does
## not match `WP-09b` because digit-to-letter is not a boundary, and `\bT5\.1\b` does not match
## `T5.10` for the same reason. The dot is escaped because an unescaped one matches any character,
## which would let `T5x1` satisfy `T5.1` - the mirror of the defect being fixed.
##
## MEASURED BEFORE IT WAS WRITTEN: all 52 recorded packages satisfy the word-boundary form in
## both files, so this tightens the check without demanding a single new row. That is also why
## the live repository is NOT the plant here, unlike T5.24 - it is green either way, so the proof
## has to be a deletion. See this row's DEVLOG entry for the three runs.
func _is_recorded_in(text: String, id: String) -> bool:
	var matcher := RegEx.create_from_string("\\b" + id.replace(".", "\\.") + "\\b")
	return matcher.search(text) != null


func _gather() -> void:
	_docs = _doc_files()
	var matcher := RegEx.create_from_string(HEADING_PATTERN)
	for line: String in FileAccess.get_file_as_string(LOG).split("\n"):
		var hit: RegExMatch = matcher.search(line)
		if hit == null:
			continue
		var id: String = hit.get_string(1)
		if not _packages.has(id):
			_packages.append(id)


## Blank lines before a heading render as nothing, so they are skipped rather than failed.
func _first_content_line(path: String) -> String:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().is_empty():
			return line
	return ""


func _doc_files() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(DOC_DIR):
		if file_name.ends_with(".md"):
			found.append("%s/%s" % [DOC_DIR, file_name])
	found.append_array(EXTRA_DOCS)
	return found
