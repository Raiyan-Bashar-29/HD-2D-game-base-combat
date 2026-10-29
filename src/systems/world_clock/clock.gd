extends Node
## The world clock. Autoload `Clock`.
##
## WHY A CLOCK IS FOUNDATIONAL
## Time is an input to lighting, NPC schedules, ambience, shop hours, weather odds and some
## interactions. If each of those keeps its own notion of "night", they drift apart. One clock
## emits the truth and everything else listens.
##
## AND WHY IT ALSO PUBLISHES ONTO THE FLAG SURFACE
## Emitting a signal serves a listener that has CODE. Authored content has none: a dialogue
## condition and a quest step both go through `FlagQuery`, which reads `Flags` and nothing else.
## So until T5.31 no authored condition in this template could mention time at all — including
## the shop hours the paragraph above names as a reason a clock is foundational. The truth still
## lives here and nowhere else; a derived copy is PUBLISHED so it can be asked about, and
## `Flags.declare_derived` keeps every key out of the save file, so the day is stored once, by
## this file, in this file's own format.
##
## OWNS: the current day, hour and minute; the rate time passes; the time-of-day phase; how many
## days pass before the calendar repeats; and publishing all of those into the `time/` namespace.
## MUST NOT: change lighting, move an NPC, play a sound, or READ a flag it published — a
## projection that is also an input is a loop. It reports time passing. What that means is the
## listener's business. This is the boundary that keeps a day/night system from quietly turning
## into the place where all world logic lives.
##
## RATE: at the default 1.0 seconds per in-game minute, a full 24-hour day takes 24 real
## minutes. That is deliberately brisk, so a play session sees several dawns.

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY

## THE DERIVED FLAG NAMESPACE THIS CLOCK OWNS, WHOLE. Declared derived in `_ready`, so nothing
## under it is written to a save; a consuming game must not put a flag of its own here.
const FLAG_PREFIX: String = "time/"
## ORDERED ints, which is why they are ints: `AT_LEAST 9` with `AT_MOST 17` is a shop's opening
## hours, and an ordering comparison on an hour means what an author expects it to mean.
const FLAG_DAY: StringName = &"time/day"
const FLAG_HOUR: StringName = &"time/hour"
## AND SO IS THE DAY OF THE CYCLE — THE ONE PLACE THIS FILE DELIBERATELY DOES NOT COPY THE PHASE.
## `_publish_phase` below argues at length for a bool-per-name, and every word of that argument is
## about a PHASE: a day wraps where an enum does not, so `AT_LEAST DUSK` holds at 00:00 and fails
## at 06:00, and equality is the only sound question to ask. A day of the cycle has neither half of
## that problem. It runs 1..`days_per_cycle` with no wrap inside the range and no enum behind it to
## be inserted into, so `EQUALS 3` is a market day and `AT_LEAST 5` is the back half of the cycle,
## and both mean what an author reading them expects. The bool-per-name shape would also have cost
## `days_per_cycle` rows in the store to answer what one ordered int answers.
const FLAG_DAY_OF_CYCLE: StringName = &"time/day_of_cycle"
## A phase is published as ONE BOOL UNDER ITS OWN NAME, never as an ordinal. `_publish_phase`
## carries the two measurements that settled that, and they are the reason this is not
## `time/phase` holding a number.
const PHASE_PREFIX: String = "time/phase/"

## THERE IS DELIBERATELY NO `time/minute`. A minute is a CONTINUOUS quantity for interpolating
## something — `day_fraction` is what a lighting gradient samples — not a question an authored
## format asks; and publishing it would rewrite a flag 1,440 times a day, and announce it on
## `flag_changed` 1,440 times, to answer a question nobody put. An hour is already the
## granularity `NpcSchedule.entry_for_hour` runs on.

## Real seconds per in-game minute. Set to 0 to freeze time without pausing the game.
@export var seconds_per_minute: float = 1.0

