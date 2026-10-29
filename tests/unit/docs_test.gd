extends TestCase
## The docs, checked against the engine they describe.
##
## WHY PROSE GETS A GATE AT ALL
## Most of a documentation package is not assertable, and pretending otherwise produces a test
## that restates the prose. But two things in a consumer document ARE facts about this repository
## and both rot silently: a `res://` path that no longer exists, and a field name in a worked
## example that was renamed. Neither is caught by anything else — a reader finds them, once, by
## following the document into a dead end and concluding the template is broken.
##
## WHAT IT CHECKS
## 1. Every `res://` path named anywhere in docs/ or CLAUDE.md resolves to a real file or folder.
## 2. Every property named in a documented .tres or .tscn block exists on the class that block
##    says the resource is scripted by. The blocks declare their own `[ext_resource type="Script"]`
##    lines, so the mapping from `script = ExtResource("1_def")` to a class comes out of the
##    document itself rather than out of a list here that would rot in turn.
##
## DEMO PATHS ARE SKIPPED, NOT ASSERTED. `docs/` teaches by example and naming
## `data/items/<something>.tres` is the point — but a stripped template has deleted exactly those,
## so a path under a content root is skipped and counted rather than failed. Everything under
## src/, scenes/objects/, scenes/characters/, tools/, tests/, assets/ and localization/ is engine
## and is asserted unconditionally.
##
## ONE DOCUMENT IS EXEMPT, AND IT IS THE HISTORY. `DEVLOG.md` records what was done, which
## includes files deliberately created and then removed — a temporary probe added under
## tests/unit/ to prove the runner fails on a crash, quoted by name and then deleted, is a true
## entry about a path that correctly no longer exists. It was the FIRST failure this case
## produced, which is a fair demonstration that the check works and an unfair demand that a log
## be rewritten whenever a file is removed. Everything a reader is meant to FOLLOW is scanned.
##
## THE PLAN IS COMPUTED from what the scan found, for the reason transitions_test.gd computes
## its own: adding a paragraph should not mean editing a number.
##
## OWNS: assertions about what the documents claim exists.
## MUST NOT: assert anything about what the documents SAY. Prose is reviewed, not tested.

const DOC_DIR: String = "res://docs"
const EXTRA_DOCS: Array[String] = ["res://CLAUDE.md"]
## The history, exempt for the reason in the header.
const HISTORY: String = "DEVLOG.md"
## Content roots a consuming game deletes on day one. A path under one of these is example
## content, so it is skipped when absent rather than failed.
const DEMO_ROOTS: Array[String] = ["res://data/", "res://scenes/areas/"]
const PATH_PATTERN: String = "res://[A-Za-z0-9_./-]*"

var _paths: Array[Array] = []
var _fields: Array[Array] = []
var _cache: Dictionary[String, Dictionary] = {}


func run() -> void:
	_gather()
	plan(_paths.size() + _fields.size() + 2)
	equal("the docs name res:// paths to check", _paths.size() > 0, true)
	equal("the docs carry worked examples to check", _fields.size() > 0, true)
	_every_documented_path_resolves()
	_every_documented_field_exists()


## A path in a document is a promise, and the only one a reader cannot verify without following
## it. Trailing "/" is a folder — several documents name a directory rather than a file.
func _every_documented_path_resolves() -> void:
	for entry: Array in _paths:
		var path: String = entry[0]
		var where: String = entry[1]
		if _is_demo(path) and not _resolves(path):
			skip("%s names %s" % [where, path], "content root, absent in a stripped template")
			continue
		equal("%s names %s, which exists" % [where, path], _resolves(path), true)


func _resolves(path: String) -> bool:
	if path.ends_with("/"):
		return DirAccess.dir_exists_absolute(path)
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _is_demo(path: String) -> bool:
	for root: String in DEMO_ROOTS:
		if path.begins_with(root):
			return true
	return false


## The rot this exists for: a worked example that still parses as text and names a field the
## engine no longer has. An author copies it, the engine ignores the line, and nothing errors.
func _every_documented_field_exists() -> void:
	for entry: Array in _fields:
		var script_path: String = entry[0]
		var field: String = entry[1]
		var where: String = entry[2]
		equal("%s documents %s.%s" % [where, script_path.get_file(), field],
			_properties_of(script_path).has(field), true)


func _properties_of(script_path: String) -> Dictionary:
	if _cache.has(script_path):
		return _cache[script_path]
	var found: Dictionary[String, bool] = {}
	var script: GDScript = load(script_path) as GDScript
	if script != null:
		for property: Dictionary in script.get_script_property_list():
			found[DictRead.get_string(property, "name")] = true
	_cache[script_path] = found
	return found


func _gather() -> void:
	var seen: Dictionary[String, bool] = {}
	for path: String in _doc_files():
		var text: String = FileAccess.get_file_as_string(path)
		_gather_paths(text, path.get_file(), seen)
		_gather_fields(text, path.get_file())


func _doc_files() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(DOC_DIR):
		if file_name.ends_with(".md") and file_name != HISTORY:
			found.append("%s/%s" % [DOC_DIR, file_name])
	found.append_array(EXTRA_DOCS)
	return found


## Deduplicated across the whole doc set: the same path named in four documents is one fact, and
## four identical assertions would only make the count harder to read.
func _gather_paths(text: String, where: String, seen: Dictionary[String, bool]) -> void:
	var expression: RegEx = RegEx.create_from_string(PATH_PATTERN)
	for found: RegExMatch in expression.search_all(text):
		var path: String = found.get_string().trim_suffix(".")
		if path == "res://" or seen.has(path):
			continue
		seen[path] = true
		_paths.append([path, where])


## Walks the fenced blocks. A block declares its own script ext_resources, so a `[resource]` or
## `[node]` section that names one identifies the class its following property lines belong to.
## A section with no `script =` line yields nothing: an instance placement overrides a prefab
## whose script this document never names, and guessing would invent coverage.
func _gather_fields(text: String, where: String) -> void:
	var scripts: Dictionary[String, String] = {}
	var current: String = ""
	var inside: bool = false
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("```"):
			inside = not inside
			scripts.clear()
			current = ""
		elif inside:
			current = _read_block_line(line, scripts, current, where)


func _read_block_line(
	line: String,
	scripts: Dictionary[String, String],
	current: String,
	where: String,
) -> String:
	if line.begins_with("[ext_resource") and line.contains("type=\"Script\""):
		scripts[_quoted_after(line, "id=\"")] = _quoted_after(line, "path=\"")
		return current
	if line.begins_with("["):
		return ""
	if line.begins_with("script = ExtResource("):
		var id: String = _quoted_after(line, "ExtResource(\"")
		return scripts[id] if scripts.has(id) else ""
	if current != "":
		_note_field(line, current, where)
	return current


func _note_field(line: String, script_path: String, where: String) -> void:
	var at: int = line.find(" = ")
	if at <= 0:
		return
	var field: String = line.substr(0, at)
	if not field.is_valid_identifier():
		return
	_fields.append([script_path, field, where])


func _quoted_after(line: String, marker: String) -> String:
	var at: int = line.find(marker)
	if at < 0:
		return ""
	var rest: String = line.substr(at + marker.length())
	var end: int = rest.find("\"")
	return rest.substr(0, end) if end > 0 else ""
