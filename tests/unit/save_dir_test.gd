extends TestCase
## WHERE the save store writes, and whether the redirect the rest of the suite leans on holds.
##
## SPLIT BY QUESTION, on T5.7's precedent. `core_test.gd` asks *does a good save survive a round
## trip* and `save_recovery_test.gd` asks *what happens to a bad one* — both of them about the
## CONTENT of a file. This asks the one question neither can: *which directory did it go in*.
## Putting it in either would mean a round-trip case asserting something about a directory it has
## no reason to care about.
##
## WHY THE "REAL" DIRECTORY IN THESE ASSERTIONS IS A SECOND SCRATCH ONE. The honest statement of
## the seam is "a write while redirected does not touch the directory that was in force before
## it", and asserting that against `user://saves` would be asserting about a developer's own
## disk: the case would pass on a machine where the slot happened to be filled already and fail
## on one where a real save collided. Two scratch directories make the same claim deterministic —
## `_stand_in` plays the part of the shipped default, and nothing here writes to `user://saves` at
## all, which is the entire point of the row.
##
## OWNS: assertions about `SaveSystem.save_dir`, `slot_path`'s use of it, and `SaveFixture`.
## MUST NOT: assert what a save file CONTAINS, or that a load succeeds — that is the other two.

const SLOT: int = 0
const PROBE: StringName = &"save_dir_probe"

## What the probe writes into its section, so the two saves in the load-bearing case are
## distinguishable on disk. See that function's header for why byte equality was not enough.
var _marker: String = ""
## Beside `SaveFixture.root()` inside this run's own directory, T6.13, for the same reason.
var _stand_in: String = RunScratch.path("saves_stand_in")


func run() -> void:
	plan(20)
	_a_case_starts_parked_and_unclaimed()
	_activating_points_the_store_at_the_scratch_directory()
	_a_write_while_redirected_leaves_the_previous_directory_untouched()
	_deactivating_restores_the_default_and_empties_the_scratch()


## A case starts PARKED, not on the shipped default, and this asserted the default until T6.12.
## The runner parks the store before every case so that a case forgetting `activate()` cannot
## reach a real save. The last two assertions are the rule the runner fails a case on.
func _a_case_starts_parked_and_unclaimed() -> void:
	equal("the store starts parked, never on the shipped default",
			SaveSystem.save_dir, SaveFixture.unclaimed())
	equal("and nothing has claimed it yet", SaveFixture.is_active(), false)
	equal("a slot path is built on the parking directory",
			SaveSystem.slot_path(SLOT).begins_with(SaveFixture.unclaimed()), true)
	equal("a write into the shipped default counts as unclaimed",
			SaveFixture.is_unclaimed(SaveSystem.DEFAULT_SAVE_DIR), true)
	equal("a write into the scratch store does not",
			SaveFixture.is_unclaimed(SaveFixture.root()), false)


func _activating_points_the_store_at_the_scratch_directory() -> void:
	SaveFixture.activate()
	equal("activate redirects the store", SaveSystem.save_dir, SaveFixture.root())
	equal("and says so", SaveFixture.is_active(), true)
	equal("a slot path now lands in the scratch directory",
			SaveSystem.slot_path(SLOT).begins_with(SaveFixture.root()), true)
	# The autosave is a separate branch of slot_path and would keep a hardcoded root of its own.
	equal("and so does the autosave, which is the other branch",
			SaveSystem.slot_path(SaveSystem.AUTOSAVE_SLOT).begins_with(SaveFixture.root()), true)
	equal("assigning created the directory",
			DirAccess.dir_exists_absolute(SaveFixture.root()), true)


## The load-bearing one. `_stand_in` is written first and stands in for whatever directory was in
## force before a redirect — the shipped default, on a real run.
##
## THE TWO SAVES CARRY DIFFERENT MARKERS, and the first version of this case did not: it compared
## the stand-in file byte-for-byte against a copy taken before the second save, and a plant that
## ignored the redirect entirely PASSED it. Both writes landed on the same path inside the same
## second, and `saved_utc` is second-resolution while `playtime_seconds` snaps to a tenth — so
## the overwrite was byte-identical to what it overwrote. A distinguishable payload is what makes
## the claim testable rather than usually-true. Gotcha 70's shape, in a fresh costume.
func _a_write_while_redirected_leaves_the_previous_directory_untouched() -> void:
	SaveSystem.save_dir = _stand_in
	SaveSystem.register(PROBE, _probe_collect, _probe_apply, 1)
	_marker = "stand_in"
	equal("a save into the stand-in succeeds", SaveSystem.save_to_slot(SLOT), OK)
	var before: String = SaveSystem.slot_path(SLOT)
	equal("and the file is there", FileAccess.file_exists(before), true)

	_marker = "redirected"
	SaveFixture.activate()
	equal("a save while redirected succeeds too", SaveSystem.save_to_slot(SLOT), OK)
	equal("and lands in the scratch directory",
			FileAccess.file_exists(SaveSystem.slot_path(SLOT)), true)
	equal("the scratch file carries the second marker",
			FileAccess.get_file_as_string(SaveSystem.slot_path(SLOT)).contains("redirected"), true)
	equal("while the file in the previous directory still carries the first",
			FileAccess.get_file_as_string(before).contains("stand_in"), true)
	equal("and was not overwritten by the second",
			FileAccess.get_file_as_string(before).contains("redirected"), false)
	SaveSystem.unregister(PROBE)
	_erase(_stand_in)


func _deactivating_restores_the_default_and_empties_the_scratch() -> void:
	SaveFixture.deactivate()
	equal("deactivate restores the shipped default",
			SaveSystem.save_dir, SaveSystem.DEFAULT_SAVE_DIR)
	equal("and says so", SaveFixture.is_active(), false)
	equal("and left nothing behind in the scratch directory",
			DirAccess.get_files_at(SaveFixture.root()).size(), 0)


func _erase(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _probe_collect() -> Dictionary:
	return {"marker": _marker}


func _probe_apply(_data: Dictionary, _from: int) -> void:
	pass