## HOW MANY DAYS PASS BEFORE THE CALENDAR REPEATS, AND IT IS A NUMBER BECAUSE A CALENDAR IS NOT
## THIS FILE'S BUSINESS. ADR-0007 places time in the base as a template DEFAULT and a calendar in
## the game as a GAME CHOICE, and the line between the two falls exactly here: a cycle length is a
## FORMULA, so it is a default with a seam; weekday names, months, seasons and a date type are a
## game's own, so this file has none of them and grows none. A game that wants a ten-day cycle
## sets this and authors against `time/day_of_cycle`; a game that wants no rhythm at all leaves it
## alone and never asks the flag.
##
## SET IT FROM CODE AT STARTUP, exactly as `seconds_per_minute` is set: these are exports on a
## SCRIPT autoload, and Godot exposes no inspector for those. There is deliberately no setter that
## republishes. `Director.start_new_game` emits `game_started` and `_republish` is connected to it,
## so a value set before a game begins is published when it begins, and after that any tick
## republishes within one in-game minute. A setter would have spent four lines closing a window no
## caller can observe, in a file with three lines of budget left.
@export var days_per_cycle: int = 7

var day: int = 1
var hour: int = 6
var minute: int = 0
var paused: bool = false

var _accumulator: float = 0.0
var _phase: GameEnums.DayPhase = GameEnums.DayPhase.DAWN


func _ready() -> void:
	_phase = phase_for_hour(hour)
	SaveSystem.register(&"clock", _collect_save, _apply_save)
	Flags.declare_derived(FLAG_PREFIX)
	# THE TWO MOMENTS THAT WIPE THE STORE FROM UNDER THE PROJECTION, both subscribed for the
	# reason `inventory.gd` records against the same seam. `Director.start_new_game` calls
	# `Flags.clear_all()` and THEN emits `game_started`. And `Flags._apply_save` clears a store
	# whose derived keys are deliberately absent from the file it restores from — participant
	# order decides whether our own `_apply_save` published before or after that wipe, so the
	# answer must not depend on it: `game_loaded` fires once, after every section is applied.
	Events.game_started.connect(_republish)
	Events.game_loaded.connect(_on_game_loaded)
	_republish()
	Log.info("clock", "Started at day %d, %02d:%02d (%s)" % [day, hour, minute, phase_name()])


func _process(delta: float) -> void:
	if paused or seconds_per_minute <= 0.0:
		return
	_accumulator += delta
	while _accumulator >= seconds_per_minute:
		_accumulator -= seconds_per_minute
		_tick_minute()


## Total in-game minutes elapsed today. Useful for interpolating anything continuous.
func minutes_today() -> int:
	return hour * MINUTES_PER_HOUR + minute


## Progress through the day as 0.0 at midnight to 1.0 at the next midnight.
## This is what a lighting gradient should sample.
func day_fraction() -> float:
	return float(minutes_today()) / float(MINUTES_PER_DAY)


func phase() -> GameEnums.DayPhase:
	return _phase


func phase_name() -> String:
	return GameEnums.DayPhase.keys()[_phase]


## Which band an hour falls into. Kept as a pure function so lighting and schedules can ask
## about a future hour, not only the present one.
func phase_for_hour(of_hour: int) -> GameEnums.DayPhase:
	if of_hour < 5:
		return GameEnums.DayPhase.DEEP_NIGHT
	if of_hour < 7:
		return GameEnums.DayPhase.DAWN
	if of_hour < 11:
		return GameEnums.DayPhase.MORNING
	if of_hour < 14:
		return GameEnums.DayPhase.MIDDAY
	if of_hour < 17:
		return GameEnums.DayPhase.AFTERNOON
	if of_hour < 20:
		return GameEnums.DayPhase.DUSK
	return GameEnums.DayPhase.NIGHT


## WHERE TODAY FALLS IN THE REPEATING CYCLE, 1 to `days_per_cycle`. Day 1 is day 1 of the cycle,
## so a new game starts at the beginning of one rather than at an arbitrary offset into it.
##
## GUARDED WITH `maxi` BECAUSE A `days_per_cycle` OF 0 IS A MODULO BY ZERO, and 1 is the honest
## reading of "no cycle": every day is day 1 of it, and an authored `EQUALS 1` is always true.
##
## PUBLIC, and the caller that matters is `NpcBrain` — it passes this into
## `NpcSchedule.entry_for_hour` so a schedule may hold a block that runs on one day of the cycle
## only. `_publish_time` is the other caller, which is what puts it on the flag surface.
func day_of_cycle() -> int:
	return (day - 1) % maxi(1, days_per_cycle) + 1


