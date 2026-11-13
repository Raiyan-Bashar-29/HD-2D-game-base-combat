class_name GemDb
extends RefCounted
## Every `GemDefinition` under `data/gems/`, found by the item it is (C7.4c). `GearDb`'s shape.
##
## IN PLAIN WORDS: a socket remembers its gem by item id, so wearing the piece needs to turn
## that id back into the gem's file. This is that lookup. A game with no gems has none. A test
## points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of gems.
## MUST NOT: know which piece holds a gem, or load anything outside `content_dir`.

const GEM_DIR: String = "res://data/gems"
const ID_PREFIX: String = "gem/"

static var content_dir: String = GEM_DIR
static var _by_id: Dictionary[StringName, GemDefinition] = {}
static var _by_item: Dictionary[StringName, GemDefinition] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The gem file for an item, or null when the item is not a gem.
static func for_item(item_id: StringName) -> GemDefinition:
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
		content_dir, ID_PREFIX, GemDefinition, "a GemDefinition", "gem", _by_id)
	for id: StringName in _by_id:
		var gem: GemDefinition = _by_id[id]
		if _by_item.has(gem.item_id):
			_problems.append("%s and %s are both gems for the item %s"
				% [_by_item[gem.item_id].id, id, gem.item_id])
			continue
		_by_item[gem.item_id] = gem
