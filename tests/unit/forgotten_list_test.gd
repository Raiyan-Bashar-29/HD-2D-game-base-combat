extends TestCase
## THE "COMMONLY FORGOTTEN" LIST, CHECKED FOR A VERDICT ON EVERY ITEM.
##
## WHY A LIST OF REMINDERS GETS A GATE
## `SYSTEMS_INVENTORY.md` § "Commonly forgotten" was written at WP-00 so that fifteen things hobby
## projects regret would be DECISIONS rather than oversights. It did not stay that way by itself:
## T6.0 found three items still describing as missing work that T2.0 had built or the owner had
## closed, and a reader of the list could not tell a settled item from an open one. Phase T6 was
## planned as the list's closure, and its exit criterion is that every item carries a verdict with
## a package id beside it. Without a gate, a sixteenth item appended next year is an oversight
## again the moment it is written, which is the thing the list exists to prevent.
##
## WHAT A VERDICT IS, STRUCTURALLY
## An item is a line `N. **Title.**` and everything up to the next item. Its verdict is the bold
## marker `**DONE — <id>` or `**CLOSED (game's) — <id>`, where `<id>` has a package's SHAPE
## (`T6.3`, `WP-02`, `WP-09b`, `record_shape_test.gd`'s reasoning) and has a row on the board. A
## verdict naming a package that does not exist is a verdict nobody can follow, so the id is
## looked up rather than merely matched.
##
## THE PLAN IS COMPUTED from the items found, for `docs_test.gd`'s reason: adding an item should
## not mean editing a number. It is `2 + 2 × items`, and the first two are the ones that stop an
## empty scan passing - a renamed heading must fail, not find nothing and pass (gotcha 23's shape).
##
## OWNS: that every item on the forgotten list carries a DONE or CLOSED (game's) marker naming a
##   package the board records, and that the items are numbered without a gap.
## MUST NOT: assert what an item SAYS beyond its marker, or whether the verdict is right. A wrong
##   verdict is a review problem; a missing one is this file's.

const LIST_DOC: String = "res://docs/SYSTEMS_INVENTORY.md"
const BOARD: String = "res://docs/WORK_PACKAGES.md"
const SECTION_MARK: String = "## Commonly forgotten"
## Bracket classes rather than backslashes, so no pattern here depends on string escaping.
const ITEM_PATTERN: String = "^([0-9]+)[.] [*][*]"
## The id group is `record_shape_test.gd`'s HEADING_PATTERN id, so both agree on what a package is.
const VERDICT_PATTERN: String = "[*][*](DONE|CLOSED [(]game's[)]) — (T[0-9]+[.][0-9]+|WP-[0-9]+[a-z]?)(?![0-9a-z])"

## Each entry is [number, body]; the body is every line of the item joined.
var _items: Array[Array] = []


func run() -> void:
	_gather()
	plan(2 + _items.size() * 2)
	equal("the forgotten list has items to check", _items.size() > 0, true)
	equal("the forgotten list is numbered 1 to N without a gap", _numbered_in_order(), true)
	_every_item_carries_a_verdict()


## One marker per item, and its package must be findable on the board by the whole id -
## `record_shape_test._is_recorded_in`'s word boundary, so `T5.1` is not satisfied by `T5.10`.
func _every_item_carries_a_verdict() -> void:
	var board: String = FileAccess.get_file_as_string(BOARD)
	var verdict := RegEx.create_from_string(VERDICT_PATTERN)
	for item: Array in _items:
		var number: int = item[0]
		var hit: RegExMatch = verdict.search(item[1] as String)
		equal("forgotten #%d is marked DONE or CLOSED (game's) with a package id" % number,
				hit != null, true)
		var id: String = "" if hit == null else hit.get_string(2)
		var row := RegEx.create_from_string("(?<![0-9A-Za-z])" + id.replace(".", "[.]") + "(?![0-9a-z])")
		equal("forgotten #%d names %s, which has a row on the board" % [number, id],
				not id.is_empty() and row.search(board) != null, true)


func _numbered_in_order() -> bool:
	for index: int in _items.size():
		if (_items[index][0] as int) != index + 1:
			return false
	return true


## The section runs from its heading to the next `---` rule or `## ` heading.
func _gather() -> void:
	var item := RegEx.create_from_string(ITEM_PATTERN)
	var inside: bool = false
	for line: String in FileAccess.get_file_as_string(LIST_DOC).split("\n"):
		if line.begins_with(SECTION_MARK):
			inside = true
			continue
		if not inside:
			continue
		if line.begins_with("---") or line.begins_with("## "):
			break
		var hit: RegExMatch = item.search(line)
		if hit != null:
			_items.append([hit.get_string(1).to_int(), line])
		elif not _items.is_empty():
			_items[-1][1] = (_items[-1][1] as String) + " " + line.strip_edges()
