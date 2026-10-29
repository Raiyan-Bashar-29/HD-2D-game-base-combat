class_name ScheduleDb
extends RefCounted
## Every NpcSchedule in the project, found by scanning data/schedules and cached by id.
##
## THE SCAN LIVES IN `ContentScan`, NOT HERE — T3.1, which is the row this file's header
## called for. It said "three is a pattern, four is a problem — if a fourth registry appears,
## that is the moment to reconsider", and it was reconsidered twice: WP-08 kept the fourth
## copy on sound reasoning about the CACHE, and T3.1 found that the duplication was in the
## SCAN. What remains here is the typed façade — the content root, the cache, and
## `schedule()` returning an `NpcSchedule` with no cast at any call site.
##
## ADR-0006 settled the argument once and it was never about items: a scan is the only option
## where dropping a .tres in a folder is the entire act, a hand-maintained list rots, and a
## generated manifest fails SILENTLY when someone forgets to regenerate it.
##
## OWNS: the schedule content root, caching schedules by id, and reporting what is wrong.
## MUST NOT: run a schedule, move an NPC, or touch an autoload. Problems are RETURNED, never
## logged, so tools/check_content.gd can use this class under `--script`.

const SCHEDULE_DIR: String = "res://data/schedules"

## The directory actually scanned. A CONTENT ROOT rather than a constant: a game may keep its
## schedules somewhere else, and the test fixtures point it at a temp directory so this
## registry can be proved with no authored content on disk at all. Restore it and rescan().
static var content_dir: String = SCHEDULE_DIR
const ID_PREFIX: String = "schedule/"

static var _by_id: Dictionary[StringName, NpcSchedule] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The schedule for an id, or null. A typo yields null rather than a crash; the caller decides
## whether that is an NPC that stands still or an error.
static func schedule(schedule_id: StringName) -> NpcSchedule:
	_ensure_loaded()
	if not _by_id.has(schedule_id):
		return null
	return _by_id[schedule_id]


static func has(schedule_id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(schedule_id)


static func all() -> Dictionary[StringName, NpcSchedule]:
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
## rescan() AND NOT reload() — gotcha 17, and item_db.gd's header has the full story.
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
		content_dir, ID_PREFIX, NpcSchedule, "an NpcSchedule", "schedule", _by_id)
