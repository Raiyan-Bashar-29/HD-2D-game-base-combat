extends TestCase
## Schedules: which block covers which hour, and whether a whereabouts survives a save.
##
## WHAT IS DELIBERATELY NOT HERE: walking. A navmesh needs physics frames and `TestCase.run()`
## is synchronous, so no assertion here can watch an NPC cross an area. That is measured by
## a RUN instead — `--npc-day` in `dev_capture.gd` steps the clock through a whole day and
## reports where each NPC actually ends up, and `--npc-storm=30` measures what a crowd costs.
##
## What IS here is everything decidable without a frame, and the part most likely to rot: the
## hour-to-block lookup, which is pure arithmetic over authored data and has exactly the shape
## that silently returns the wrong answer at 03:00 six months from now.
##
## FIXTURES, NOT THE DEMO. The arithmetic runs on `FixtureContent`'s two-block timetable. The
## one block that genuinely needs a game — every waypoint an authored schedule names must exist
## in some authored area — is gated on the demo and skipped loudly without it.
##
## OWNS: assertions about NpcSchedule, ScheduleEntry, ScheduleDb and persisted whereabouts.
## MUST NOT: assert anything about pathing, movement or navmesh baking.

const FIXTURE: StringName = FixtureContent.SCHEDULE

var _schedule: NpcSchedule = null


func run() -> void:
	plan(84)
	_authored_waypoints_exist_somewhere()
	_set_up()
	_the_catalogue_is_sound()
	_every_hour_of_the_day_has_an_owner()
	_the_night_shift_wraps_past_midnight()
	_a_market_day_resolves_differently()
	_the_validator_tells_a_market_day_from_a_collision()
	_every_schedule_must_cover_every_day()
	_whereabouts_survive_a_save()
	_tear_down()


func _set_up() -> void:
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Fixtures.activate()
	_schedule = ScheduleDb.schedule(FIXTURE)


func _the_catalogue_is_sound() -> void:
	equal("the fixture schedule exists", ScheduleDb.has(FIXTURE), true)
	equal("and the catalogue is clean", ScheduleDb.problems().size(), 0)
	equal("its id survived the round trip", _schedule.id, FIXTURE)
	equal("it has entries", _schedule.entries.size() > 0, true)
	equal("an invented schedule is null", ScheduleDb.schedule(&"schedule/nobody"), null)
	equal("and reports as absent", ScheduleDb.has(&"schedule/nobody"), false)


## THE HEADLINE. Every hour must resolve to some block, including the hours before the first one
## begins. A gap would mean an NPC with no instructions, which in practice means an NPC standing
## wherever it happened to be when the gap opened.
func _every_hour_of_the_day_has_an_owner() -> void:
	for hour: int in 24:
		var entry: ScheduleEntry = _schedule.entry_for_hour(hour)
		equal("%02d:00 has a block" % hour, entry != null, true)
		if entry != null:
			equal("%02d:00 names a waypoint" % hour, entry.waypoint != &"", true)


## A day starting at 06:00 means 02:00 belongs to the LAST block of the previous day, not to the
## first block of this one. Getting this backwards puts every NPC at its morning post all night,
## which reads as a game where nobody sleeps.
func _the_night_shift_wraps_past_midnight() -> void:
	var latest: ScheduleEntry = null
	for entry: ScheduleEntry in _schedule.entries:
		if latest == null or entry.from_hour > latest.from_hour:
			latest = entry
	var first: ScheduleEntry = null
	for entry: ScheduleEntry in _schedule.entries:
		if first == null or entry.from_hour < first.from_hour:
			first = entry

	equal("before the day starts, the last block still runs",
		_schedule.entry_for_hour(first.from_hour - 1).waypoint, latest.waypoint)
	equal("and so does midnight", _schedule.entry_for_hour(0).waypoint, latest.waypoint)
	equal("the day's first hour switches over",
		_schedule.entry_for_hour(first.from_hour).waypoint, first.waypoint)
	equal("an hour inside a block belongs to that block",
		_schedule.entry_for_hour(latest.from_hour + 1).waypoint, latest.waypoint)
	# Out-of-range hours are clamped rather than crashing: a caller passing 24 has a bug, but a
	# crash in an NPC's daily update is a worse way to find out about it.
	equal("hour 99 is clamped", _schedule.entry_for_hour(99).waypoint, latest.waypoint)
	equal("and so is -5", _schedule.entry_for_hour(-5).waypoint, latest.waypoint)


