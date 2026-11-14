class_name MugenIni
extends RefCounted
## Reads a M.U.G.E.N text file (`.def`, `.cns`, `.cmd`) into its sections (C9.9a).
##
## IN PLAIN WORDS: these files are lists of `[Section]` headers with `key = value` lines under
## them, and `;` starts a comment. A key may repeat (`trigger1` twice means both must hold), so
## a section keeps its lines as pairs, in order, and never as a dictionary.
##
## A section is `{"name": the header in lower case, "pairs": [[key, value], ...]}`. Keys are
## lower case with no spaces; values keep their case, because a command name is text.
##
## OWNS: turning one file's text into sections, and reading a key out of one.
## MUST NOT: know what any section means. `MugenMoves` does.


## Every section of the file at `path`, in order. An unreadable file gives none.
static func read(path: String) -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	return parse(file.get_buffer(file.get_length()).get_string_from_utf8())


## Every section in `text`, in order.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pairs: Array = []
	for raw: String in text.split("\n"):
		var line: String = _without_comment(raw).strip_edges()
		if line == "":
			continue
		if line.begins_with("["):
			pairs = []
			out.append({"name": line.trim_prefix("[").get_slice("]", 0).strip_edges().to_lower(),
				"pairs": pairs})
			continue
		var cut: int = line.find("=")
		if cut < 0 or out.is_empty():
			continue
		pairs.append([line.substr(0, cut).replace(" ", "").replace("\t", "").to_lower(),
			line.substr(cut + 1).strip_edges()])
	return out


## The first value of `key` in `section`, or `fallback`.
static func value(section: Dictionary, key: String, fallback: String = "") -> String:
	for pair: Array in _pairs(section):
		if pair[0] == key:
			return str(pair[1])
	return fallback


## The first number in the value of `key` (`"15, 3"` gives 15), or `fallback`.
static func number(section: Dictionary, key: String, fallback: float = 0.0) -> float:
	return first_number(value(section, key), fallback)


## The first number in `text`, or `fallback` when it does not start with one.
static func first_number(text: String, fallback: float = 0.0) -> float:
	var head: String = text.get_slice(",", 0).strip_edges()
	return head.to_float() if head.is_valid_float() else fallback


## The numbers of a comma list (`"-3, 0"` gives [-3, 0]); a part that is no number is 0.
static func numbers(text: String) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for part: String in text.split(","):
		out.append(part.strip_edges().to_float())
	return out


## Every value whose key starts with `prefix`, as [key, value] pairs in file order.
static func starting(section: Dictionary, prefix: String) -> Array:
	var out: Array = []
	for pair: Array in _pairs(section):
		if str(pair[0]).begins_with(prefix):
			out.append(pair)
	return out


static func _pairs(section: Dictionary) -> Array:
	var held: Variant = section.get("pairs", [])
	return held if held is Array else []


# The line up to its first `;` that is not inside double quotes.
static func _without_comment(line: String) -> String:
	var quoted: bool = false
	for i: int in line.length():
		var c: String = line[i]
		if c == "\"":
			quoted = not quoted
		elif c == ";" and not quoted:
			return line.substr(0, i)
	return line
