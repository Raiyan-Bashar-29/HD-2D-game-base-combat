extends TestCase
## The smoke test: ONE continuous session driving the systems through their PUBLIC APIs, in the
## order a game drives them, asserting that the whole run left the log clean.
##
## THE ROW ASKED FOR "A SMOKE TEST THAT DRIVES THE WHOLE DEMO", AND THIS DELIBERATELY DRIVES A
## GAME INSTEAD. WP-14 was written before the template reframing and its wording would have
## welded the courtyard, the garden-keeper and the rose key into a permanent gate — the exact
## coupling `tools/check_boundary.gd` exists to prevent, arriving through the back door of a
## test. T1.3 already unwelded the suite from the demo once; a smoke test naming demo content
## would have grown it straight back, and the gate would have caught it, because
## `check_boundary` scans `tests/unit/`. So the session below is built from
## `tests/framework/fixtures.gd` and names no content at all. The board row was rewritten in
## the same commit rather than quietly reinterpreted — see docs/WORK_PACKAGES.md § WP-14.
##
## WHAT A SMOKE TEST CAN BE HERE, given that `run()` is SYNCHRONOUS (TESTING.md rule 2). It
## cannot travel between areas, wait on the threaded loader or press a key, so "end to end" is
## not "boot to credits". It is the CHAIN: a run begins, a quest starts because a flag was
## written, items are gathered and publish their counts, a counted objective notices, something
## is put in hand, time passes, the whole lot is saved, wiped and restored, and the quest is
## still where it was. Every one of those seams has its own case; this asserts they compose,
## which is the one thing a per-system case cannot see.
##
## WHY THE TALLY IS A DELTA AND NOT `Log.tally() == Vector2i(0, 0)`, which is what the row's
## exit criterion literally says. Measured: a full suite run ends `14 warnings, 8 errors`,
## because several cases assert refusals and bad input ON PURPOSE. `tally()` is cumulative over
## the session, so the absolute form would assert something about the cases that happened to run
## first. The delta across this case is the claim actually worth making, and it is the stronger
## one: driving a game through this chain must produce neither a warning nor an error.
##
## OWNS: the composed session, and the assertion that it logged nothing.
## MUST NOT: name authored content, or re-assert a single system's behaviour — the per-system
## cases own that, and duplicating it here would make this file fail for their reasons.

## The FIXTURE carrier, not one of our own: the fixture counted step names
## `BagKeys.key(CARRIER, STACK_ITEM)`, so a bag published under any other id is invisible to it.
## Found by assertion rather than by reading the fixture — the first run of this case reported
## `expected (2, 3), got (0, 3)` with the flag provably set, which is what a carrier mismatch
## looks like from the outside.
const CARRIER: StringName = FixtureContent.CARRIER
const SLOT: int = 3

var _actor: Node3D = null
var _bag: Inventory = null
var _worn: Equipment = null
var _tracker: QuestTracker = null
## Read at the top of the session and again at the end; see the header on why it is a delta.
var _before: Vector2i = Vector2i.ZERO


func run() -> void:
	plan(23)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	_a_session_runs_end_to_end()
	_the_whole_session_logged_nothing()
	_a_checkout_with_a_game_in_it_can_start_one()


## THE CHAIN. Driven strictly through public APIs — `add`, `equip`, `set_flag`, `save_to_slot` —
## never by reaching into a private field, because the claim is that the seams compose and a
## test that arranged the state by hand would prove only that the assertions agree with
## themselves.
func _a_session_runs_end_to_end() -> void:
	_begin_session()

	# A RUN BEGINS. `game_started` is what a new game emits after clearing the flags, and the
	# bag clears on it — the latent defect T3.3 found, asserted here in the composed order
	# rather than in isolation.
	_bag.add(FixtureContent.STACK_ITEM, 5)
	Flags.clear_all()
	Events.game_started.emit()
	equal("a run beginning empties the bag", _bag.total_count(), 0)
	equal("and leaves no counts published",
			Flags.has_flag(BagKeys.key(CARRIER, FixtureContent.STACK_ITEM)), false)

	# A QUEST STARTS BECAUSE A FLAG WAS WRITTEN, which is WP-08's whole design: nothing calls a
	# quest API, and the tracker derives the state.
	Flags.set_flag(FixtureContent.COUNT_START_FLAG, true)
	_tracker.evaluate()
	equal("writing a flag starts the quest",
			_tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.ACTIVE)

	# ITEMS ARE GATHERED, AND THE COUNTED OBJECTIVE NOTICES — through `Flags`, with the tracker
	# never learning what an inventory is (T3.3).
	_bag.add(FixtureContent.STACK_ITEM, FixtureContent.COUNT_NEEDED - 1)
	_tracker.evaluate()
	var step: QuestStep = _tracker.current_step(FixtureContent.COUNT_QUEST)
	equal("one short leaves the objective open", step != null, true)
	equal("and the tally reads what is carried",
			_tracker.step_progress(step), Vector2i(FixtureContent.COUNT_NEEDED - 1,
			FixtureContent.COUNT_NEEDED))
	_bag.add(FixtureContent.STACK_ITEM, 1)
	_tracker.evaluate()
	equal("the last one settles the quest",
			_tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.COMPLETE)

	# SOMETHING IS PUT IN HAND, AND IT HAS TO BE CARRIED FIRST: `Equipment.can_equip` asks the
	# bag beside it, so the chain really is gather-then-hold and cannot be short-circuited.
	equal("the holdable item is picked up", _bag.add(FixtureContent.HELD_ITEM, 1), true)
	equal("an equippable item goes in hand", _worn.equip(FixtureContent.HELD_ITEM), true)
	equal("and reads back as held", _worn.is_equipped(FixtureContent.HELD_ITEM), true)

	# TIME PASSES, through the one event a skip is allowed to be.
	Clock.set_time(1, 6, 0)
	var skipped_minutes: int = Clock.skip_to_hour(18)
	equal("resting until evening skips forward", skipped_minutes, 12 * 60)
	equal("and the clock agrees it is evening", Clock.minutes_today(), 18 * 60)

	_the_session_survives_a_save()


