extends TestCase
## What the save loader does with a file it cannot trust, and the one path it CANNOT REACH.
##
## WHY THIS IS SEPARATE FROM `core_test.gd`. That case owns the save ROUND TRIP — write, read
## back, restore. This one owns the refusals, and they are a different question: not "does a good
## save survive" but "what happens to a bad one". `core_test.gd` asserted exactly one of them (an
## empty slot) and nothing in the suite had ever written a MALFORMED save file, so every OTHER
## refusal in `load_from_slot`, and both of `_migrate`'s, were carried by review alone.
## Split by QUESTION, on T5.7's precedent.
##
## ONE BAD SECTION MUST NOT COST THE WHOLE FILE, and three blocks below are about that line. A
## corrupt envelope is refused outright; a corrupt SECTION is logged and skipped while the rest of
## the save loads, because the difference between those two is the difference between a player
## losing a setting and a player losing forty hours.
##
## THE ONE THAT IS NOT A TEST OF BEHAVIOUR. `_migrate`'s success path is UNREACHABLE at
## `SCHEMA_VERSION == 1`, and that is arithmetic rather than an opinion: it is called only when
## `version != 1`, and it then refuses `<= 0` and `> 1` — and no integer is all three of not-one,
## above-zero and at-most-one. So its "Migrated save from v%d to v%d" line cannot print for any
## input a file can contain. `_the_migration_path_has_no_reachable_success_case()` asserts the
## boundary exhaustively AND pins `SCHEMA_VERSION`, so the day someone ships v2 this case fails
## and says what to write. An unreachable path is not a bug — but `SYSTEMS_INVENTORY.md` calling
## migration DONE was describing a mechanism nothing can enter.
##
## THE SAVE DIRECTORY IS A SCRATCH ONE, as of T5.22. It was the developer's real save directory
## until then, because `SaveSystem.SAVE_DIR` was a `const` with no redirect — the one content
## root `Fixtures` could not repoint. `SaveFixture.activate()` now points the store at
## `user://test_saves` for the whole case and the runner points it back. This case still deletes
## what it writes on every path and still uses a slot of its own: the redirect removes the
## consequence of a leftover file, not the reason not to leave one.
##
## A SECTION FROM A NEWER BUILD IS REFUSED, as of T6.1, and it was not before. The envelope had
## that guard in `_migrate`; the section level had no twin, so a section a newer build wrote was
## handed, differently shaped, to an applier that believed it current. The probe below registers
## at `PROBE_VERSION`, and a section one past it must leave the probe at its defaults.
##
## AND THE SUITE'S FIRST WORKED MIGRATION, which is the model a game copies. `_probe_apply` is a
## participant whose format changed at v2 — `old_key` became `new_key` — and it upgrades a v1
## payload in place before reading it. See `docs/UPGRADING.md` § 4.
##
## OWNS: assertions about a save file the loader must refuse, partially skip, or migrate.
## MUST NOT: assert the round trip (that is `core_test.gd`), or name authored content.

const FIXED: int = 26
const PROBE: StringName = &"recovery_probe"
## The probe's CURRENT section version: its format changed once, at v2. A section stored at v1 is
## migrated, at v2 is read as it is, and at v3 was written by a build this one has never seen.
const PROBE_VERSION: int = 2
## What the probe holds when nothing was applied. The refusal asserts it is still this.
const UNSET: String = "unset"
## Two below `MAX_SLOTS`, so it cannot collide with `core_test.gd`'s `MAX_SLOTS - 1`.
const SLOT: int = SaveSystem.MAX_SLOTS - 2

## Counts applier calls. The skip blocks assert this stays at zero, because "the load returned OK"
## and "the section was applied" are different claims — and when the question is whether a
## malformed section was skipped, only the second one answers it.
var _applied: int = 0
## The probe's one piece of state, read from `new_key` after any migration.
var _value: String = UNSET


func run() -> void:
	plan(FIXED)
	# Every block below writes a REAL file to assert what the loader does with it. Redirected so
	# that file lands in a scratch directory rather than the developer's own saves; the runner
	# deactivates unconditionally afterwards.
	SaveFixture.activate()
	_a_file_that_is_not_json_is_refused()
	_a_save_with_no_version_field_is_refused()
	_a_save_from_a_newer_build_is_refused()
	_a_section_that_is_not_a_dictionary_is_skipped_and_the_rest_loads()
	_a_section_predating_versioning_is_skipped_and_the_rest_loads()
	_a_section_that_is_absent_leaves_its_system_at_defaults()
	_a_section_from_a_newer_build_is_refused_and_keeps_defaults()
	_a_section_at_the_registered_version_is_applied_as_it_is()
	_an_older_section_is_migrated_before_it_is_read()
	_the_migration_path_has_no_reachable_success_case()