## True between dusk and dawn. Convenience for the many things that just want "is it dark".
func is_night() -> bool:
	return _phase == GameEnums.DayPhase.NIGHT or _phase == GameEnums.DayPhase.DEEP_NIGHT


## Jump to a specific time. Used by sleeping, cutscenes, debug tools and save loading.
## Emits the same signals a natural passage would, so listeners need no special case.
func set_time(to_day: int, to_hour: int, to_minute: int = 0) -> void:
	var previous_day: int = day
	var previous_hour: int = hour
	day = maxi(1, to_day)
	hour = clampi(to_hour, 0, HOURS_PER_DAY - 1)
	minute = clampi(to_minute, 0, MINUTES_PER_HOUR - 1)
	_accumulator = 0.0
	# BEFORE THE EMITS, on this path as on the tick, so nothing woken by a time signal reads a
	# flag that still says the old hour. That is `inventory.gd`'s ordering rule, and
	# `bag_mirror_test.gd` exists because the same seam went unasserted there.
	_publish_time()
	Events.minute_passed.emit(day, hour, minute)
	if hour != previous_hour:
		Events.hour_passed.emit(day, hour)
	if day != previous_day:
		Events.day_passed.emit(day)
	_update_phase()
	Log.info("clock", "Time set to day %d, %02d:%02d" % [day, hour, minute])


## Push time forward. Sleeping until morning is advance_minutes of whatever the gap is.
func advance_minutes(count: int) -> void:
	if count <= 0:
		return
	for _i: int in count:
		_tick_minute()


## Jump forward to the next occurrence of an hour, rolling into tomorrow if it has already
## passed today. This is what sleeping in a bed does. Returns the minutes skipped.
##
## ROUTED THROUGH set_time, NEVER advance_minutes. Sleeping eight hours through the minute
## loop would emit 480 minute_passed signals and every listener in the game would run 480
## times for a change that, as far as the world is concerned, happened at once. The whole
## reason a time skip is a distinct operation is that it is one event, not a fast-forward.
func skip_to_hour(target_hour: int) -> int:
	var skipped: int = minutes_until_hour(target_hour)
	# minutes_until_hour rolls to tomorrow when the target is not still ahead today, so the
	# day advances exactly when the skip crosses midnight.
	var crossed_midnight: bool = minutes_today() + skipped >= MINUTES_PER_DAY
	set_time(day + (1 if crossed_midnight else 0), clampi(target_hour, 0, HOURS_PER_DAY - 1), 0)
	Log.info("clock", "Skipped %d minutes to %02d:00" % [skipped, hour])
	return skipped


## Minutes from now until the next occurrence of an hour. Used by "sleep until dawn".
func minutes_until_hour(target_hour: int) -> int:
	var target: int = clampi(target_hour, 0, HOURS_PER_DAY - 1) * MINUTES_PER_HOUR
	var now: int = minutes_today()
	if target <= now:
		target += MINUTES_PER_DAY
	return target - now


func _tick_minute() -> void:
	minute += 1
	var rolled_hour: bool = false
	var rolled_day: bool = false

	if minute >= MINUTES_PER_HOUR:
		minute = 0
		hour += 1
		rolled_hour = true
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		rolled_day = true

	_publish_time()
	Events.minute_passed.emit(day, hour, minute)
	if rolled_hour:
		Events.hour_passed.emit(day, hour)
		_update_phase()
	if rolled_day:
		Events.day_passed.emit(day)
		Log.info("clock", "Day %d began" % day)


func _update_phase() -> void:
	var next: GameEnums.DayPhase = phase_for_hour(hour)
	if next == _phase:
		return
	_phase = next
	Log.debug("clock", "Phase -> %s at %02d:%02d" % [phase_name(), hour, minute])
	_publish_phase()
	Events.day_phase_changed.emit(_phase)