## THE T5.32 HEADLINE: ONE HOUR, TWO ANSWERS, DECIDED BY THE DAY. Before this, `from_hour` was an
## entry's whole address and `entry_for_hour(hour)` was the whole lookup, so every NPC in every
## game repeated one identical day forever and a weekly rhythm was not unauthored but
## INEXPRESSIBLE. The fixture is built to make that failure visible rather than arguable: its
## market-day block COLLIDES with the ordinary morning block on the hour, so the hour cannot
## separate them and only the day can. Ignore the day argument in the lookup and the first three
## assertions below go red together — which is this row's plant, run and recorded.
func _a_market_day_resolves_differently() -> void:
	var ordinary: ScheduleEntry = _schedule.entry_for_hour(
		FixtureContent.MORNING_HOUR, FixtureContent.ORDINARY_DAY)
	var market: ScheduleEntry = _schedule.entry_for_hour(
		FixtureContent.MORNING_HOUR, FixtureContent.MARKET_DAY)
	equal("an ordinary day gets the every-day block",
		ordinary.waypoint, FixtureContent.MORNING_WAYPOINT)
	equal("the market day gets the block authored for the market day",
		market.waypoint, FixtureContent.EVENING_WAYPOINT)
	equal("so one hour resolves to two different places on two days",
		ordinary.waypoint != market.waypoint, true)

	# The other half of the tiebreak, and the half a naive "day-specific wins" would break: an
	# every-day block must still run on the market day at every hour the market day says nothing
	# about. Otherwise authoring one special morning would silently blank the rest of that day.
	equal("an every-day block still runs on the market day",
		_schedule.entry_for_hour(FixtureContent.EVENING_HOUR,
			FixtureContent.MARKET_DAY).waypoint, FixtureContent.EVENING_WAYPOINT)
	# And the default must mean "no particular day", NOT "any day". If a day-specific block leaked
	# into the day-agnostic lookup, every caller written before this argument existed would start
	# seeing a market day it never asked about - the defect, arriving through the fix.
	equal("and the market block does not leak into a day-agnostic lookup",
		_schedule.entry_for_hour(FixtureContent.MORNING_HOUR).waypoint,
		FixtureContent.MORNING_WAYPOINT)
	# The wrap and the clamp are the pre-existing invariants, re-asked on a day that now has an
	# extra entry in it: adding a block must not open a gap in the hours around it.
	equal("midnight on the market day still wraps to the previous block",
		_schedule.entry_for_hour(0, FixtureContent.MARKET_DAY).waypoint,
		FixtureContent.EVENING_WAYPOINT)
	equal("and hour 99 is still clamped on the market day",
		_schedule.entry_for_hour(99, FixtureContent.MARKET_DAY) != null, true)