## SAVED, WIPED AND RESTORED. The wipe matters: loading into a session that still holds the
## state would pass whether or not anything was written to the file.
func _the_session_survives_a_save() -> void:
	equal("the session saves", SaveSystem.save_to_slot(SLOT), OK)

	# THE LATCH HAS TO GO TOO. `QuestTracker` derives progress from `Flags` but LATCHES the two
	# things it cannot derive, so clearing the flags alone leaves it still saying ACTIVE — which
	# is correct behaviour, and would have made this a wipe that did not wipe.
	Flags.clear_all()
	_bag.clear_all()
	_tracker.reset()
	Clock.set_time(1, 0, 0)
	equal("the wipe really emptied the bag", _bag.total_count(), 0)
	equal("and really dropped the quest",
			_tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.UNSTARTED)

	equal("the session loads", SaveSystem.load_from_slot(SLOT), OK)
	equal("the carried items come back",
			_bag.count_of(FixtureContent.STACK_ITEM), FixtureContent.COUNT_NEEDED)
	equal("what was in hand is still in hand",
			_worn.is_equipped(FixtureContent.HELD_ITEM), true)
	equal("the hour comes back", Clock.minutes_today(), 18 * 60)
	_tracker.evaluate()
	equal("and the quest is still settled",
			_tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.COMPLETE)
	# THE PUBLISHED COUNT IS DERIVED, so it is not IN the file and has to be re-derived on the way
	# back. THIS ASSERTS ONLY THAT IT IS THERE AFTERWARDS, and the comment that used to sit here
	# claimed it asserted the save-participant ORDER as well. It does not: deleting
	# `Inventory`'s `game_loaded` subscription — the real way that invariant would be lost —
	# leaves this line green, because the wipe above happens to let `_apply_save` publish for
	# itself. Found by PLANTING the violation instead of trusting the assertion (gotcha 23), the
	# same way T3.2's framing gate turned out to be passing over deleted content, and left
	# written down because the weaker claim is the true one. The order invariant is owned and
	# provably caught by `item_count_test.gd`, which went red on that same plant.
	equal("the derived count is available again after a load",
			Flags.get_int(BagKeys.key(CARRIER, FixtureContent.STACK_ITEM), 0),
			FixtureContent.COUNT_NEEDED)

	SaveSystem.delete_slot(SLOT)


## THE ASSERTION THE ROW ASKED FOR. Everything above ran between the two readings.
func _the_whole_session_logged_nothing() -> void:
	var after: Vector2i = Log.tally()
	equal("the whole session logged no warning and no error", after - _before, Vector2i.ZERO)
	_end_session()


## THE ONE BLOCK THAT IS ABOUT A GAME RATHER THAN THE ENGINE, so it is the one that skips.
## `GameConfig.first_area()` is the single demo id the template allows (it lives in
## project.godot, not in `src/`), and this asserts only that whatever it names RESOLVES — never
## what it is called. A checkout with no areas has no first area, which is a correct state and
## not a failure, so it is skipped and COUNTED rather than passed quietly.
##
## IT GATES ON AREAS, NOT ON CONTENT, AND THE DIFFERENCE COST A RED RUNG. `has_demo_content()`
## answers true on the FIRST .tres of any kind, so a new game that authored one item before its
## first area armed an assertion about areas and failed rung 4 — in exactly the window
## docs/NEW_GAME.md walks an author through, and while docs/NEW_GAME.md said the ladder stays
## green. Found by PERFORMING docs/UPGRADING.md against a real fork, not by reading. A block
## must gate on the same question it asserts; `Fixtures.area_ids()` is that question and it
## already existed. Nothing is weakened: a game WITH areas still fails on an unset first area
## and on one that names a scene that is not there.
func _a_checkout_with_a_game_in_it_can_start_one() -> void:
	if Fixtures.area_ids().is_empty():
		skip("a game in this checkout can be started",
				"no areas authored yet", 2)
		return
	var first: StringName = GameConfig.first_area()
	equal("the configured first area is set", first != &"", true)
	equal("and its scene really exists", Director.area_exists(first), true)


func _begin_session() -> void:
	Fixtures.activate()
	_before = Log.tally()
	_actor = Node3D.new()
	_bag = Inventory.new()
	# Before add_child: `_ready` registers the save participant and declares the derived prefix.
	_bag.save_id = &"smoke_bag"
	_bag.carrier_id = CARRIER
	_actor.add_child(_bag)
	_worn = Equipment.new()
	_worn.wearer_id = CARRIER
	_actor.add_child(_worn)
	attach(_actor)
	_tracker = QuestTracker.new()
	attach(_tracker)


## Freed here rather than left to exit, and the save participants unregistered with them: a live
## `Inventory` would answer the NEXT case's _collect_save, and anything alive at exit prints a
## wall of leaked-RID errors that buries a real one.
func _end_session() -> void:
	remove_child(_tracker)
	_tracker.free()
	remove_child(_actor)
	_actor.free()

