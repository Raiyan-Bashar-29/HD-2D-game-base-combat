class_name Fixtures
extends RefCounted
## Where fixture content lives, and how a case switches the registries onto it.
##
## THE DECISION: IN MEMORY WHERE POSSIBLE, ON DISK WHERE THE REGISTRY LOOKS.
## Both were on the table and the answer is split, deliberately, along one line: does the system
## under test receive the content, or LOOK IT UP BY ID?
##
## - RECEIVED. A `Pickup` is handed an `ItemDefinition`, a `PathActionPoint` a `PathAction`.
##   Nothing scans anything, so the fixture is built in memory by `FixtureContent` and set on
##   the node. No file, no temp directory, no global state to restore.
## - LOOKED UP. `Inventory.add(id)` asks `ItemDb`, `DialogueRunner.begin(id)` asks `DialogueDb`,
##   `NpcBrain` asks `ScheduleDb`, `QuestTracker` asks `QuestDb`, and `WorldMap` asks `AreaDb`.
##   Those five registries find content BY DIRECTORY SCAN
##   (ADR-0006) and cache it statically, so an in-memory resource is invisible to them. The
##   options were a test-only injection method on each registry - engine code carrying a
##   backdoor that exists for the suite and for nothing else - or a real directory the real
##   scan really reads. This picks the second.
##
## WHAT THE SECOND OPTION BUYS BEYOND UNWELDING THE SUITE: the fixtures go out through
## `ResourceSaver` and come back through the registry's own scan, so the suite now proves the
## .tres authoring round trip that a consuming game depends on and that nothing tested before.
##
## WHY user:// AND NOT A FOLDER UNDER res://
## Writing into `res://data/` would mean the suite mutates the very content root
## `docs/NEW_GAME.md` tells a game to delete, and a crashed run would leave stray .tres files
## that `tools/check_content.gd` would then fail on. `user://` is outside the repo, so the
## worst a crashed run leaves behind is a stale temp directory that the next `activate()`
## overwrites.
##
## OWNS: the temp content root, redirecting the five registries onto it and back, and telling
## a case whether demo content exists at all.
## MUST NOT: build content (that is `FixtureContent`), or assert anything.

const AREA_ROOT: String = "res://scenes/areas"

static var _active: bool = false


## The fixture content root, inside this run's own scratch directory (T6.13): a fixed name under
## the `user://` every worktree shares let a second suite rewrite this one's fixtures mid-case,
## and a file one case planted appeared in the other's scan. `RunScratch` says why per process.
static func root() -> String:
	return RunScratch.path("fixtures")


static func item_dir() -> String:
	return root().path_join("items")


static func dialogue_dir() -> String:
	return root().path_join("dialogue")


static func schedule_dir() -> String:
	return root().path_join("schedules")


static func quest_dir() -> String:
	return root().path_join("quests")


static func area_def_dir() -> String:
	return root().path_join("areas")


static func is_active() -> bool:
	return _active


## Point all five registries at fixture content. Idempotent, and it REWRITES the files every
## time: a case that edited a cached resource in place must not leave that edit for the next.
static func activate() -> bool:
	var written: bool = _write_all()
	ItemDb.content_dir = item_dir()
	DialogueDb.content_dir = dialogue_dir()
	ScheduleDb.content_dir = schedule_dir()
	QuestDb.content_dir = quest_dir()
	AreaDb.content_dir = area_def_dir()
	_reload_all()
	_active = true
	return written


## Back to whatever the game itself ships. Called by the runner after EVERY case, not only by
## the cases that switched, because a case that crashes half way through would otherwise leave
## every later case reading fixture content and never say so.
static func deactivate() -> void:
	if not _active:
		return
	_active = false
	ItemDb.content_dir = ItemDb.ITEM_DIR
	DialogueDb.content_dir = DialogueDb.DIALOGUE_DIR
	ScheduleDb.content_dir = ScheduleDb.SCHEDULE_DIR
	QuestDb.content_dir = QuestDb.QUEST_DIR
	AreaDb.content_dir = AreaDb.AREA_DIR
	_reload_all()


## Whether this checkout still has the demo in it. A stripped template - `data/` and
## `scenes/areas/` deleted, which is step one of docs/NEW_GAME.md - answers false, and the cases
## that genuinely assert things ABOUT the demo skip themselves and say so.
static func has_demo_content() -> bool:
	return not (area_ids().is_empty()
		and ContentScan.resource_paths(ItemDb.ITEM_DIR).is_empty()
		and ContentScan.resource_paths(DialogueDb.DIALOGUE_DIR).is_empty()
		and ContentScan.resource_paths(ScheduleDb.SCHEDULE_DIR).is_empty()
		and ContentScan.resource_paths(QuestDb.QUEST_DIR).is_empty()
		and ContentScan.resource_paths(AreaDb.AREA_DIR).is_empty())


## Every area a game has authored, DISCOVERED rather than listed. The structural contract in
## `area_root.gd`'s header applies to whatever areas exist, so listing two demo ids would both
## weld the suite to the demo and stop covering area three.
static func area_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for folder: String in DirAccess.get_directories_at(AREA_ROOT):
		var packed: String = "%s/%s/%s.tscn" % [AREA_ROOT, folder, folder]
		if ResourceLoader.exists(packed):
			out.append(StringName(folder))
	out.sort()
	return out


static func _reload_all() -> void:
	ItemDb.rescan()
	DialogueDb.rescan()
	ScheduleDb.rescan()
	QuestDb.rescan()
	AreaDb.rescan()


static func _write_all() -> bool:
	var ok: bool = true
	var dirs: Array[String] = [
		item_dir(), dialogue_dir(), schedule_dir(), quest_dir(), area_def_dir(),
	]
	for directory: String in dirs:
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			ok = false
	for definition: ItemDefinition in FixtureContent.items():
		ok = _save(definition, item_dir(), definition.id) and ok
	var talk: Conversation = FixtureContent.conversation()
	ok = _save(talk, dialogue_dir(), talk.id) and ok
	var timetable: NpcSchedule = FixtureContent.schedule()
	ok = _save(timetable, schedule_dir(), timetable.id) and ok
	for errand: Quest in FixtureContent.quests():
		ok = _save(errand, quest_dir(), errand.id) and ok
	for def: AreaDef in FixtureContent.area_defs():
		ok = _save(def, area_def_dir(), def.id) and ok
	return ok


## The file NAME carries the id, because every registry requires the two to agree - which is
## itself a rule the fixtures now exercise rather than assume.
static func _save(resource: Resource, directory: String, id: StringName) -> bool:
	var path: String = "%s/%s.tres" % [directory, String(id).get_file()]
	return ResourceSaver.save(resource, path) == OK
