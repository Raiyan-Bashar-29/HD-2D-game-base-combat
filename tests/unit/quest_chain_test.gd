extends TestCase
## Quest CHAINING: one quest's completion starting another, driven THROUGH `Events.flag_changed`.
##
## THIS IS THE ONE QUEST CASE THAT USES THE SIGNAL, AND THAT IS WHY IT EXISTS. `quests_test.gd`
## says in its own header that it drives `evaluate()` and `Flags.set_flag` directly "rather than
## through the signal chain a running game uses" — which is right for asking what a step MEANS,
## and is exactly why it could not see this: a re-entrant `evaluate()` can only arrive on
## `flag_changed`, so a case that never emits one cannot reach the guard at all. Split by
## QUESTION rather than by size, on T5.7's precedent.
##
## THE DEFECT IT PINS. `evaluate()` used to `return` on a re-entrant call instead of remembering
## it. A listener on `quest_completed` that writes the next chapter's start flag — the case the
## guard's own comment names — landed back in `evaluate()` mid-pass and was DISCARDED, so whether
## the next quest started depended on where it sat in `QuestDb.all()`, which is directory scan
## order. BOTH orders are asserted below, because the benign one passed even while broken and a
## case that happened to test only that would have looked like proof.
##
## WHAT IS NOT ASSERTED, SAID OUT LOUD. The drain's pass bound is defensive and NO listener this
## template can construct reaches it: a flag-written-per-flag listener recurses through the signal
## before the drain is ever re-entered, and a quest completes at most once, so a chain always
## settles. The bound exists so a consuming game's listener cannot hang the game, and it is
## unproved for the same reason `export_test.gd` cannot test an export it is not running in.
##
## OWNS: assertions about a chain of quests and about the re-entrant path.
## MUST NOT: name authored content, or assert what a single quest's step means — that is
## `quests_test.gd`, and duplicating it here would give two files one question.

const FIXED: int = 8

## Counted by the chaining listener, so a block asserts the listener actually fired rather than
## inferring it from the outcome it was supposed to cause.
var _writes: int = 0
## The flag the listener writes when any quest completes. Set by `_armed`, which is what lets one
## pair of fixtures play the dependent in either direction.
var _arm_flag: StringName = &""


func run() -> void:
	plan(FIXED)
	_the_scan_order_is_the_one_these_assertions_assume()
	_a_dependent_scanned_BEFORE_its_trigger_still_starts()
	_a_dependent_scanned_AFTER_its_trigger_still_starts()


## THE LOAD-BEARING PRECONDITION, ASSERTED RATHER THAN ASSUMED. `ContentScan.resource_paths()`
## does not sort — it hands back whatever the directory listing gave — so "lead is scanned first"
## is an observation about this machine, not a guarantee. If it ever stops holding, the two blocks
## below quietly swap meaning and both end up testing the benign order. This fails loudly instead.
func _the_scan_order_is_the_one_these_assertions_assume() -> void:
	Fixtures.activate()
	var order: Array[StringName] = []
	for quest_id: StringName in QuestDb.all():
		order.append(quest_id)
	var lead: int = order.find(FixtureContent.CHAIN_LEAD)
	var next: int = order.find(FixtureContent.CHAIN_NEXT)
	equal("both chaining fixtures are in the scan", lead >= 0 and next >= 0, true)
	equal("chain_lead is scanned before chain_next", lead < next, true)


## THE ADVERSARIAL ORDER, and the one that was broken. The DEPENDENT (`lead`) is scanned first,
## so by the time the trigger (`next`) completes and the listener writes lead's start flag, the
## pass has already walked past lead and will not look again — unless the re-entrant call is
## remembered.
func _a_dependent_scanned_BEFORE_its_trigger_still_starts() -> void:
	var tracker: QuestTracker = _armed(FixtureContent.CHAIN_LEAD_START)
	Flags.set_flag(FixtureContent.CHAIN_NEXT_START, true)
	equal("the trigger is active before anything completes",
			tracker.state_of(FixtureContent.CHAIN_NEXT), GameEnums.QuestState.ACTIVE)
	# The only kind of line here a running game also executes: a step's flag set by something
	# that has never heard of quests.
	Flags.set_flag(FixtureContent.CHAIN_NEXT_FLAG, true)
	equal("the trigger completed", tracker.state_of(FixtureContent.CHAIN_NEXT),
			GameEnums.QuestState.COMPLETE)
	equal("the listener fired once", _writes, 1)
	equal("the dependent scanned BEFORE its trigger started anyway",
			tracker.state_of(FixtureContent.CHAIN_LEAD), GameEnums.QuestState.ACTIVE)
	_disarm(tracker)


## THE BENIGN ORDER. The dependent (`next`) is scanned after its trigger, so the running pass
## reaches it with the flag already set and it starts even with the defect present. Asserted so
## the fix is shown not to have broken the case that used to work by accident.
func _a_dependent_scanned_AFTER_its_trigger_still_starts() -> void:
	var tracker: QuestTracker = _armed(FixtureContent.CHAIN_NEXT_START)
	Flags.set_flag(FixtureContent.CHAIN_LEAD_START, true)
	Flags.set_flag(FixtureContent.CHAIN_LEAD_FLAG, true)
	equal("the trigger completed", tracker.state_of(FixtureContent.CHAIN_LEAD),
			GameEnums.QuestState.COMPLETE)
	equal("the dependent scanned AFTER its trigger started too",
			tracker.state_of(FixtureContent.CHAIN_NEXT), GameEnums.QuestState.ACTIVE)
	_disarm(tracker)


## A tracker with the chaining listener attached, armed to write `starts` when anything completes.
## Flags are cleared first so neither fixture quest carries state from an earlier block.
func _armed(starts: StringName) -> QuestTracker:
	var tracker := QuestTracker.new()
	attach(tracker)
	Flags.clear_all()
	_writes = 0
	_arm_flag = starts
	Events.quest_completed.connect(_on_quest_completed)
	return tracker


## Freed immediately rather than at the end of the case, for the reason `quests_test.gd` gives:
## an unregistered save participant left alive answers the NEXT block's collect as well.
func _disarm(tracker: QuestTracker) -> void:
	if Events.quest_completed.is_connected(_on_quest_completed):
		Events.quest_completed.disconnect(_on_quest_completed)
	remove_child(tracker)
	tracker.free()


## THE LISTENER THE WHOLE CASE IS ABOUT: a consequence of one quest finishing that writes the flag
## another quest starts on. Deliberately ignorant of quests beyond the signal — this is the shape
## a consuming game's chapter script has, and it is why the guard's comment named it.
func _on_quest_completed(_quest_id: StringName) -> void:
	_writes += 1
	Flags.set_flag(_arm_flag, true)
