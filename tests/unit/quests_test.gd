extends TestCase
## Quests: the resources, the registry, the tracker's derivation and its two latches, the save
## round trip, and the journal screen.
##
## THE FIXTURE QUEST, NEVER THE DEMO ONE. `Fixtures.activate()` points `QuestDb.content_dir` at
## `user://test_fixtures/quests`, so every assertion below is about the quest SYSTEM. A case that
## named the authored quest would be testing the demo, and `tools/check_boundary.gd` scans this
## directory and would fail the build for it.
##
## NOTHING HERE AWAITS A FRAME. `TestCase.run()` is synchronous, so the tracker is driven through
## `evaluate()` and `Flags.set_flag` rather than through the signal chain a running game uses -
## that the chain is connected is proved by the boot log and by the windowed captures quoted in
## `DEVLOG.md`.
##
## OWNS: assertions about quest data, the tracker and the journal.
## MUST NOT: name authored content, assert about the demo's quest, or await anything.

const FIXED: int = 48


func run() -> void:
	# COMPUTED, not declared: the last block asserts one thing per authored quest, so authoring a
	# second one must not mean editing a number here. Gathered BEFORE the assertions run, which is
	# what makes the plan checkable at all - see transitions_test.gd and docs/TESTING.md.
	var authored: Array[StringName] = _authored_ids()
	plan(FIXED + authored.size())
	_the_resources_validate_themselves()
	_the_registry_finds_the_fixture()
	_a_quest_starts_only_when_its_condition_passes()
	_steps_advance_in_authored_order()
	_completion_is_latched_and_a_step_is_not()
	_the_save_carries_ids_and_survives_a_round_trip()
	_the_journal_draws_what_the_tracker_holds()
	_the_closed_set_has_one_implementation()
	_every_authored_quest_is_loadable(authored)


## Every quest the game itself ships, discovered rather than listed. Read with the registry on its
## OWN root, before any fixture redirect, and sorted so the order cannot drift.
func _authored_ids() -> Array[StringName]:
	Fixtures.deactivate()
	var out: Array[StringName] = []
	for quest_id: StringName in QuestDb.all():
		out.append(quest_id)
	out.sort()
	return out


## `problems()` is the content layer's whole error-reporting mechanism, and a quest with no steps
## is the one shape that would otherwise start and never finish.
func _the_resources_validate_themselves() -> void:
	var empty := Quest.new()
	equal("a quest with no id, no name and no steps reports three problems",
			empty.problems().size(), 3)
	var made: Quest = FixtureContent.quest()
	equal("a well-formed quest reports nothing", made.problems().size(), 0)
	equal("step() finds a step by id",
			made.step(FixtureContent.QUEST_SECOND_STEP).step_id, FixtureContent.QUEST_SECOND_STEP)
	equal("step() answers null for an id no step has", made.step(&"nonesuch"), null)
	var twice: Quest = FixtureContent.quest()
	twice.steps.append(FixtureContent.quest_step(FixtureContent.QUEST_FIRST_STEP, &"fixture/x"))
	equal("two steps with one id is a problem", twice.problems().size(), 1)
	var untested := QuestStep.new()
	untested.step_id = &"loose"
	untested.summary_key = "fixture.quest.step.loose"
	untested.condition_test = GameEnums.FlagTest.IS_TRUE
	equal("a step that tests a flag but names none is a problem",
			untested.problems(&"quest/whatever").size(), 1)


## The registry's contract is ADR-0006's, and `rescan()` is the name gotcha 17 forced.
func _the_registry_finds_the_fixture() -> void:
	Fixtures.activate()
	equal("the fixture quest is on disk and found", QuestDb.has(FixtureContent.QUEST), true)
	equal("it comes back with its steps",
			QuestDb.quest(FixtureContent.QUEST).steps.size(), 2)
	equal("the registry reports no problems with it", QuestDb.problems().size(), 0)
	equal("an id nothing declares answers null", QuestDb.quest(&"quest/nonesuch"), null)
	equal("the prefix is the one the file name rule uses", QuestDb.ID_PREFIX, "quest/")
	# The content root is a static var and not a const, which is what makes this redirect legal.
	equal("the fixture redirect is in force", QuestDb.content_dir, Fixtures.quest_dir())


func _a_quest_starts_only_when_its_condition_passes() -> void:
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	tracker.evaluate()
	equal("with its start flag unset the quest has not started",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.UNSTARTED)
	equal("and nothing is listed as active",
			tracker.ids_in_state(GameEnums.QuestState.ACTIVE).size(), 0)
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	tracker.evaluate()
	equal("setting the flag a conversation would set starts it",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.ACTIVE)
	equal("current_step is the first authored step",
			tracker.current_step(FixtureContent.QUEST).step_id, FixtureContent.QUEST_FIRST_STEP)
	_free(tracker)


