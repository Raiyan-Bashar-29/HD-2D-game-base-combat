class_name EncounterDb
extends RefCounted
## Every `Encounter` under `data/encounters/`, by id. `StatusDb`'s shape; `skill_test.gd`
## checks the whole directory for problems.
##
## OWNS: the catalogue of encounters.
## MUST NOT: start one, or load anything outside `content_dir`.

const ENCOUNTER_DIR: String = "res://data/encounters"
const ID_PREFIX: String = "encounter/"

static var content_dir: String = ENCOUNTER_DIR
static var _by_id: Dictionary[StringName, Encounter] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func encounter(encounter_id: StringName) -> Encounter:
	_ensure_loaded()
	if not _by_id.has(encounter_id):
		return null
	return _by_id[encounter_id]


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
	_problems = ContentScan.into(content_dir, ID_PREFIX, Encounter, "an Encounter", "encounter", _by_id)
