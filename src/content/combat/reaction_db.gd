class_name ReactionDb
extends RefCounted
## Every `ElementReaction` under `data/reactions/`, found by its elements (C8.4). `RarityDb`'s
## shape.
##
## IN PLAIN WORDS: a game with no reaction files has no reactions, and hits leave no marks. A test
## points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of reactions.
## MUST NOT: know who is marked, or load anything outside `content_dir`.

const REACTION_DIR: String = "res://data/reactions"
const ID_PREFIX: String = "reaction/"

static var content_dir: String = REACTION_DIR
static var _by_id: Dictionary[StringName, ElementReaction] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The reaction with this id, or null.
static func of(id: StringName) -> ElementReaction:
	_ensure_loaded()
	return _by_id.get(id, null)


## Every reaction that names `element`, in id order.
static func naming(element: StringName) -> Array[ElementReaction]:
	_ensure_loaded()
	var out: Array[ElementReaction] = []
	if element == &"":
		return out
	var ids: Array[StringName] = _by_id.keys()
	ids.sort()
	for id: StringName in ids:
		if _by_id[id].other(element) != &"":
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
	_problems = ContentScan.into(
		content_dir, ID_PREFIX, ElementReaction, "an ElementReaction", "reaction", _by_id)
