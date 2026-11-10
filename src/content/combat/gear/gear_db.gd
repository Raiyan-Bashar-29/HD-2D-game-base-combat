class_name GearDb
extends RefCounted
## Every `GearDefinition` under `data/gear/`, found by its id or by the item it is (C7.1a).
## `StatusDb`'s shape.
##
## IN PLAIN WORDS: a save remembers worn gear by item id, so loading needs to turn an item id
## back into its gear file. This is that lookup. A test points `content_dir` at a scratch
## directory and calls `rescan()`.
##
## OWNS: the catalogue of gear.
## MUST NOT: know who wears a piece, or load anything outside `content_dir`.

const GEAR_DIR: String = "res://data/gear"
const ID_PREFIX: String = "gear/"

static var content_dir: String = GEAR_DIR
static var _by_id: Dictionary[StringName, GearDefinition] = {}
static var _by_item: Dictionary[StringName, GearDefinition] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The gear file for an item, or null when the item is not gear.
static func for_item(item_id: StringName) -> GearDefinition:
	_ensure_loaded()
	if not _by_item.has(item_id):
		return null
	return _by_item[item_id]


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


static func rescan() -> void:
	_by_id.clear()
	_by_item.clear()
	_problems = PackedStringArray()
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# No directory is no content, not an error: the stripped template has none.
	if not DirAccess.dir_exists_absolute(content_dir):
		return
	_problems = ContentScan.into(
		content_dir, ID_PREFIX, GearDefinition, "a GearDefinition", "gear", _by_id)
	for id: StringName in _by_id:
		var piece: GearDefinition = _by_id[id]
		if _by_item.has(piece.item_id):
			_problems.append("%s and %s are both gear for the item %s"
				% [_by_item[piece.item_id].id, id, piece.item_id])
			continue
		_by_item[piece.item_id] = piece