## The flag that reads true while a phase is the current one. PUBLIC because it is the spelling
## an AUTHOR writes into a dialogue condition, and BagKeys' header is the reason it is a function
## rather than a note: a format reconstructed by its second reader is a format that disagrees
## once, and the disagreement surfaces as a conversation that never fires at dusk.
func phase_flag(of_phase: GameEnums.DayPhase) -> StringName:
	# Assigned to a typed local rather than passed straight in: `keys()` hands back a Variant,
	# and this is the same conversion `phase_name()` above relies on.
	var key_name: String = GameEnums.DayPhase.keys()[of_phase]
	return _phase_flag_named(key_name)


func _phase_flag_named(key_name: String) -> StringName:
	return StringName("%s%s" % [PHASE_PREFIX, key_name.to_lower()])


func _publish_time() -> void:
	Flags.set_flag(FLAG_DAY, day)
	Flags.set_flag(FLAG_HOUR, hour)
	Flags.set_flag(FLAG_DAY_OF_CYCLE, day_of_cycle())


## A PHASE IS A NAME, NOT A NUMBER, AND TWO MEASUREMENTS SETTLED THAT RATHER THAN A PREFERENCE.
##
## The obvious shape is `time/phase` holding the `GameEnums.DayPhase` ordinal, read with `EQUALS`.
## It was rejected twice over:
##
## 1. ORDINALS ARE A STORAGE FORMAT, NOT A MEANING. `GameEnums` is append-only precisely because
##    its ordinals live inside authored `.tscn` and `.tres` files, so inserting a phase would
##    silently re-point every authored condition at its neighbour — a content migration with no
##    parse error to announce it.
## 2. AND ORDERING ON A PHASE IS ALREADY MEANINGLESS, WHICH IS THE SHARPER HALF. Running
##    `phase_for_hour` across a day gives ordinals 6,6,6,6,6,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,5
##    — DEEP_NIGHT is the HIGHEST ordinal and the EARLIEST hours, because a day wraps and an enum
##    does not. So `AT_LEAST DUSK` would hold at 00:00 and fail at 06:00. The only sound question
##    about a phase is equality, whatever the numbering.
##
## SO WHY NOT THE STRING NAME. Because a String flag is UNREADABLE by the one evaluator, and that
## was measured too: `FlagQuery.passes` on a flag holding "DUSK" returns FALSE for every test in
## the closed set — `EQUALS` and `IS_TRUE` both, each logging `expected int` / `expected bool` —
## since the set compares bools and ints and nothing else. Publishing a name would have shipped
## four flags no authored condition could read, while looking exactly right.
##
## A BOOL UNDER THE NAME IS BOTH: stable against an enum insertion, and readable through
## `IS_TRUE` / `IS_FALSE` with no seventh comparison added to a set whose own file says it stays
## closed. EXACTLY ONE EXISTS AT A TIME, and it is ERASED rather than set false — `Inventory`
## erases a spent stack rather than zeroing it, and an absent flag answers `IS_TRUE` false and
## `IS_FALSE` true, so the query semantics are identical and the store stays one row per phase
## instead of seven. The erase comes FIRST: a phase flag left true would make an authored
## dawn-only line fire at every hour after the first dawn, which is the whole defect this guards.
func _publish_phase() -> void:
	var current: StringName = phase_flag(_phase)
	for key_name: String in GameEnums.DayPhase.keys():
		var key: StringName = _phase_flag_named(key_name)
		if key != current:
			Flags.erase_flag(key)
	Flags.set_flag(current, true)


func _republish() -> void:
	_publish_time()
	_publish_phase()


func _on_game_loaded(_slot: int) -> void:
	_republish()


func _collect_save() -> Dictionary:
	return {"day": day, "hour": hour, "minute": minute}


func _apply_save(data: Dictionary, _from_version: int) -> void:
	set_time(
		DictRead.get_int(data, "day", 1),
		DictRead.get_int(data, "hour", 6),
		DictRead.get_int(data, "minute", 0),
	)