func _steps_advance_in_authored_order() -> void:
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	tracker.evaluate()
	# THE SECOND FLAG FIRST, on purpose: order is authored, not chronological. Satisfying step two
	# before step one must leave step one as the current objective.
	Flags.set_flag(FixtureContent.QUEST_SECOND_FLAG, true)
	tracker.evaluate()
	equal("satisfying the later step does not skip the earlier one",
			tracker.current_step(FixtureContent.QUEST).step_id, FixtureContent.QUEST_FIRST_STEP)
	equal("and the quest is still active",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.ACTIVE)
	Flags.set_flag(FixtureContent.QUEST_FIRST_FLAG, true)
	tracker.evaluate()
	equal("with every step satisfied the quest completes",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.COMPLETE)
	equal("a completed quest has no current step",
			tracker.current_step(FixtureContent.QUEST), null)
	equal("and it is listed as complete rather than active",
			tracker.ids_in_state(GameEnums.QuestState.COMPLETE), [FixtureContent.QUEST])
	_free(tracker)


## THE ASYMMETRY THAT IS THE TRACKER'S CENTRAL DECISION. Completion is a fact about history and is
## latched; a step is a live question about the world and is not. Both halves are asserted,
## because a latch nothing tests is indistinguishable from a cache.
func _completion_is_latched_and_a_step_is_not() -> void:
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	for flag: StringName in [FixtureContent.QUEST_START_FLAG, FixtureContent.QUEST_FIRST_FLAG,
			FixtureContent.QUEST_SECOND_FLAG]:
		Flags.set_flag(flag, true)
	tracker.evaluate()
	equal("the quest completed", tracker.state_of(FixtureContent.QUEST),
			GameEnums.QuestState.COMPLETE)
	Flags.set_flag(FixtureContent.QUEST_SECOND_FLAG, false)
	tracker.evaluate()
	equal("clearing a step's flag afterwards does NOT reopen a finished quest",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.COMPLETE)
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, false)
	tracker.evaluate()
	equal("neither does clearing the flag that started it",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.COMPLETE)
	# Now the other half: an ACTIVE quest's objective is re-derived, so a reopened flag reopens
	# the objective. That is the deliberate line, not an oversight.
	tracker.reset()
	Flags.clear_all()
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	Flags.set_flag(FixtureContent.QUEST_FIRST_FLAG, true)
	tracker.evaluate()
	equal("with step one done, step two is the objective",
			tracker.current_step(FixtureContent.QUEST).step_id, FixtureContent.QUEST_SECOND_STEP)
	Flags.set_flag(FixtureContent.QUEST_FIRST_FLAG, false)
	tracker.evaluate()
	equal("clearing step one's flag on an ACTIVE quest reopens step one",
			tracker.current_step(FixtureContent.QUEST).step_id, FixtureContent.QUEST_FIRST_STEP)
	_free(tracker)


## IDS, NEVER ORDINALS - the ADR-0005 rule this project has already been bitten by. The section is
## driven directly rather than through a slot file, because writing one would test `SaveSystem`
## rather than the section, and `core_test.gd` already owns that.
func _the_save_carries_ids_and_survives_a_round_trip() -> void:
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	tracker.evaluate()
	var section: Dictionary = tracker._collect_save()
	equal("an active quest is saved by id, in the active list",
			DictRead.get_array(section, "active"), [String(FixtureContent.QUEST)])
	equal("and the complete list is empty", DictRead.get_array(section, "complete").size(), 0)
	tracker.reset()
	equal("reset forgets it", tracker.state_of(FixtureContent.QUEST),
			GameEnums.QuestState.UNSTARTED)
	tracker._apply_save(section, 1)
	equal("applying the section brings the latch back",
			tracker.state_of(FixtureContent.QUEST), GameEnums.QuestState.ACTIVE)
	equal("and the derived step is re-derived rather than saved",
			tracker.current_step(FixtureContent.QUEST).step_id, FixtureContent.QUEST_FIRST_STEP)
	# A LOAD DOES NOT RE-FIRE HISTORY. Restoring must not toast three objectives the player
	# finished an hour ago, so _apply_save evaluates silently.
	var heard: Array[StringName] = []
	var listener: Callable = func(key: String, _s: float, _a: Dictionary) -> void:
		heard.append(StringName(key))
	Events.notify_requested.connect(listener)
	tracker.reset()
	tracker._apply_save(section, 1)
	Events.notify_requested.disconnect(listener)
	equal("restoring a save announces nothing", heard.size(), 0)
	# A saved id whose .tres has gone is dropped and named rather than carried into the journal.
	# The flags are cleared first, or _apply_save's own silent evaluate would legitimately start
	# the fixture quest and the count would be 1 for a reason that has nothing to do with this.
	tracker.reset()
	Flags.clear_all()
	tracker._apply_save({"active": ["quest/deleted_since"], "complete": []}, 1)
	equal("a saved id no quest declares is dropped",
			tracker.ids_in_state(GameEnums.QuestState.ACTIVE).size(), 0)
	_free(tracker)