## The shape a half-written file, a truncated copy or a disk error leaves behind.
func _a_file_that_is_not_json_is_refused() -> void:
	_arm("this is not json {{{")
	equal("a file that is not JSON is refused as corrupt",
			SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	equal("and nothing was applied from it", _applied, 0)
	_disarm()


## A missing `version` reads as 0 through `DictRead`, which is not `SCHEMA_VERSION`, so it reaches
## `_migrate` and is refused there rather than being quietly assumed to be current.
func _a_save_with_no_version_field_is_refused() -> void:
	_arm('{"sections":{}}')
	equal("a save with no version field is refused",
			SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	equal("and nothing was applied from it", _applied, 0)
	_disarm()


## What a player hits by copying a save back from a machine running a newer build. Refused rather
## than attempted, because a forward migration cannot be written in advance.
func _a_save_from_a_newer_build_is_refused() -> void:
	_arm('{"version":99,"sections":{}}')
	equal("a save from a newer build is refused",
			SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	equal("and nothing was applied from it", _applied, 0)
	_disarm()


func _a_section_that_is_not_a_dictionary_is_skipped_and_the_rest_loads() -> void:
	_arm('{"version":1,"sections":{"recovery_probe":"not a dictionary"}}')
	equal("a section that is not a Dictionary does not fail the load",
			SaveSystem.load_from_slot(SLOT), OK)
	equal("and that section's applier was never called", _applied, 0)
	_disarm()


## A section written before per-section versioning existed. Skipped LOUDLY rather than handed to an
## applier that cannot recognise its shape — the loader's own comment says why.
func _a_section_predating_versioning_is_skipped_and_the_rest_loads() -> void:
	_arm('{"version":1,"sections":{"recovery_probe":{"data":{"kept":true}}}}')
	equal("a section with no per-section version does not fail the load",
			SaveSystem.load_from_slot(SLOT), OK)
	equal("and its applier was never called, so it keeps its defaults", _applied, 0)
	_disarm()


## The ordinary forward-compatibility case: a save written before this system existed at all. For
## that one system it must be indistinguishable from a new game.
func _a_section_that_is_absent_leaves_its_system_at_defaults() -> void:
	_arm('{"version":1,"sections":{}}')
	equal("a save with no section for a registered system still loads",
			SaveSystem.load_from_slot(SLOT), OK)
	equal("and that system's applier was never called", _applied, 0)
	_disarm()


## The section-level twin of `_a_save_from_a_newer_build_is_refused`. Not a whole-file refusal:
## ONE BAD SECTION MUST NOT COST THE WHOLE FILE, so the load still returns OK and only this
## participant is left where a new game would have it.
func _a_section_from_a_newer_build_is_refused_and_keeps_defaults() -> void:
	_arm('{"version":1,"sections":{"recovery_probe":{"v":3,"data":{"new_key":"from the future"}}}}')
	equal("a section from a newer build does not fail the whole load",
			SaveSystem.load_from_slot(SLOT), OK)
	equal("but its applier was never called", _applied, 0)
	equal("so the probe keeps its defaults", _value, UNSET)
	_disarm()


## The other side of that boundary, so the refusal above cannot pass by refusing everything.
func _a_section_at_the_registered_version_is_applied_as_it_is() -> void:
	_arm('{"version":1,"sections":{"recovery_probe":{"v":2,"data":{"new_key":"current"}}}}')
	equal("a section at the registered version loads", SaveSystem.load_from_slot(SLOT), OK)
	equal("its applier ran once", _applied, 1)
	equal("and read it without migrating", _value, "current")
	_disarm()


## THE WORKED MIGRATION. A v1 payload spells the field `old_key`; the applier renames it before
## reading, so the value survives a format change the player never saw.
func _an_older_section_is_migrated_before_it_is_read() -> void:
	_arm('{"version":1,"sections":{"recovery_probe":{"v":1,"data":{"old_key":"migrated"}}}}')
	equal("an older section loads", SaveSystem.load_from_slot(SLOT), OK)
	equal("its applier ran once", _applied, 1)
	equal("and read the value through the renamed field", _value, "migrated")
	_disarm()


## THE BOUNDARY, EXHAUSTIVELY, AND THE PIN THAT MAKES IT EXPIRE. Every integer a `version` field
## can hold falls into exactly one of three buckets and only the middle one loads, which is what
## makes `_migrate`'s success path unreachable rather than merely untested.
func _the_migration_path_has_no_reachable_success_case() -> void:
	_arm('{"version":-1,"sections":{}}')
	equal("a negative version is refused", SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	_disarm()
	_arm('{"version":0,"sections":{}}')
	equal("version zero is refused", SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	_disarm()
	_arm('{"version":2,"sections":{}}')
	equal("one past the schema is refused", SaveSystem.load_from_slot(SLOT), ERR_FILE_CORRUPT)
	_disarm()
	_arm('{"version":1,"sections":{}}')
	equal("only the current schema loads, and it never enters _migrate at all",
			SaveSystem.load_from_slot(SLOT), OK)
	_disarm()
	## WHEN THIS FAILS, WRITE THE MIGRATION TEST. A v2 schema gives `_migrate` its first reachable
	## success case, and the block above stops being exhaustive the moment one exists.
	equal("SCHEMA_VERSION is still 1, so _migrate has no reachable success path",
			SaveSystem.SCHEMA_VERSION, 1)


## Register the probe and plant `text` as the slot's raw contents. Registered fresh each time so
## `_applied` counts one block's calls rather than the whole case's.
func _arm(text: String) -> void:
	_applied = 0
	_value = UNSET
	SaveSystem.register(PROBE, _probe_collect, _probe_apply, PROBE_VERSION)
	var file: FileAccess = FileAccess.open(SaveSystem.slot_path(SLOT), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Unregistered and DELETED on every path including the failing ones: a slot left behind would be
## read by the next block, and a participant left registered would answer it too.
func _disarm() -> void:
	SaveSystem.unregister(PROBE)
	if SaveSystem.has_slot(SLOT):
		SaveSystem.delete_slot(SLOT)


func _probe_collect() -> Dictionary:
	return {"new_key": _value}


## COPY THIS SHAPE. One `if` per past version, each upgrading the payload IN PLACE to the next
## shape and falling through, then one read of the current shape. The loader has already refused
## a `from_version` above `PROBE_VERSION`, so no applier needs its own guard against the future.
func _probe_apply(data: Dictionary, from_version: int) -> void:
	_applied += 1
	if from_version == 1:
		data["new_key"] = data.get("old_key", UNSET)
		data.erase("old_key")
	_value = DictRead.get_string(data, "new_key", UNSET)
