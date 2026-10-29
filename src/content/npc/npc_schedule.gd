class_name NpcSchedule
extends ContentEntry
## Where one NPC is at every hour of the day, as authored data.
##
## THE ID IS THE FILE NAME, exactly as for items and conversations: `data/schedules/keeper.tres`
## must declare `id = &"schedule/keeper"`. Third content type, third time the same rule, and it
## is the same rule for the same reason - a copy-paste slip becomes a named startup failure
## rather than an NPC that silently never goes anywhere.
##
## ENTRIES ARE SORTED ON LOOKUP, NOT ON LOAD. Authored order is whatever the writer found
## convenient; `entry_for_hour` does not care, because it picks the entry with the greatest
## `from_hour` not exceeding the hour asked for, and falls back to the LAST entry of the day
## when the hour is earlier than every block. That fallback is what makes a night shift work:
## an NPC whose day starts at 06:00 is, at 02:00, still doing whatever it was doing at 22:00.
##
## AND A BLOCK IS ADDRESSED BY AN HOUR *AND* A DAY OF THE CYCLE, WHICH IS T5.32. Before it, the
## hour was the whole address, so this class could describe exactly one day and every NPC in a
## game repeated it forever. `on_day_of_cycle` of `-1` means every day and is the default, so an
## every-day schedule is written exactly as it always was; a day-specific entry BEATS an every-day
## entry at the same hour, which is the whole authoring gesture — a market day is one entry added
## beside the ordinary block, not a second schedule.
##
## THE DAY ARGUMENT DEFAULTS TO `-1` FOR THE SAME REASON THE FIELD DOES, and the default is the
## careful half. `-1` asked of the lookup means "no particular day", and only every-day entries
## are considered — so a caller written before this argument existed gets the answer it always
## got, and a game that never mentions a cycle never sees one. What it does NOT mean is "any day":
## that reading would have made a day-specific block leak into every day, which is the defect this
## whole change exists to make expressible in the first place.
##
## EVERY SCHEDULE MUST CARRY AT LEAST ONE EVERY-DAY ENTRY, and `problems()` enforces it since
## T5.33. That is not a style rule: one `-1` entry is exactly what makes the coverage promise in
## `schedule_entry.gd` true, because `_applies_on` admits it whatever day is asked, so `latest` is
## never null and this function never returns null. Without one, a schedule of only day-specific
## blocks answers nothing on any other day and the NPC stands where it last was.
##
## OWNS: the immutable schedule of one NPC, and validating its own shape.
## MUST NOT: know which NPC uses it, move anything, or touch an autoload — which is why nothing
## here validates a day against the real cycle length; `schedule_entry.gd` records that cost. The
## every-day rule above is the part of coverage that IS checkable without one.

## `id` is inherited from `ContentEntry`; for this catalogue it is `schedule/` plus this file name.
## In any order. Each runs until the next begins; the last wraps around midnight.
@export var entries: Array[ScheduleEntry] = []


## Which block covers this hour on this day of the cycle. Null only when there are no entries
## that apply at all. `on_day` of `-1` considers only every-day entries; see the header.
func entry_for_hour(hour: int, on_day: int = -1) -> ScheduleEntry:
	var wanted: int = clampi(hour, 0, 23)
	var best: ScheduleEntry = null
	var latest: ScheduleEntry = null
	for entry: ScheduleEntry in entries:
		if entry == null or not _applies_on(entry, on_day):
			continue
		if latest == null or _outranks(entry, latest):
			latest = entry
		if entry.from_hour <= wanted and (best == null or _outranks(entry, best)):
			best = entry
	# Before the first block of the day, the previous day's last block is still running.
	return best if best != null else latest


func _applies_on(entry: ScheduleEntry, on_day: int) -> bool:
	return entry.on_day_of_cycle == -1 or entry.on_day_of_cycle == on_day


## Later hour wins; at the SAME hour, the day-specific entry wins. That tiebreak is the market
## day, and it is what makes the ordinary block authorable once instead of once per day.
func _outranks(entry: ScheduleEntry, other: ScheduleEntry) -> bool:
	if entry.from_hour != other.from_hour:
		return entry.from_hour > other.from_hour
	return entry.on_day_of_cycle != -1 and other.on_day_of_cycle == -1


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if entries.is_empty():
		found.append("%s (%s) has no entries" % [resource_path, id])
	# KEYED ON THE HOUR *AND* THE DAY SINCE T5.32, because the hour alone is no longer the
	# address. Keying on the hour would report a market day as a defect - which is precisely the
	# shape this change exists to allow - while a genuine collision is two entries agreeing on
	# BOTH, and that one is still ambiguous in exactly the old way.
	var slots: Dictionary[Vector2i, bool] = {}
	var covers_every_day: bool = false
	for entry: ScheduleEntry in entries:
		if entry == null:
			found.append("%s has an empty entry slot" % id)
			continue
		var slot: Vector2i = Vector2i(entry.from_hour, entry.on_day_of_cycle)
		if slots.has(slot):
			# Two blocks claiming one hour is not a crash, but it IS ambiguous, and which one
			# wins depends on array order - exactly the kind of thing that reads as random.
			found.append("%s has two entries starting at %02d:00 on day %d of the cycle" % [
				id, entry.from_hour, entry.on_day_of_cycle,
			])
		slots[slot] = true
		if entry.on_day_of_cycle == -1:
			covers_every_day = true
		found.append_array(entry.problems(String(id)))
	# THE COVERAGE GUARANTEE, AND T5.32 BROKE IT BEFORE T5.33 PUT IT BACK. `schedule_entry.gd`
	# promises a day is ALWAYS completely covered, because an NPC is always somewhere. One
	# every-day entry is exactly what makes that true: `_applies_on` admits it whatever day is
	# asked, so `latest` is never null and `entry_for_hour` never returns null. Take the last one
	# away and a schedule of only day-specific blocks answers NOTHING on any other day - measured
	# at 24 hours of 24 - while `NpcBrain.decide_for_hour` returns early on null and leaves the
	# NPC wherever it happened to be. That is the "reads as random" failure the entry header
	# exists to prevent, and it needs no autoload to detect: one entry at `-1` is both necessary
	# and sufficient, so this is the check the `content` layer can actually make.
	if not entries.is_empty() and not covers_every_day:
		found.append(
			"%s has no every-day entry, so an NPC following it has no instructions at all on any "
			% id
			+ "day the schedule does not name; give one entry on_day_of_cycle = -1")
	return found
