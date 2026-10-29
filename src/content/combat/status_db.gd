class_name StatusDb
extends RefCounted
## Every `StatusEffect` under `data/statuses/`, by id. `ItemDb`'s shape, with only the accessors
## something calls.
##
## A SAVE STORES A STATUS BY ID, so loading one needs this lookup; that is the whole reason it
## exists. A test points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of statuses.
## MUST NOT: know who holds a status, or load anything outside `content_dir`.

const STATUS_DIR: String = "res://data/statuses"
const ID_PREFIX: String = "status/"

static var content_dir: String = STATUS_DIR
static var _by_id: Dictionary[StringName, StatusEffect] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func status(status_id: StringName) -> StatusEffect:
	_ensure_loaded()
	if not _by_id.has(status_id):
		return null
	return _by_id[status_id]


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
	_problems = ContentScan.into(
		content_dir, ID_PREFIX, StatusEffect, "a StatusEffect", "status", _by_id)
