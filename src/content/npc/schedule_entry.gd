class_name ScheduleEntry
extends Resource
## One block of an NPC's day: from this hour, be at that waypoint, doing this.
##
## A WAYPOINT MUST BE SOMEWHERE THE BODY CAN WALK, WHICH IS NOT THE SAME AS SOMEWHERE THE
## NAVMESH COVERS. A NavigationMesh bakes `agent_max_climb` into the walkable surface, so it
## will happily bridge a knee-high step - but `CharacterBody3D.move_and_slide()` has no step-up
## at all, so the body walks into the riser and stops while the agent insists it has not
## arrived. This game has no jumping and authored vertical movement (ClimbPoint), so the climb
## limit is kept BELOW anything the body cannot manage and waypoints sit on the ground.
##
## IT NAMES A WAYPOINT, NOT A POSITION. A schedule that stored coordinates would be authored
## against one area's geometry and silently wrong the moment a bench moved, and it could not be
## reused by a second NPC or a second area at all. A name is resolved against the area's
## `Waypoints/` node at runtime, so moving the marker moves everyone who goes there.
##
## THERE IS NO `until_hour`, deliberately. An entry runs until the next one begins, and the last
## entry wraps to the first, so a day is always completely covered and two entries cannot
## disagree about who owns 14:00. The cost is that a gap in the day cannot be expressed - which
## is correct, because an NPC is always somewhere.
##
## AND THAT INVARIANT IS NOW GUARDED RATHER THAN MERELY CLAIMED, WHICH IS T5.33. Adding
## `on_day_of_cycle` in T5.32 made it violable by authored data for the first time: a schedule of
## ONLY day-specific entries answers nothing on any other day - measured at 24 hours of 24 - and
## `problems()` was silent, so `check_content` passed and the NPC simply stood wherever it was.
## `NpcSchedule.problems` now requires at least one entry at `-1`, which is both necessary and
## sufficient for total coverage and needs no autoload to check. The lesson is the general one:
## an invariant a header asserts and no gate enforces is a comment, and the row that adds a new
## degree of freedom is the row that has to go back and ask what the old promise rested on.
##
## AND UNTIL T5.32 THERE WAS NO `on_day_of_cycle`, WHICH MEANT EVERY NPC REPEATED ONE IDENTICAL
## DAY FOREVER. `from_hour` was the entry's whole address and `entry_for_hour` was the whole
## lookup, so a market day — or any weekly rhythm at all — was not merely unauthored, it was
## inexpressible. The fix is one more field on the address, and the DEFAULT IS WHAT MAKES IT SAFE:
## `-1` means every day, so every `.tres` authored before this field existed keeps resolving
## exactly as it did, with no edit and no migration. That is the same append-only discipline
## `GameEnums` runs on, for the same reason — these numbers live inside authored files.
##
## OWNS: one block of one schedule.
## MUST NOT: know which NPC uses it, resolve its own waypoint, or touch an autoload -
## tools/check_content.gd loads this class under `--headless --script`, where autoload
## identifiers do not resolve, so one Log call here would break the build gate.

## The hour this block begins, 0 to 23. It runs until the next entry's hour.
@export_range(0, 23, 1) var from_hour: int = 0
## Which day of `Clock.days_per_cycle` this block runs on, or `-1` for every day. A day-specific
## entry BEATS an every-day entry at the same hour, which is how a market day is authored: leave
## the ordinary block alone and add one entry beside it.
##
## THE UPPER BOUND IS GENEROUS RATHER THAN DERIVED, AND NOTHING VALIDATES AGAINST IT. This class
## MUST NOT touch an autoload — `check_content.gd` loads it where `Clock` does not resolve — and
## neither may `NpcSchedule`, so no validator in this layer can ask what the cycle length is. A
## day past the end of the cycle therefore parses, loads, and is simply an entry that never runs.
## That is a stated cost, not an oversight: the alternative is `content` reaching up into
## `systems` for a number, which is the dependency `check_layers.gd` exists to refuse. What IS
## checked below is the one case that needs no autoload — a value below `-1`, which is not "every
## day" and not a day either.
@export_range(-1, 30, 1) var on_day_of_cycle: int = -1
## Name of a Marker3D under the area's `Waypoints/` node.
@export var waypoint: StringName = &""
## What to do on arrival.
@export var activity: GameEnums.NpcActivity = GameEnums.NpcActivity.STAND


func activity_name() -> String:
	var names: Array = GameEnums.NpcActivity.keys()
	var raw: String = names[activity]
	return raw


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if waypoint == &"":
		found.append("%s has an entry at %02d:00 with no waypoint" % [context, from_hour])
	if on_day_of_cycle < -1:
		found.append("%s has an entry at %02d:00 on day %d, which is neither -1 nor a day" % [
			context, from_hour, on_day_of_cycle,
		])
	return found
