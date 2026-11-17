class_name DifficultyDb
extends RefCounted
## Every `Difficulty` under `data/difficulty/`, by its id (C5.4a). `ReactionDb`'s shape.
##
## IN PLAIN WORDS: a game with no difficulty files has one difficulty, the formula as written. A
## test points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of difficulties.
## MUST NOT: know which one is on, or load anything outside `content_dir`.

const DIFFICULTY_DIR: String = "res://data/difficulty"
const ID_PREFIX: String = "difficulty/"

static var content_dir: String = DIFFICULTY_DIR
static var _by_id: Dictionary[StringName, Difficulty] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The difficulty with this id, or null.
static func of(id: StringName) -> Difficulty:
	_ensure_loaded()
	return _by_id.get(id, null)


## Every difficulty id in its `order`, then by id, for a settings screen to offer.
static func ids() -> Array[StringName]:
	_ensure_loaded()
	var out: Array[StringName] = _by_id.keys()
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if _by_id[a].order != _by_id[b].order:
			return _by_id[a].order < _by_id[b].order
		return String(a) < String(b))
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
		content_dir, ID_PREFIX, Difficulty, "a Difficulty", "difficulty", _by_id)
