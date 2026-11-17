class_name AffixDb
extends RefCounted
## Every `Affix` under `data/affixes/` (C7.2b). `RarityDb`'s shape.
##
## IN PLAIN WORDS: a game with no affix files has none, and dropped pieces roll nothing. A test
## points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of affixes.
## MUST NOT: know which piece rolled what, or load anything outside `content_dir`.

const AFFIX_DIR: String = "res://data/affixes"
const ID_PREFIX: String = "affix/"

static var content_dir: String = AFFIX_DIR
static var _by_id: Dictionary[StringName, Affix] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The affix with this id, or null.
static func of(id: StringName) -> Affix:
	_ensure_loaded()
	return _by_id.get(id, null)


## Every affix that fits a piece going in `piece_slots`, in id order.
static func fitting(piece_slots: Array[StringName]) -> Array[Affix]:
	_ensure_loaded()
	var ids: Array[StringName] = _by_id.keys()
	ids.sort()
	var out: Array[Affix] = []
	for id: StringName in ids:
		if _by_id[id].fits(piece_slots):
			out.append(_by_id[id])
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
	_problems = ContentScan.into(content_dir, ID_PREFIX, Affix, "an Affix", "affix", _by_id)