## THE VALIDATOR HAD TO CHANGE WITH THE LOOKUP, and getting that wrong would have been the
## quietest way to break this: `problems()` keyed its duplicate check on the hour alone, so the
## very fixture proving the feature works would have been reported as malformed content and
## `check_content.gd` would have failed the build on correctly authored data. Keyed on the PAIR, a
## market day is legal and a genuine collision - two entries agreeing on hour AND day - still is
## not, because that one is ambiguous in exactly the old array-order way.
func _the_validator_tells_a_market_day_from_a_collision() -> void:
	equal("two entries sharing an hour but differing by day are not a defect",
		_schedule.problems().size(), 0)

	var both: Array[ScheduleEntry] = []
	both.append(_bare_entry(FixtureContent.MORNING_HOUR, FixtureContent.MARKET_DAY))
	both.append(_bare_entry(FixtureContent.MORNING_HOUR, FixtureContent.MARKET_DAY))
	var clashing := NpcSchedule.new()
	clashing.id = FixtureContent.SCHEDULE
	clashing.entries = both
	# Counted by phrase, not by total: this schedule also has no every-day entry, which T5.33
	# made a problem of its own, and asserting `size() == 1` would tie this assertion to how
	# many OTHER rules the same resource happens to break.
	equal("but two agreeing on both is still reported",
		_problems_mentioning(clashing, "two entries starting at"), 1)
	equal("and it names the day, so an author can find which of the two blocks to move",
		_problems_mentioning(clashing, "day %d of the cycle" % FixtureContent.MARKET_DAY), 1)

	var below: Array[ScheduleEntry] = []
	below.append(_bare_entry(FixtureContent.MORNING_HOUR, -2))
	var nonsense := NpcSchedule.new()
	nonsense.id = FixtureContent.SCHEDULE
	nonsense.entries = below
	# Two problems now, not one: the nonsense day AND the missing every-day entry below.
	equal("a day below -1 is neither every day nor a day, and is reported",
		_problems_mentioning(nonsense, "neither -1 nor a day"), 1)


## THE COVERAGE GUARANTEE, WHICH T5.32 BROKE AND AN AUDIT CAUGHT RATHER THAN A GATE.
##
## `schedule_entry.gd` promises a day is ALWAYS completely covered, "because an NPC is always
## somewhere", and before `on_day_of_cycle` existed that was structurally true: any entry applied
## on any day, so the wrap-to-last-block fallback could never come up empty. A day-specific entry
## broke it, and nothing noticed — a schedule of only day-specific blocks answered NOTHING on any
## other day while `problems()` returned zero, so `check_content` passed on content that strands
## an NPC. `NpcBrain.decide_for_hour` returns early on a null entry, so the NPC keeps standing
## wherever it happened to be: the "reads as random" failure that header exists to prevent.
##
## ONE ENTRY AT `-1` IS NECESSARY AND SUFFICIENT, which is why that is the rule rather than
## "every day of the cycle is covered". The stronger rule would need `Clock.days_per_cycle`, and
## `content` may not touch an autoload. This asserts both halves: that the rule is enforced, and
## that satisfying it really does restore total coverage.
func _every_schedule_must_cover_every_day() -> void:
	var only_specific: Array[ScheduleEntry] = []
	only_specific.append(_bare_entry(FixtureContent.MORNING_HOUR, FixtureContent.MARKET_DAY))
	only_specific.append(_bare_entry(FixtureContent.EVENING_HOUR, FixtureContent.MARKET_DAY))
	var stranded := NpcSchedule.new()
	stranded.id = FixtureContent.SCHEDULE
	stranded.entries = only_specific

	# The consequence first, so the assertion below is guarding a measured failure and not a rule
	# for its own sake: on any day the schedule does not name, EVERY hour comes back null.
	var unanswered: int = 0
	for hour: int in 24:
		if stranded.entry_for_hour(hour, FixtureContent.ORDINARY_DAY) == null:
			unanswered += 1
	equal("with no every-day entry, every hour of an unnamed day answers nothing",
		unanswered, 24)
	equal("and that is reported as a problem rather than passing check_content",
		_problems_mentioning(stranded, "no every-day entry"), 1)

	# Adding one every-day entry restores total coverage, on the named day and every other.
	var repaired: Array[ScheduleEntry] = only_specific.duplicate()
	repaired.append(_bare_entry(FixtureContent.MORNING_HOUR, -1))
	stranded.entries = repaired
	equal("one every-day entry clears the problem", stranded.problems().size(), 0)
	var still_null: int = 0
	for hour: int in 24:
		if stranded.entry_for_hour(hour, FixtureContent.ORDINARY_DAY) == null:
			still_null += 1
		if stranded.entry_for_hour(hour, FixtureContent.MARKET_DAY) == null:
			still_null += 1
	equal("and no hour on any day answers nothing again", still_null, 0)

	# The fixture is the positive control: it has every-day entries, so it was never affected.
	equal("the fixture schedule already satisfied the rule",
		_problems_mentioning(_schedule, "no every-day entry"), 0)


