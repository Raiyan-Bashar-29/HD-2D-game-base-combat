extends TestCase
## A NUMBER FOUR DOCUMENTS RESTATE ABOUT THIS REPOSITORY, CHECKED AGAINST THE THING COUNTED.
##
## WHY THIS IS NOT `docs_test.gd`
## That file's MUST NOT line forbids asserting anything about what the documents SAY, and it is
## right to: prose is reviewed, not tested. A COUNT is the exception that proves that rule rather
## than an argument to widen it - `CONTEXT.md`'s gotcha list has a length, that length is a fact
## about this repository in exactly the way a `res://` path is, and four documents quote it. So
## this is a second case with its own boundary, not a third check inside that one.
##
## WHAT WENT WRONG WITHOUT IT
## Performing `docs/TESTING.md` at T4.4 found `CLAUDE.md` saying forty-four in two places,
## `CONTEXT.md` saying forty-eight and `TESTING.md` saying forty-three - three different answers
## to a countable question, over a list that had forty-eight entries. Each was true when written
## and none was updated. This is gotcha 48's shape without gotcha 48's excuse: that one would
## have needed a list of which key prefixes are engine, which is the same rot moved sideways, and
## was refused in writing. This one needs no list at all - it counts the entries and spells the
## number.
##
## A HISTORICAL COUNT IS WRITTEN IN DIGITS, AND THAT IS THIS GATE'S ONE DEMAND ON PROSE. A line
## saying a document "used to say 44" is not a claim about the list's length, but nothing in the
## text distinguishes it from one that is - so the convention is that a SPELLED tens-number on a
## line mentioning gotchas is a claim and a digit is a record. Both `CONTEXT.md` and `ROADMAP.md`
## failed this case the first time it ran, on their own account of the drift it exists to catch.
##
## OWNS: the agreement between the gotcha list's length and every document that states it.
## MUST NOT: assert anything else about the prose, or grow a second unrelated number. A count
##   with no countable thing behind it belongs in review, not here.

const DOC_DIR: String = "res://docs"
const EXTRA_DOCS: Array[String] = ["res://CLAUDE.md"]
## The history is exempt for `docs_test.gd`'s reason: it records what WAS true.
const HISTORY: String = "DEVLOG.md"
const SECTION_MARK: String = "gotchas that each cost an hour"
const LIST_DOC: String = "res://docs/CONTEXT.md"
const ENTRY_PATTERN: String = "^([0-9]+)[.] "

const UNITS: Array[String] = [
	"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
	"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
	"eighteen", "nineteen",
]
## Index 0 and 1 are unused: below twenty the word comes from UNITS.
const TENS: Array[String] = [
	"", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
]

## [document, the number word found on a line that mentions gotchas].
var _claims: Array[Array] = []
var _entries: Array[int] = []


func run() -> void:
	_gather()
	plan(_claims.size() + 2)
	equal("CONTEXT.md carries a numbered gotcha list", _entries.size() > 0, true)
	_the_list_is_numbered_without_a_gap()
	_every_document_spells_the_same_count()


## A repeat or a skip would make the count ambiguous, so the length and the last number must
## agree before either is quoted at anything.
func _the_list_is_numbered_without_a_gap() -> void:
	var highest: int = 0
	for number: int in _entries:
		if number > highest:
			highest = number
	equal("the gotcha numbers run 1 to N with no gap and no repeat", _entries.size(), highest)


## Every line in every document that mentions a gotcha and spells a tens-number must spell THIS
## one. Only tens-words are looked for, so "gotcha 22's family, one level up" is not mistaken for
## a count - and the project will not run out of them before ninety-nine.
func _every_document_spells_the_same_count() -> void:
	var expected: String = _spelled(_entries.size())
	for claim: Array in _claims:
		equal("%s spells the gotcha count" % claim[0], claim[1], expected)


func _gather() -> void:
	_entries = _numbered_entries(FileAccess.get_file_as_string(LIST_DOC))
	for path: String in _doc_files():
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in _lines_outside_the_list(text):
			if not line.to_lower().contains("gotcha"):
				continue
			var word: String = _number_word_on(line.to_lower())
			if word != "":
				_claims.append([path.get_file(), word])


## THE CLAIMS LIVE OUTSIDE THE LIST, AND SO MUST THE SCAN. The gotcha entries are prose about the
## engine, and several spell a number for their own reasons - gotcha 35 says a staging wait
## requires "twenty CONSECUTIVE settled frames", which read as a claim about the list's length
## and failed this case the first time it ran. A heading, a router table or a `Read next` line is
## where a count is actually quoted, and none of those is inside the list.
func _lines_outside_the_list(text: String) -> Array[String]:
	var kept: Array[String] = []
	var inside: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("## "):
			inside = line.contains(SECTION_MARK)
			# The heading is itself the primary statement of the count, and it is never an
			# entry, so it is kept as a claim rather than swallowed by the section it opens.
			# Leaving it out would let this gate pass while the list's own title was wrong.
			kept.append(line)
			continue
		if not inside:
			kept.append(line)
	return kept


## The entry numbers inside the gotcha section only. `CONTEXT.md` has other numbered lists -
## "Known defects" is one - so the scan starts at the section heading and stops at the next.
func _numbered_entries(text: String) -> Array[int]:
	var found: Array[int] = []
	var matcher := RegEx.create_from_string(ENTRY_PATTERN)
	var inside: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("## "):
			inside = line.contains(SECTION_MARK)
			continue
		if not inside:
			continue
		var hit: RegExMatch = matcher.search(line)
		if hit != null:
			found.append(hit.get_string(1).to_int())
	return found


## Longest match first, so "forty" inside "forty-nine" is not read as a different number.
func _number_word_on(line: String) -> String:
	for tens: int in range(2, TENS.size()):
		if not line.contains(TENS[tens]):
			continue
		for unit: int in range(1, 10):
			var compound: String = "%s-%s" % [TENS[tens], UNITS[unit]]
			if line.contains(compound):
				return compound
		return TENS[tens]
	return ""


func _spelled(number: int) -> String:
	if number < UNITS.size():
		return UNITS[number]
	if number % 10 == 0:
		return TENS[number / 10]
	return "%s-%s" % [TENS[number / 10], UNITS[number % 10]]


func _doc_files() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(DOC_DIR):
		if file_name.ends_with(".md") and file_name != HISTORY:
			found.append("%s/%s" % [DOC_DIR, file_name])
	found.append_array(EXTRA_DOCS)
	return found
