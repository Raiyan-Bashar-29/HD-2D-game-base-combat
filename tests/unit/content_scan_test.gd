extends TestCase
## The one directory scan behind all five catalogues, and the contract each of them keeps.
##
## WHY THIS FILE EXISTS. T3.1 moved scan-and-validate out of five registries and into
## `ContentScan.into()`. A refactor's assertions are mostly the EXISTING ones staying green,
## but a shared scan has one failure mode nothing else would catch: it can go on working for
## four catalogues and quietly stop reporting a bad file for the fifth — a wrong prefix, a
## wrong `kind`, an `_ensure_loaded` that dropped the problems on the floor. So the per-file
## error reporting is asserted for EVERY registry by name, not for one and by analogy.
##
## The scan itself is driven directly, with dictionaries this file owns, because every branch
## it has is a content error and a content error is easier to plant than to find.
##
## OWNS: assertions about finding content on disk and refusing what is wrong with it.
## MUST NOT: assert what a catalogue's entries MEAN — that is items_test, dialogue_test,
## npc_test, quests_test and world_map_test, each of which owns its own content type.

const ITEM_LABEL: String = "an ItemDefinition"
const SOUND_ID: StringName = &"item/scan_sound"
const TWIN_ID: StringName = &"item/scan_twin"
const BARE_ID: StringName = &"scan_bare"
const BARE_OFF_ID: StringName = &"scan_bare_off"
const PLANTED: String = "scan_planted"

## Under this run's own scratch directory (T6.13), so a suite in another worktree cannot plant a
## file into this one's scan. Vars rather than consts because the name carries the process id.
var _root: String = RunScratch.path("content_scan")
var _empty_dir: String = RunScratch.path("content_scan/empty")
var _missing_dir: String = RunScratch.path("content_scan/never_created")
var _work_dir: String = RunScratch.path("content_scan/work")
var _bare_dir: String = RunScratch.path("content_scan/bare")


func run() -> void:
	plan(47)
	_an_absent_or_empty_root_is_not_a_problem()
	_a_sound_file_is_found_and_keyed_by_its_id()
	_an_id_that_disagrees_with_its_file_name_is_refused()
	_a_resource_of_the_wrong_type_is_refused()
	_a_duplicate_id_is_refused()
	_a_catalogue_with_no_prefix_works()
	_every_catalogue_reports_its_own_bad_file()
	_every_content_root_goes_back_to_its_own()
	_tear_down()


## T1.2's finding, and the reason a stripped template passes its own content gate on step one
## of docs/NEW_GAME.md. Both cases matter: a root that exists and holds nothing, and a root
## that was never created at all, which is what a game that authors no quests has.
func _an_absent_or_empty_root_is_not_a_problem() -> void:
	DirAccess.make_dir_recursive_absolute(_empty_dir)
	var empty: Dictionary[StringName, ItemDefinition] = {}
	var from_empty: PackedStringArray = _scan(_empty_dir, empty)
	equal("an empty content root yields no entries", empty.size(), 0)
	equal("an empty content root is not an error: %s" % str(from_empty),
		from_empty.is_empty(), true)
	# The absent root prints an engine `Couldn't open directory` line. That is DirAccess
	# answering honestly on the fallback path, it is ERROR_TYPE_ERROR rather than
	# ERROR_TYPE_SCRIPT so `ErrorWatch` counts it and does not fail the case, and a stripped
	# template prints the same five lines at boot today. The behaviour under test is what the
	# SCAN does with it: nothing.
	var absent: Dictionary[StringName, ItemDefinition] = {}
	var from_absent: PackedStringArray = _scan(_missing_dir, absent)
	equal("a content root that does not exist yields no entries", absent.size(), 0)
	equal("a content root that does not exist is not an error: %s" % str(from_absent),
		from_absent.is_empty(), true)


func _a_sound_file_is_found_and_keyed_by_its_id() -> void:
	_clear(_work_dir)
	_write(FixtureContent.item(SOUND_ID, GameEnums.ItemCategory.MATERIAL, 9), _work_dir, "tres")
	var found: Dictionary[StringName, ItemDefinition] = {}
	var problems: PackedStringArray = _scan(_work_dir, found)
	equal("a sound file is loaded", found.size(), 1)
	equal("a sound file raises nothing: %s" % str(problems), problems.is_empty(), true)
	equal("it is keyed by its declared id", found.has(SOUND_ID), true)
	# The dictionary the scan filled is the CALLER'S typed one, which is the whole reason
	# ItemDb.definition() still returns ItemDefinition with no cast at any call site.
	equal("and the dictionary kept its value type", found.is_typed_value(), true)


