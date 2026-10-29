class_name SkillDb
extends RefCounted
## Every `Skill` under `data/skills/`, by id. `StatusDb`'s shape.
##
## A SKILL IS FOUND BY ID WHEN A SAVE OR A LEVEL CURVE NAMES ONE (C2.8), and its problems are
## checked over the whole directory by `combat_content_test.gd`, the combat fork's half of
## `check_content`, kept in its own file so upstream's checker is never edited.
##
## OWNS: the catalogue of skills.
## MUST NOT: know who knows a skill, or load anything outside `content_dir`.

const SKILL_DIR: String = "res://data/skills"
const ID_PREFIX: String = "skill/"

static var content_dir: String = SKILL_DIR
static var _by_id: Dictionary[StringName, Skill] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func skill(skill_id: StringName) -> Skill:
	_ensure_loaded()
	if not _by_id.has(skill_id):
		return null
	return _by_id[skill_id]


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
	_problems = ContentScan.into(content_dir, ID_PREFIX, Skill, "a Skill", "skill", _by_id)
