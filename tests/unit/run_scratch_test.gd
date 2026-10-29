extends TestCase
## Whether a suite run writes only inside its own directory, and cleans up the dead runs' ones.
##
## WHAT THIS CAN AND CANNOT PROVE. The defect was two PROCESSES, and one process cannot be two.
## So this asserts the two facts the isolation rests on: every scratch path the suite hands out
## is inside `RunScratch.root()`, and two pids never share a root. The isolation itself was
## proved by running two suites at once, before and after, in DEVLOG.md's T6.13 entry.
##
## PRUNING IS DRIVEN WITH A THRESHOLD THIS CASE SUPPLIES, because nothing can age a heartbeat
## file, and IN A PARENT OF ITS OWN, because a doctored prune aimed at the shared parent is the
## defect again. The real threshold is exercised too: under it, a fresh heartbeat survives.
##
## OWNS: assertions about `RunScratch` and about every suite scratch path living under it.
## MUST NOT: assert what a save, a fixture or a setting CONTAINS. save_dir_test.gd and
## content_scan_test.gd own those.

## Two run directories this case plants: one whose run has stopped, one whose run has only begun.
const RUN_STOPPED: int = 2_000_000_004
const RUN_STARTING: int = 2_000_000_008
const FOREIGN: String = "notes"


func run() -> void:
	plan(28)
	_this_run_has_a_directory_of_its_own()
	_every_scratch_path_is_inside_it()
	_a_stale_run_is_pruned_and_a_live_one_is_not()
	_this_run_beats()
	_removing_a_tree_takes_everything_under_it()


func _this_run_has_a_directory_of_its_own() -> void:
	equal("the root is named for this process", RunScratch.root(),
		"%s/%d" % [RunScratch.PARENT, OS.get_process_id()])
	equal("and the runner created it", DirAccess.dir_exists_absolute(RunScratch.root()), true)
	# The load-bearing one: a shared root is the defect, whatever it is called.
	equal("two processes never share a root", RunScratch.root_for(8) != RunScratch.root_for(12),
		true)
	equal("and a path is built inside it",
		RunScratch.path("x").begins_with(RunScratch.root() + "/"), true)


## Every path a case or the runner may write. A new scratch path added outside the root is the
## defect coming back, so each is named rather than trusted.
func _every_scratch_path_is_inside_it() -> void:
	var paths: Dictionary[String, String] = {
		"the save store": SaveFixture.root(),
		# T6.12's, joined at the merge: `park()` empties it before every case, so shared it is the
		# likeliest race of all.
		"the parking directory": SaveFixture.unclaimed(),
		"the store the runner parked this case on": SaveSystem.save_dir,
		"the settings file": SaveFixture.settings_path(),
		"the settings file the runner pinned": Settings.file_path,
		"the bindings file the runner pinned": KeyBindings.file_path,
		"the fixture root": Fixtures.root(),
		"the item fixtures": Fixtures.item_dir(),
		"the dialogue fixtures": Fixtures.dialogue_dir(),
		"the schedule fixtures": Fixtures.schedule_dir(),
		"the quest fixtures": Fixtures.quest_dir(),
		"the area fixtures": Fixtures.area_def_dir(),
	}
	for label: String in paths:
		equal("%s is this run's own" % label,
			paths[label].begins_with(RunScratch.root() + "/"), true)
	equal("and the player's bindings file is not written", KeyBindings.file_path != KeyBindings.PATH,
		true)


## IN A PARENT OF THIS CASE'S OWN, never `RunScratch.PARENT`. An earlier version pruned the shared
## one with a doctored answer, and a second suite running at the same moment lost its directory
## mid-case. `prune`'s header has the numbers. A negative threshold stands in for an old file.
func _a_stale_run_is_pruned_and_a_live_one_is_not() -> void:
	var parent: String = RunScratch.path("fake_runs")
	var stopped: String = parent.path_join(str(RUN_STOPPED))
	var starting: String = parent.path_join(str(RUN_STARTING))
	var own: String = parent.path_join(str(OS.get_process_id()))
	var foreign: String = parent.path_join(FOREIGN)
	for run: String in [stopped, own, foreign]:
		_plant(run, RunScratch.HEARTBEAT)
	_plant(stopped.path_join("saves"), "slot_00.json")
	_plant(starting, "settings.cfg")

	var removed: PackedStringArray = RunScratch.prune(parent)
	equal("a run whose heartbeat is fresh is left alone", DirAccess.dir_exists_absolute(stopped),
		true)
	equal("so nothing is removed", removed.size(), 0)

	removed = RunScratch.prune(parent, -1)
	equal("a run whose heartbeat is stale is removed, nested and all",
		DirAccess.dir_exists_absolute(stopped), false)
	equal("and prune says so", removed.has(stopped), true)
	equal("a run with no heartbeat yet is left alone", DirAccess.dir_exists_absolute(starting), true)
	equal("and so is this process's own, however stale", DirAccess.dir_exists_absolute(own), true)
	equal("a folder not named by a pid is not prune's to delete",
		DirAccess.dir_exists_absolute(foreign), true)
	RunScratch.remove_tree(parent)


## The runner beats before every case, so this case's own beat is seconds old.
func _this_run_beats() -> void:
	var beat: String = RunScratch.path(RunScratch.HEARTBEAT)
	equal("this run's heartbeat is fresh", FileAccess.file_exists(beat)
		and int(Time.get_unix_time_from_system()) - FileAccess.get_modified_time(beat)
			<= RunScratch.STALE_SECONDS, true)


func _removing_a_tree_takes_everything_under_it() -> void:
	var tree: String = RunScratch.path("tree")
	_plant(tree.path_join("a/b"))
	equal("removing a tree answers true", RunScratch.remove_tree(tree), true)
	equal("and the tree is gone", DirAccess.dir_exists_absolute(tree), false)
	equal("an absent tree is already removed", RunScratch.remove_tree(tree), true)


## A directory with one file in it, so a removal that skips files cannot pass.
func _plant(path: String, file_name: String = "planted.txt") -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var file: FileAccess = FileAccess.open(path.path_join(file_name), FileAccess.WRITE)
	file.store_string("planted")
	file.close()
