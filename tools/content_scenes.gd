class_name ContentSceneChecks
extends RefCounted
## The half of tools/check_content.gd that reads SCENE FILES as text: duplicate object ids,
## localization keys that will render on screen as their own name, and the missing [editable]
## marker that silently drops an override in an exported build.
##
## WHY IT IS A SEPARATE FILE, AND WHY THE SEAM IS HERE
## check_content.gd stood at 237 of the 250 allowed code lines, and validating quests did not
## fit. The seam was already in the reasoning rather than invented to make a number pass: the
## checks left behind ask the REGISTRIES what they loaded, so they load content classes, need
## ADR-0006's scan and go stale the moment a content root moves. These ones open .tscn files and
## read text, so they need no class registered and keep working on a scene that is broken for an
## unrelated reason. FIFTH time the budget checker has exposed a split that was already there,
## after check_boundary.gd and the three-way split of the debug surface.
##
## NOT A SECOND TOOL, DELIBERATELY. It is a RefCounted the one --script entry point instantiates,
## so the ladder still has one content command and CI still has one rung. A second SceneTree tool
## would be a second thing to forget to run.
##
## FAILURES ARE COLLECTED, NEVER PRINTED. The caller owns the exit code and the output format, on
## the same reasoning that makes every content class RETURN its problems.
##
## MUST NOT: load a content class, instantiate a scene, reference an autoload, or print. If it
## needed any of those it belongs on the other side of the seam.

const SCENE_DIRS: Array[String] = ["res://scenes"]

## Everything wrong, in the order found. The caller counts them.
var failures: PackedStringArray = PackedStringArray()
## How many .tscn files were opened, so the caller can report that the scan saw anything at all.
var scanned: int = 0

var _keys: Dictionary[String, bool] = {}


## `keys` is the parsed CSV, owned by the caller: a scene check that re-read the file would be a
## second parser for the unquoted-comma rule, which is exactly the duplication that shipped a
## half-sentence for three packages.
func run(keys: Dictionary[String, bool]) -> void:
	_keys = keys
	var scenes: Array[String] = []
	for directory: String in SCENE_DIRS:
		_collect_files(directory, ".tscn", scenes)
	scanned = scenes.size()
	for path: String in scenes:
		_check_scene(path)
		_check_editable_instances(path)


func _fail(message: String) -> void:
	failures.append(message)


func _collect_files(directory: String, extension: String, into: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_files("%s/%s" % [directory, sub], extension, into)
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(extension):
			into.append("%s/%s" % [directory, file_name])


## Text-scanned rather than instantiated: it needs no scene tree, it is fast, and it still
## works when a scene is broken for an unrelated reason.
##
## KNOWN LIMIT: duplicates are detected per FILE. Two objects in different scenes that end up
## under one AreaRoot at runtime are not caught, and neither is the same sub-scene instanced
## twice without overriding object_id - though that second case shows up as a missing override,
## which is why an instance line with no object_id is also reported.
func _check_scene(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % path)
		return
	var seen: Dictionary[String, bool] = {}
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		var object_id: String = _quoted_after(line, "object_id = &\"")
		if object_id != "":
			if seen.has(object_id):
				_fail("%s:%d duplicate object_id '%s' in one scene" % [path, line_number, object_id])
			seen[object_id] = true
		_check_key_literal(path, line_number, line)
	file.close()


## Every property whose name ends in _key must name a real CSV row. tr() on a missing key
## silently returns the key itself, so this is the only thing that catches a typo before a
## player sees "object.chest.courtyard.label" printed on screen.
func _check_key_literal(path: String, line_number: int, line: String) -> void:
	var trimmed: String = line.strip_edges()
	if not trimmed.contains("_key = \""):
		return
	var value: String = _quoted_after(trimmed, "_key = \"")
	if value == "" or _keys.has(value):
		return
	_fail("%s:%d localization key '%s' is not in the CSV" % [path, line_number, value])


func _quoted_after(line: String, marker: String) -> String:
	var at: int = line.find(marker)
	if at < 0:
		return ""
	var rest: String = line.substr(at + marker.length())
	var end: int = rest.find("\"")
	return rest.substr(0, end) if end > 0 else ""


## THE EDITABLE-INSTANCE TRAP, and it is a SILENT EXPORT failure — found by T2.0 running an
## exported build, not by any gate. courtyard.tscn overrode object_id, label_key and
## conversation_id on two nodes INSIDE its instanced npc.tscn without the `[editable path=...]`
## marker that makes those internals addressable. From source that works: the text loader applies
## the overrides and every rung, both CI jobs and 911 assertions were green. An export converts
## .tscn to BINARY .scn, and the conversion drops overrides on a non-editable instance — so the
## exported build booted with a keeper who had no object_id, no prompt and no conversation, and
## said so in three log lines nobody would have seen for months.
##
## This project hand-authors its .tscn files, so the marker the editor would have written is
## exactly the thing a hand-authored scene forgets. Hence a gate rather than a note.
##
## THE RULE: a [node] block whose parent path descends into an instanced node requires an
## [editable path="<that instance>"] for that instance. Deliberately STRICTER than the failure
## needs — an ADDED node inside an instance was observed to survive the conversion, and it is
## still required to be declared editable, because "which of the two kinds is this" is a
## distinction the export makes and the author should not have to remember.
func _check_editable_instances(path: String) -> void:
	var instances: PackedStringArray = PackedStringArray()
	var editable: PackedStringArray = PackedStringArray()
	var inside: Dictionary[String, int] = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		if line.begins_with("[editable path=\""):
			editable.append(_quoted_after(line, "[editable path=\""))
		elif line.begins_with("[node "):
			_note_node(line, line_number, instances, inside)
	file.close()
	_report_uneditable(path, instances, editable, inside)


## One [node] header: remember it if it is an instance, and remember where it sits if its parent
## is not the scene root. The full path of a node is its parent path plus its name, and a parent
## of "." is the root.
func _note_node(
	line: String,
	line_number: int,
	instances: PackedStringArray,
	inside: Dictionary[String, int],
) -> void:
	var node_name: String = _quoted_after(line, "name=\"")
	var parent: String = _quoted_after(line, "parent=\"")
	if node_name == "" or parent == "":
		return
	var full: String = node_name if parent == "." else "%s/%s" % [parent, node_name]
	if line.contains(" instance="):
		instances.append(full)
	if parent != ".":
		inside[full] = line_number


## For every node sitting under an instance, the instance must be declared editable. Godot needs
## the marker at EVERY level, so a nested instance reports one violation per level that lacks
## one rather than only the outermost.
func _report_uneditable(
	path: String,
	instances: PackedStringArray,
	editable: PackedStringArray,
	inside: Dictionary[String, int],
) -> void:
	for full: String in inside:
		for instance: String in instances:
			if full == instance or not full.begins_with("%s/" % instance):
				continue
			if editable.has(instance):
				continue
			_fail("%s:%d overrides '%s' inside the instance '%s' with no [editable path=\"%s\"] — the override is DROPPED in an exported build" % [
				path, inside[full], full, instance, instance,
			])