## The id-equals-file-name rule, which is the same rule for all five catalogues and the one an
## author trips over. The message must name BOTH values or it does not help.
func _an_id_that_disagrees_with_its_file_name_is_refused() -> void:
	_clear(_work_dir)
	var wrong: ItemDefinition = FixtureContent.item(SOUND_ID, GameEnums.ItemCategory.MATERIAL, 1)
	ResourceSaver.save(wrong, "%s/%s.tres" % [_work_dir, PLANTED])
	var found: Dictionary[StringName, ItemDefinition] = {}
	var problems: PackedStringArray = _scan(_work_dir, found)
	equal("a file whose id disagrees is refused", problems.size(), 1)
	equal("the message names the id that was declared",
		problems[0].contains(String(SOUND_ID)), true)
	equal("the message names the id the file name requires",
		problems[0].contains("item/%s" % PLANTED), true)
	equal("and the resource is not in the catalogue", found.size(), 0)


## A .tres that is present, loads perfectly and is simply not this catalogue's type. Refused
## by name rather than by crash, and the label is the registry's own, so a registry handed the
## wrong `kind` would say the wrong thing here.
func _a_resource_of_the_wrong_type_is_refused() -> void:
	_clear(_work_dir)
	ResourceSaver.save(FixtureContent.schedule(), "%s/%s.tres" % [_work_dir, PLANTED])
	var found: Dictionary[StringName, ItemDefinition] = {}
	var problems: PackedStringArray = _scan(_work_dir, found)
	equal("a resource of the wrong type is refused", problems.size(), 1)
	equal("and it is refused by the catalogue's own type name",
		problems[0].ends_with("is not %s" % ITEM_LABEL), true)
	equal("and nothing is added", found.size(), 0)


## Two files can only collide when they share a base name, which .tres and .res do. Rare, and
## exactly the case where a catalogue would otherwise silently keep whichever came second.
func _a_duplicate_id_is_refused() -> void:
	_clear(_work_dir)
	var twin: ItemDefinition = FixtureContent.item(TWIN_ID, GameEnums.ItemCategory.MATERIAL, 4)
	ResourceSaver.save(twin, "%s/%s.tres" % [_work_dir, String(TWIN_ID).get_file()])
	ResourceSaver.save(twin, "%s/%s.res" % [_work_dir, String(TWIN_ID).get_file()])
	var found: Dictionary[StringName, ItemDefinition] = {}
	var problems: PackedStringArray = _scan(_work_dir, found)
	equal("a second file claiming the same id is refused", problems.size(), 1)
	equal("and the message says which id", problems[0].contains(String(TWIN_ID)), true)
	equal("and exactly one entry survives", found.size(), 1)


## AreaDb passes an EMPTY prefix, because an area id is already a public identifier — it is a
## folder name. An empty prefix is a legitimate catalogue rather than an oversight, and it is
## the one argument to `into()` that no other registry exercises.
func _a_catalogue_with_no_prefix_works() -> void:
	_clear(_bare_dir)
	_write(FixtureContent.area_def(BARE_ID, Vector2(0.5, 0.5), false, &""), _bare_dir, "tres")
	var found: Dictionary[StringName, AreaDef] = {}
	var problems: PackedStringArray = ContentScan.into(
		_bare_dir, "", AreaDef, "an AreaDef", "area", found)
	equal("a prefix-less catalogue loads its file: %s" % str(problems), found.size(), 1)
	equal("and the bare file name is the id", found.has(BARE_ID), true)
	# A def outside the 0..1 plate is AreaDef's own complaint, not the scan's, and it must
	# reach the caller: entry.problems() is appended for every resource that passes the scan.
	# A SECOND ID, not the same file rewritten: ResourceLoader caches by path, so re-saving
	# over a path already loaded in this run hands the scan back the FIRST resource.
	_clear(_bare_dir)
	_write(FixtureContent.area_def(BARE_OFF_ID, Vector2(9.0, 9.0), false, &""), _bare_dir, "tres")
	var second: Dictionary[StringName, AreaDef] = {}
	var raised: PackedStringArray = ContentScan.into(
		_bare_dir, "", AreaDef, "an AreaDef", "area", second)
	equal("the resource's own problems reach the caller", raised.size(), 1)
	equal("and it is still catalogued, because it loaded", second.size(), 1)


