class_name RarityDb
extends RefCounted
## Every `Rarity` under `data/rarities/`, found by its id (C7.2). `GearDb`'s shape.
##
## IN PLAIN WORDS: a piece of gear names its rarity by id, such as `rarity/rare`, and this
## turns the id back into the tier's file. A game with no rarities has none, and every piece
## then behaves as plain. A test points `content_dir` at a scratch directory and calls
## `rescan()`.
##
## OWNS: the catalogue of rarity tiers.
## MUST NOT: know which pieces have a tier, or load anything outside `content_dir`.

const RARITY_DIR: String = "res://data/rarities"
const ID_PREFIX: String = "rarity/"

static var content_dir: String = RARITY_DIR
static var _by_id: Dictionary[StringName, Rarity] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The tier with this id, or null when there is none (or the id is empty).
static func of(id: StringName) -> Rarity:
	_ensure_loaded()
	if not _by_id.has(id):
		return null
	return _by_id[id]


## Every tier, lowest rank first.
static func ranked() -> Array[Rarity]:
	_ensure_loaded()
	var out: Array[Rarity] = []
	out.assign(_by_id.values())
	out.sort_custom(func(a: Rarity, b: Rarity) -> bool: return a.rank < b.rank)
	return out


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


static func rescan() -> void:
	_by_id.clear()
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
		content_dir, ID_PREFIX, Rarity, "a Rarity", "rarity", _by_id)
