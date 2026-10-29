extends Node
## World and plot state. Autoload `Flags`.
##
## WHY A FLAG STORE AT ALL
## Narrative state spreads if you let it: a door remembers whether it is unlocked, an NPC
## remembers whether you spoke, a quest remembers a step, and soon the same truth lives in
## four places and they disagree. One store, one truth, one save section.
##
## WHAT BELONGS HERE: facts the plot cares about, and that must survive a reload.
##     story/chapter                   int    how far the main plot has progressed
##     met/gardener                    bool   has the player spoken to this NPC
##     area/orchard/gate_unlocked      bool   world change the player made
##     count/lanterns_lit              int    a running tally
##
## WHAT DOES NOT BELONG HERE: anything recomputable, anything per-frame, positions,
## velocities, UI state, or a cache. If it can be derived, derive it.
##
## AND ONE DELIBERATE EXCEPTION, WHICH IS WHAT `declare_derived` IS FOR. A recomputable fact
## sometimes has to be READABLE here, because reading a flag is how authored content asks a
## question: a quest step names a flag, and an item count is not one. So a system may PUBLISH a
## derived value into a declared prefix and keep the truth where it already lives — the value is
## visible to `FlagQuery`, announced on `flag_changed`, and left out of the save file, so the
## rule above survives intact. Nothing here derives anything itself; the publisher owns that.
##
## NAMING: lowercase, slash-separated, most general part first, so `story/`, `met/` and
## `area/<id>/` group naturally when sorted or dumped in the debug console.
##
## OWNS: the flag dictionary and its save section.
## MUST NOT: interpret any flag. It never knows what `story/chapter` means.

var _values: Dictionary[StringName, Variant] = {}
## Prefixes whose keys are DERIVED and therefore never saved. See `declare_derived`.
var _derived: Array[String] = []


func _ready() -> void:
	SaveSystem.register(&"flags", _collect_save, _apply_save)


## Set a flag and announce it. Setting a flag to the value it already has is silent, so
## listeners are never woken for a non-change.
func set_flag(flag: StringName, value: Variant) -> void:
	if _values.has(flag) and _values[flag] == value:
		return
	_values[flag] = value
	Log.debug("flags", "%s = %s" % [flag, str(value)])
	Events.flag_changed.emit(flag, value)


## THE UNTYPED ESCAPE HATCH. NO CALLER here, because everything in this template stores a bool,
## an int, a String, a float, an Array or a Dictionary, and each of those has a typed accessor
## below that is better in every way. It survives for the type this template did not anticipate:
## a game storing a Vector3 or a custom Resource on a flag has no other way to read it back, and
## the typed accessors cannot be widened to cover a type they cannot check.
func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return _values.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return _values.has(flag)


## Typed accessors. Prefer these over the untyped hatch above, so a wrong type is caught here instead
## of surfacing as a strange bug three systems away.
func get_bool(flag: StringName, default: bool = false) -> bool:
	var value: Variant = _values.get(flag, default)
	if value is bool:
		return value
	Log.warn("flags", "%s is %s, expected bool" % [flag, type_string(typeof(value))])
	return default


func get_int(flag: StringName, default: int = 0) -> int:
	var value: Variant = _values.get(flag, default)
	if value is int or value is float:
		return roundi(value as float)
	Log.warn("flags", "%s is %s, expected int" % [flag, type_string(typeof(value))])
	return default


func get_string(flag: StringName, default: String = "") -> String:
	var value: Variant = _values.get(flag, default)
	if value is String:
		return value
	Log.warn("flags", "%s is %s, expected String" % [flag, type_string(typeof(value))])
	return default


## Add to a counter flag, creating it at zero if absent. Returns the new total.
func advance(flag: StringName, amount: int = 1) -> int:
	var total: int = get_int(flag, 0) + amount
	set_flag(flag, total)
	return total


func erase_flag(flag: StringName) -> void:
	if _values.erase(flag):
		Events.flag_changed.emit(flag, null)


## Wipe everything. Used when starting a new game, and by tests between cases.
func clear_all() -> void:
	var count: int = _values.size()
	_values.clear()
	Log.info("flags", "Cleared %d flags" % count)


## Every flag whose name starts with `prefix`. Useful for area teardown and debug dumps.
func with_prefix(prefix: String) -> Dictionary[StringName, Variant]:
	var found: Dictionary[StringName, Variant] = {}
	for flag: StringName in _values:
		if String(flag).begins_with(prefix):
			found[flag] = _values[flag]
	return found


func count() -> int:
	return _values.size()


## DECLARE A PREFIX WHOSE KEYS ARE DERIVED, so they are readable but not saved.
##
## The problem it solves: `Inventory` keeps item counts and a quest step can only observe a flag,
## so the counts have to be readable HERE. Writing them into the save section as well would make
## one number saved twice, in two formats, by two participants — and this file's header says a
## recomputable value does not belong in the store at all. So the value is published, announced
## and read like any other flag, and omitted from `_collect_save`: its publisher re-derives it,
## which is the same asymmetry `QuestTracker` already runs on.
##
## Idempotent, so a second carrier declaring the same prefix costs nothing. There is deliberately
## no `undeclare`: a prefix is a property of the engine's namespace rather than of one node's
## lifetime, and a component leaving the tree must not start persisting another one's derived
## keys behind its back.
func declare_derived(prefix: String) -> void:
	if prefix != "" and not _derived.has(prefix):
		_derived.append(prefix)


## Whether this flag sits under a declared derived prefix. Public so a test can assert that a key
## IS derived, rather than infer it from the absence of a row in a save file.
func is_derived(flag: StringName) -> bool:
	for prefix: String in _derived:
		if String(flag).begins_with(prefix):
			return true
	return false


func _collect_save() -> Dictionary:
	# StringName keys become strings in JSON, and come back as strings. _apply_save converts.
	var out: Dictionary = {}
	for flag: StringName in _values:
		if is_derived(flag):
			continue
		out[String(flag)] = _values[flag]
	return out


func _apply_save(data: Dictionary, _from_version: int) -> void:
	_values.clear()
	for key: String in data:
		_values[StringName(key)] = data[key]
	Log.info("flags", "Restored %d flags" % _values.size())


## A Dictionary flag, returned as a DEEP COPY.
##
## WHY A COPY. Godot hands out Dictionaries and Arrays by reference, so returning the stored
## object would let a caller mutate world state without going through set_flag - meaning
## flag_changed never fires and nothing listening ever learns. Container contents are the
## first system that would have been bitten.
func get_dict(flag: StringName, default: Dictionary = {}) -> Dictionary:
	var value: Variant = _values.get(flag, null)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return default.duplicate(true)


## An Array flag, returned as a DEEP COPY. Same reasoning as get_dict.
func get_array(flag: StringName, default: Array = []) -> Array:
	var value: Variant = _values.get(flag, null)
	if value is Array:
		return (value as Array).duplicate(true)
	return default.duplicate(true)


## Floats need their own getter because a JSON round-trip can hand back either an int or a
## float for the same value.
func get_float(flag: StringName, default: float = 0.0) -> float:
	var value: Variant = _values.get(flag, default)
	if value is float:
		return value
	if value is int:
		return float(value as int)
	Log.warn("flags", "%s is %s, expected float" % [flag, type_string(typeof(value))])
	return default