## Problems whose text contains a phrase. Counted rather than totalled, because a malformed
## fixture legitimately reports several things at once and a bare `size()` would make each
## assertion depend on how many OTHER rules the same resource happens to break.
func _problems_mentioning(sched: NpcSchedule, phrase: String) -> int:
	var n: int = 0
	for problem: String in sched.problems():
		if problem.contains(phrase):
			n += 1
	return n


## An entry with a waypoint, so `ScheduleEntry.problems` has nothing of its own to say and the
## count above measures only what this function is about.
func _bare_entry(from_hour: int, on_day_of_cycle: int) -> ScheduleEntry:
	var entry := ScheduleEntry.new()
	entry.from_hour = from_hour
	entry.on_day_of_cycle = on_day_of_cycle
	entry.waypoint = FixtureContent.MORNING_WAYPOINT
	return entry


## A schedule names waypoints; the AREA owns where they are. A name that resolves to nothing is
## an NPC that never leaves, and it is invisible until someone watches for an hour. This is the
## one thing here that only a real game can be asked: it needs authored schedules AND the areas
## they walk in, so it is asserted across whatever areas exist rather than against a named one.
func _authored_waypoints_exist_somewhere() -> void:
	var areas: Array[StringName] = Fixtures.area_ids()
	ScheduleDb.rescan()
	if areas.is_empty() or ScheduleDb.count() == 0:
		skip("authored waypoints exist in an authored area", "no areas or no schedules", 1)
		return
	var missing: PackedStringArray = PackedStringArray()
	var known: Dictionary[StringName, bool] = _waypoint_names(areas)
	for schedule_id: StringName in ScheduleDb.all():
		for entry: ScheduleEntry in ScheduleDb.schedule(schedule_id).entries:
			if entry != null and not known.has(entry.waypoint):
				missing.append("%s names '%s'" % [schedule_id, entry.waypoint])
	equal("every authored waypoint exists: %s" % str(missing), missing.size(), 0)


## Every Node3D under any area's Waypoints node. Instantiated without entering the tree, so
## nothing readies, and freed immediately.
func _waypoint_names(areas: Array[StringName]) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	for area_id: StringName in areas:
		var packed: PackedScene = load(Director.area_path(area_id)) as PackedScene
		if packed == null:
			continue
		var area: Node = packed.instantiate()
		var markers: Node = area.get_node_or_null(^"Waypoints")
		if markers != null:
			for marker: Node in markers.get_children():
				if marker is Node3D:
					out[StringName(marker.name)] = true
		area.free()
	return out


## An NPC's whereabouts ride the save machinery that already exists, through PersistentState and
## therefore through Flags. Asserted at the storage level because the walking half needs frames:
## what matters here is that the key is namespaced per area and per object like everything else,
## so two NPCs cannot overwrite each other and a second area cannot overwrite the first.
func _whereabouts_survive_a_save() -> void:
	var first: StringName = &"obj/area_one/walker/waypoint"
	var second: StringName = &"obj/area_two/walker/waypoint"
	Flags.set_flag(first, "post_a")
	Flags.set_flag(second, "post_b")
	equal("a whereabouts is stored", Flags.get_string(first), "post_a")
	equal("and the same NPC in another area is separate", Flags.get_string(second), "post_b")

	var slot: int = 3
	equal("the save succeeds", SaveSystem.save_to_slot(slot), OK)
	Flags.set_flag(first, "somewhere_else")
	equal("the value is destroyed before reloading", Flags.get_string(first), "somewhere_else")
	equal("the load succeeds", SaveSystem.load_from_slot(slot), OK)
	equal("and the whereabouts came back", Flags.get_string(first), "post_a")
	equal("both of them", Flags.get_string(second), "post_b")
	SaveSystem.delete_slot(slot)


func _tear_down() -> void:
	Flags.erase_flag(&"obj/area_one/walker/waypoint")
	Flags.erase_flag(&"obj/area_two/walker/waypoint")
	ScheduleDb.rescan()
	_schedule = null
