class_name PersistentState
extends Node
## Gives one world object a stable identity and somewhere to keep what the player changed.
## Add it as a child of any object that must remember something across a save.
##
## WHY IDENTITY IS AUTHORED AND NOT DERIVED
## The obvious identity is the node path, and it is a trap: renaming a node or reparenting it
## silently orphans its saved state, the chest refills, and nothing errors. That bug surfaces
## weeks later in someone else's save file. An authored id costs one field and survives every
## scene edit. See docs/decisions/ADR-0005.
##
## State is written through `Flags`, namespaced per area and per object:
##     obj/<area_id>/<object_id>/<field>
## so it round-trips through the save machinery that already exists and is already tested.
##
## Usage, from the object that owns it:
##     if not state.fetch_bool(&"thrown"):
##         state.store(&"thrown", true)
##
## OWNS: this object's identity and the shape of its storage keys.
## MUST NOT: know what any field means, or contain object behaviour. It is storage.

## Unique within this area. Lowercase, snake_case, descriptive: `gate_lever`, `shrine_offering`.
@export var object_id: StringName = &""

var _area_id: StringName = &"global"
var _valid: bool = false


func _ready() -> void:
	_area_id = _resolve_area_id()
	if object_id == &"":
		# Loud on purpose. A silent fallback here would recreate the node-path failure that
		# ADR-0005 exists to prevent.
		Log.error("world", "%s has a PersistentState with no object_id — its state cannot persist" % _owner_name())
		return
	_valid = true


## True if this object can actually persist. False means `object_id` was never set.
func is_valid_state() -> bool:
	return _valid


func area_id() -> StringName:
	return _area_id


## The full flag key for a field, for logging and for debug tooling.
func key(field: StringName) -> StringName:
	return StringName("obj/%s/%s/%s" % [_area_id, object_id, field])


func store(field: StringName, value: Variant) -> void:
	if not _valid:
		return
	Flags.set_flag(key(field), value)


func has(field: StringName) -> bool:
	return _valid and Flags.has_flag(key(field))


func fetch_bool(field: StringName, default: bool = false) -> bool:
	return Flags.get_bool(key(field), default) if _valid else default


## fetch_int, fetch_float and fetch_dict have NO CALLER in this template and are kept as a set:
## `fetch_bool` and `fetch_string` are used, and a typed family with holes in it is worse than no
## family, because the game that stores a counter or a position on an object would then reach
## past PersistentState to Flags and lose the per-object key prefix that is the whole point.
func fetch_int(field: StringName, default: int = 0) -> int:
	return Flags.get_int(key(field), default) if _valid else default


func fetch_string(field: StringName, default: String = "") -> String:
	return Flags.get_string(key(field), default) if _valid else default


## Forget everything this object stored. For debug tooling and for a "reset area" command.
func clear() -> void:
	if not _valid:
		return
	for flag: StringName in Flags.with_prefix("obj/%s/%s/" % [_area_id, object_id]):
		Flags.erase_flag(flag)


## Walk up to the enclosing area, so an id only has to be unique within one area file.
## Objects placed outside an area fall back to "global", which is correct for anything
## parented under the persistent world root rather than a loaded area.
func _resolve_area_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		var area: AreaRoot = node as AreaRoot
		if area != null:
			return area.area_id
		node = node.get_parent()
	return &"global"


func _owner_name() -> String:
	var host: Node = get_parent()
	return host.name if host != null else name


## A Dictionary field, deep-copied. Container contents live here.
## NO CALLER — see fetch_int above; these three are one decision.
func fetch_dict(field: StringName, default: Dictionary = {}) -> Dictionary:
	return Flags.get_dict(key(field), default) if _valid else default.duplicate(true)


## NO CALLER — see fetch_int above; these three are one decision.
func fetch_float(field: StringName, default: float = 0.0) -> float:
	return Flags.get_float(key(field), default) if _valid else default
