class_name PassiveDb
extends RefCounted
## Every `PassiveSkill` under `data/passives/`, by id (C9.1). `StatusDb`'s shape.
##
## IN PLAIN WORDS: a save, and later the loadout (C9.4), name a passive by its id, so something
## has to turn an id back into the file. A test points `content_dir` at a scratch directory and
## calls `rescan()`.
##
## OWNS: the catalogue of passives.
## MUST NOT: know who holds a passive, or load anything outside `content_dir`.

const PASSIVE_DIR: String = "res://data/passives"
const ID_PREFIX: String = "passive/"

static var content_dir: String = PASSIVE_DIR
static var _by_id: Dictionary[StringName, PassiveSkill] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func passive(passive_id: StringName) -> PassiveSkill:
	_ensure_loaded()
	if not _by_id.has(passive_id):
		return null
	return _by_id[passive_id]


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
		content_dir, ID_PREFIX, PassiveSkill, "a PassiveSkill", "passive", _by_id)
