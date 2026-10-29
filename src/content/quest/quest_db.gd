class_name QuestDb
extends RefCounted
## Every Quest in the project, found by scanning data/quests and cached by id.
##
## THE SCAN LIVES IN `ContentScan`, NOT HERE — T3.1, the row this file's header asked for.
## WP-08 wrote it as: "the refactor that WOULD pay is a base holding the cache plus a thin
## typed facade per registry", and then kept the fourth copy because a base holding the CACHE
## could only hand back untyped `Resource`s. Both halves were right, and the resolution is
## that the duplication was never in the cache — it was in the SCAN. What remains here is the
## typed façade: the content root, the cache, and `quest()` returning a `Quest` with no cast
## at any call site.
##
## ADR-0006 verbatim, and it was never about items: a scan is the only option where dropping a
## .tres in a folder is the entire act, a hand-maintained list rots, and a generated manifest
## fails SILENTLY when someone forgets to regenerate it.
##
## OWNS: the quest content root, caching quests by id, and reporting what is wrong.
## MUST NOT: track progress, read a flag, or touch an autoload. Problems are RETURNED, never
## logged, so tools/check_content.gd can use this class under `--script`.

const QUEST_DIR: String = "res://data/quests"

## The directory actually scanned. A CONTENT ROOT rather than a constant: a game may keep its
## quests somewhere else, and the test fixtures point it at a temp directory so this registry
## can be proved with no authored content on disk at all. Restore it to QUEST_DIR and rescan().
static var content_dir: String = QUEST_DIR
const ID_PREFIX: String = "quest/"

static var _by_id: Dictionary[StringName, Quest] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The quest for an id, or null. A typo yields null rather than a crash; the caller decides
## whether that is a quest nobody can start or an error.
static func quest(quest_id: StringName) -> Quest:
	_ensure_loaded()
	if not _by_id.has(quest_id):
		return null
	return _by_id[quest_id]


static func has(quest_id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(quest_id)


static func all() -> Dictionary[StringName, Quest]:
	_ensure_loaded()
	return _by_id


static func count() -> int:
	_ensure_loaded()
	return _by_id.size()


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


## Static state survives a scene reload and a new game, which is right for immutable content
## and wrong while authoring or testing. Tests and the validator call this.
##
## rescan() AND NOT reload(). `Script` declares `reload()`, and a GDScript identifier IS the
## script object, so `QuestDb.reload()` would dispatch to the native method and silently reset
## every static variable in this file - including `content_dir`. See gotcha 17.
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
		content_dir, ID_PREFIX, Quest, "a Quest", "quest", _by_id)