## THE ASSERTION THIS WHOLE FILE EXISTS FOR. One shared scan is exactly the change that can
## leave four catalogues reporting a bad file and the fifth silent. So each registry is named,
## the same violation is planted in all five roots at once, and the way back out is asserted
## too — a case that left a planted file behind would hand the next case a broken catalogue.
func _every_catalogue_reports_its_own_bad_file() -> void:
	Fixtures.activate()
	for directory: String in _fixture_dirs():
		ResourceSaver.save(FixtureContent.path_action(), "%s/%s.tres" % [directory, PLANTED])
	_rescan_all()
	equal("ItemDb reports a bad file in its root", ItemDb.problems().size(), 1)
	equal("DialogueDb reports a bad file in its root", DialogueDb.problems().size(), 1)
	equal("ScheduleDb reports a bad file in its root", ScheduleDb.problems().size(), 1)
	equal("QuestDb reports a bad file in its root", QuestDb.problems().size(), 1)
	equal("AreaDb reports a bad file in its root", AreaDb.problems().size(), 1)
	_counts_are_unharmed()
	for directory: String in _fixture_dirs():
		DirAccess.remove_absolute("%s/%s.tres" % [directory, PLANTED])
	_rescan_all()
	equal("ItemDb is clean once it is gone: %s" % str(ItemDb.problems()),
		ItemDb.problems().is_empty(), true)
	equal("DialogueDb is clean once it is gone: %s" % str(DialogueDb.problems()),
		DialogueDb.problems().is_empty(), true)
	equal("ScheduleDb is clean once it is gone: %s" % str(ScheduleDb.problems()),
		ScheduleDb.problems().is_empty(), true)
	equal("QuestDb is clean once it is gone: %s" % str(QuestDb.problems()),
		QuestDb.problems().is_empty(), true)
	equal("AreaDb is clean once it is gone: %s" % str(AreaDb.problems()),
		AreaDb.problems().is_empty(), true)
	_counts_are_unharmed()


## One bad file must cost the catalogue exactly that file. A scan that gave up on the first
## problem would look identical in every assertion above and lose every later entry.
func _counts_are_unharmed() -> void:
	equal("ItemDb still holds its fixtures", ItemDb.count(), FixtureContent.items().size())
	equal("DialogueDb still holds its fixture", DialogueDb.count(), 1)
	equal("ScheduleDb still holds its fixture", ScheduleDb.count(), 1)
	equal("QuestDb still holds its fixtures", QuestDb.count(), FixtureContent.quests().size())
	equal("AreaDb still holds its fixtures", AreaDb.count(),
		FixtureContent.area_defs().size())


## `content_dir` is a static var and not a const precisely so the fixtures can redirect it,
## and the runner calls deactivate() after every case. A registry that lost its own constant
## would strand every later case on fixture content, so the way back is asserted, not assumed.
func _every_content_root_goes_back_to_its_own() -> void:
	Fixtures.deactivate()
	equal("ItemDb is back on its own root", ItemDb.content_dir, ItemDb.ITEM_DIR)
	equal("DialogueDb is back on its own root", DialogueDb.content_dir, DialogueDb.DIALOGUE_DIR)
	equal("ScheduleDb is back on its own root", ScheduleDb.content_dir, ScheduleDb.SCHEDULE_DIR)
	equal("QuestDb is back on its own root", QuestDb.content_dir, QuestDb.QUEST_DIR)
	equal("AreaDb is back on its own root", AreaDb.content_dir, AreaDb.AREA_DIR)


func _tear_down() -> void:
	for directory: String in [_empty_dir, _work_dir, _bare_dir]:
		_clear(directory)
		DirAccess.remove_absolute(directory)
	DirAccess.remove_absolute(_root)


func _scan(directory: String, into: Dictionary[StringName, ItemDefinition]) -> PackedStringArray:
	return ContentScan.into(directory, ItemDb.ID_PREFIX, ItemDefinition, ITEM_LABEL, "item", into)


func _fixture_dirs() -> Array[String]:
	return [Fixtures.item_dir(), Fixtures.dialogue_dir(), Fixtures.schedule_dir(),
		Fixtures.quest_dir(), Fixtures.area_def_dir()]


func _rescan_all() -> void:
	ItemDb.rescan()
	DialogueDb.rescan()
	ScheduleDb.rescan()
	QuestDb.rescan()
	AreaDb.rescan()


func _write(resource: ContentEntry, directory: String, suffix: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(resource,
		"%s/%s.%s" % [directory, String(resource.id).get_file(), suffix])


func _clear(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute("%s/%s" % [directory, file_name])