## The screen is dumb and this asserts exactly that: it draws what the tracker holds and holds no
## rules of its own. `refresh()` is public so it can be driven with no frame.
func _the_journal_draws_what_the_tracker_holds() -> void:
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	tracker.evaluate()
	var screen := JournalScreen.new()
	attach(screen)
	equal("the journal declares its identity in _init", screen.screen_id, JournalScreen.SCREEN_ID)
	equal("it stops the world, unlike a conversation", screen.pauses_world, true)
	equal("and cancel dismisses it", screen.closes_on_cancel, true)
	screen.notify_opened()
	equal("with nothing tracked it draws exactly one row, the empty line",
			screen._list.get_child_count(), 1)
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	tracker.evaluate()
	screen.refresh()
	# A heading, a title row and an objective line: three children for one active quest.
	equal("one active quest draws a heading, a title and an objective",
			screen._list.get_child_count(), 3)
	var title: Button = screen._list.get_child(1) as Button
	equal("the title row is focusable, which is the whole of the navigation", title != null, true)
	equal("it draws the quest's name key, translated",
			title.text, tr(QuestDb.quest(FixtureContent.QUEST).name_key))
	var objective: Label = screen._list.get_child(2) as Label
	equal("the objective line is the tracker's current step",
			objective.text.contains(tr("fixture.quest.step.first")), true)
	screen.notify_closed()
	equal("closing disconnects the quest signals",
			Events.quest_advanced.is_connected(screen._on_quest_changed), false)
	screen.queue_free()
	_free(tracker)


## A REGRESSION GATE, not a behaviour test. `FlagQuery` exists because a quest step and a dialogue
## condition are the same closed set of six comparisons, and the whole value of extracting it is
## lost the moment a second copy grows back - the same reasoning `art_contract_test.gd` uses to
## keep a sheet dimension out of `character_visual.gd`.
func _the_closed_set_has_one_implementation() -> void:
	equal("FlagQuery answers ALWAYS without a flag",
			FlagQuery.passes(&"", GameEnums.FlagTest.ALWAYS, 0), true)
	Flags.set_flag(&"fixture/tally", 3)
	equal("AT_LEAST compares an int flag",
			FlagQuery.passes(&"fixture/tally", GameEnums.FlagTest.AT_LEAST, 3), true)
	equal("AT_MOST does too",
			FlagQuery.passes(&"fixture/tally", GameEnums.FlagTest.AT_MOST, 2), false)
	var runner: String = FileAccess.get_file_as_string(
			"res://src/systems/dialogue/dialogue_runner.gd")
	equal("dialogue_runner.gd read", runner.is_empty(), false)
	equal("and it no longer carries its own copy of the comparison table",
			runner.contains("FlagTest.AT_LEAST"), false)
	var tracker_source: String = FileAccess.get_file_as_string(
			"res://src/systems/quest/quest_tracker.gd")
	equal("nor does the tracker", tracker_source.contains("FlagTest.AT_LEAST"), false)


## One assertion per quest the GAME has authored, so this holds for quest three the day it is
## written and skips loudly in a stripped template that has none. The shape `Fixtures.area_ids()`
## established: discover, then assert per item found or skip with the count.
func _every_authored_quest_is_loadable(authored: Array[StringName]) -> void:
	Fixtures.deactivate()
	if authored.is_empty():
		skip("authored quests validate", "this checkout has no quests in data/quests", 0)
		return
	for quest_id: StringName in authored:
		var found: Quest = QuestDb.quest(quest_id)
		equal("authored quest %s loads with steps and no problems" % quest_id,
				found != null and not found.steps.is_empty() and found.problems().is_empty(), true)


## A tracker of its own per block, so one block's latches cannot leak into the next. It is attached
## so `_ready` runs - which is what joins the group `JournalScreen.find` looks in - and `Flags` is
## cleared by the caller rather than here, because a block that wants a flag set before the first
## evaluation has to be able to arrange that.
func _tracker() -> QuestTracker:
	var tracker := QuestTracker.new()
	attach(tracker)
	return tracker


## Freed immediately rather than at the end of the case: an unregistered save participant left
## alive would answer the NEXT block's _collect_save as well, and anything alive at exit prints a
## wall of leaked-RID errors that buries a real one.
func _free(tracker: QuestTracker) -> void:
	remove_child(tracker)
	tracker.free()
