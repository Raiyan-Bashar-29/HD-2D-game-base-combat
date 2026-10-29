extends SceneTree
## Generates the PSEUDOLOCALE column of localization/strings.csv, so the template ships a second
## language without pretending to ship a translation.
##
## WHY A GENERATED LANGUAGE AND NOT A REAL ONE
## Phase 2's last criterion is "switch language at runtime and see every visible string change",
## and it was unmet for a reason no amount of wiring would have fixed: the CSV had ONE locale
## column, so there was nothing to switch to. A real second language is 218 rows of translation
## the template has no business inventing and a consuming game will replace anyway. A generated
## one proves the mechanism, and it is the same argument that generates placeholder ART rather
## than shipping art: the stand-in exists so the SYSTEM can be verified before the content is.
##
## WHAT IT IS FOR, once the mechanism is proved. A pseudolocale is the standard way to catch two
## bugs that a single-language build cannot show. A string that appears UNBRACKETED on screen is
## hard-coded and never went through the CSV - which is the same defect `check_strings.gd` hunts
## statically, caught visually and including anything computed. And the padding makes every label
## longer than its English, so a layout that only just fits in English fails HERE rather than in
## the first translated build.
##
## en_XA is the ICU/Android convention for "English, pseudo-region". Measured under 4.7.2:
## `TranslationServer.set_locale` accepts it verbatim and does not normalise it away, which was
## worth checking because a code the engine rewrote to "en" would have made the second column
## unreachable while looking correct in the file.
##
## FORMAT PLACEHOLDERS ARE LEFT ALONE. `%s`, `%d` and `%02d` are wrapped, never rewritten, or the
## HUD clock would draw its own format string.
##
## RUN:  godot_console --headless --script tools/gen_pseudolocale.gd
## OUT:  localization/strings.csv, rewritten in place with the en_XA column filled
##
## OWNS: the pseudolocale column and nothing else in that file.
## MUST NOT: invent, reorder or remove a KEY, or touch the English column. It reads the source
##   column and writes one derived column; a tool that could edit English would be a translator.

const CSV: String = "res://localization/strings.csv"
const KEY_COLUMN: String = "keys"
const SOURCE_LOCALE: String = "en"
const PSEUDO_LOCALE: String = "en_XA"

## Long enough that a label which only just fits in English overflows, short enough to stay
## readable in a screenshot. Real translations run 30-40% longer than English.
const PAD: String = "~~"


func _init() -> void:
	var rows: Array[PackedStringArray] = _read()
	if rows.is_empty():
		push_error("gen_pseudolocale: %s is empty or unreadable" % CSV)
		quit(1)
		return
	var header: PackedStringArray = rows[0]
	var source: int = header.find(SOURCE_LOCALE)
	if header.is_empty() or header[0] != KEY_COLUMN or source < 0:
		push_error("gen_pseudolocale: header must start '%s' and contain '%s', got: %s" % [
			KEY_COLUMN, SOURCE_LOCALE, ", ".join(header),
		])
		quit(1)
		return
	var target: int = header.find(PSEUDO_LOCALE)
	if target < 0:
		target = header.size()
	_write(rows, source, target)
	quit()


func _read() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0] == ""):
			continue
		out.append(row)
	file.close()
	return out


## Rewritten whole rather than appended to, because `store_csv_line` is what knows how to quote a
## value containing a comma - and an unquoted comma in this file is the defect `check_content.gd`
## exists to catch. Writing it by hand is how that bug would come back.
func _write(rows: Array[PackedStringArray], source: int, target: int) -> void:
	var file: FileAccess = FileAccess.open(CSV, FileAccess.WRITE)
	if file == null:
		push_error("gen_pseudolocale: cannot write %s" % CSV)
		quit(1)
		return
	var filled: int = 0
	for at: int in rows.size():
		var row: PackedStringArray = rows[at]
		while row.size() <= target:
			row.append("")
		if at == 0:
			row[target] = PSEUDO_LOCALE
		else:
			row[target] = _pseudo(row[source] if source < row.size() else "")
			if row[target] != "":
				filled += 1
		file.store_csv_line(row)
	file.close()
	print("gen_pseudolocale: %d row(s), %s column at index %d, %d value(s) filled" % [
		rows.size() - 1, PSEUDO_LOCALE, target, filled,
	])


## Bracketed so an unbracketed string on screen is visibly not from the table, and padded so it
## is longer than the English. An empty source stays empty: a key with no English text has
## nothing to pseudo-translate, and inventing text for it would hide that it is unwritten.
func _pseudo(english: String) -> String:
	if english == "":
		return ""
	return "[%s%s%s]" % [PAD, english, PAD]
