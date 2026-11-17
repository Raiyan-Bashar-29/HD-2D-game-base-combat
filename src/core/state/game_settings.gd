class_name GameSettings
extends RefCounted
## The settings a game adds to the base's own (T7.4). `Settings.game` holds one.
##
## IN PLAIN WORDS: `Settings.DEFAULTS` is a const, so a game built on this base could not give the
## player an option of its own, such as a difficulty or an aim assist. Now it calls
## `Settings.game.add(path, default, choices)` once at boot. From then on that setting is read,
## written, saved, announced and reset like a built-in one, and the settings screen draws it: at
## the end of the built-in section it names (`gameplay/...`), or under a section of its own.
##
## `choices` ARE THE VALUES ONE PRESS WALKS, in order. A bool needs none. An int or a String must
## have them, because a press cannot invent the next value; a float without them steps from 0 to 1
## by a tenth. The default must be one of them. The screen shows a String value through the key
## `ui.settings.<section>.<key>.<value>` (`SettingsScreen.value_key`), and an int as its number.
##
## A SAVED VALUE NEEDS NO RESTORING, unlike a key binding (T7.3). `Settings` reads the whole file at
## boot, a game's sections too, so the player's choice is already there when `add` runs; `add`
## only says what the default is and which values a press may choose.
##
## OWNS: which settings a game added, their defaults and choices, and the order rows are drawn in.
## MUST NOT: read, write or announce a value. `Settings` does all three. Nor name `Settings`: it is
## handed the built-in list when made, so the two files are not a cycle.

## The value kinds a settings file holds and a press can change.
const KINDS: Array[int] = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]

## The base's own settings, `Settings.DEFAULTS`: never added over, and drawn first.
var _built_in: Dictionary = {}
## path -> default, in the order added.
var _defaults: Dictionary[String, Variant] = {}
## path -> the values a press walks.
var _choices: Dictionary[String, Array] = {}


func _init(built_in: Dictionary = {}) -> void:
	_built_in = built_in


## Add a setting, or change the default and choices of one already added. Refused, with an error
## and false, for an empty or built-in path, a kind a settings file cannot hold, an int or a String
## with no choices, a choice of another kind, or a default that is not one of the choices.
func add(path: String, default: Variant, choices: Array = []) -> bool:
	var problem: String = _problem(path, default, choices)
	if problem != "":
		Log.error("settings", "Cannot add setting '%s': %s" % [path, problem])
		return false
	_defaults[path] = default
	_choices[path] = [] if default is bool else choices.duplicate()
	return true


## The default of a setting a game added, or null for any other path.
func default_of(path: String) -> Variant:
	return _defaults.get(path, null)


## The values one press walks for a setting a game added; empty for a bool, a float that steps by a
## tenth, or a path no game added.
func choices_of(path: String) -> Array:
	if not _choices.has(path):
		return []
	return _choices[path].duplicate()


## Every setting, built-in and added, in the order the settings screen draws them: the built-ins in
## their own order, each added one after the last row of its section, and a new section
## after all of those.
func every() -> Array[String]:
	var paths: Array[String] = []
	for path: String in _built_in:
		paths.append(path)
	for path: String in _defaults:
		paths.insert(_end_of(paths, section_of(path)), path)
	return paths


## The section a path belongs to: the text before its first slash, or "general" for none.
static func section_of(path: String) -> String:
	return path.get_slice("/", 0) if path.contains("/") else "general"


func _problem(path: String, default: Variant, choices: Array) -> String:
	if path == "" or _built_in.has(path):
		return "the path is empty or a built-in one"
	var kind: int = typeof(default)
	if not KINDS.has(kind):
		return "a setting is a bool, an int, a float or a String, not %s" % type_string(kind)
	if kind == TYPE_BOOL:
		return ""
	if choices.is_empty():
		return "" if kind == TYPE_FLOAT else "an int or a String needs its choices"
	for choice: Variant in choices:
		if typeof(choice) != kind:
			return "the choice %s is not a %s" % [str(choice), type_string(kind)]
	return "" if choices.has(default) else "the default is not one of the choices"


## Just past the last path in `section`, or the end when no path is in it yet.
func _end_of(paths: Array[String], section: String) -> int:
	for index: int in range(paths.size() - 1, -1, -1):
		if section_of(paths[index]) == section:
			return index + 1
	return paths.size()
