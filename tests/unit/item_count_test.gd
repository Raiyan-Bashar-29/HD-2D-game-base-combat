extends TestCase
## A quest step that reads an ITEM COUNT: the key shape, the projection that publishes it, the
## step reading it, the journal drawing it, and the layer rule that made this the design.
##
## THE ONE THING TO UNDERSTAND BEFORE READING ANY ASSERTION BELOW. `QuestTracker` is in
## `systems`, `Inventory` is in `gameplay`, and `src/` points downward only - so a tracker that
## read a bag is the layer violation WP-08 already refused once over a `reward_item` field. The
## dependency is inverted instead: `Inventory` PUBLISHES its counts as flags under
## `bag/<carrier>/<item id>`, and a step reads a flag exactly as it always has. The last block
## here is a REGRESSION GATE on that, because the design whole value is lost the moment the
## quest system learns what an inventory is - the shape `art_contract_test.gd` established.
##
## THE PROJECTION IS NOT THE TRUTH, and two blocks are about the ways that can go wrong: a count
## spent to zero must ERASE its key rather than leave one saying 1, and the two moments that wipe
## `Flags` from underneath the mirror - a new game and a loaded save - must both republish.
##
## OWNS: assertions about the count key, its publication, a counted step and its journal line.
## MUST NOT: name authored content, or assert about the demo quest - `quests_test.gd` rule,
## for `check_boundary` reason.

const NEEDED: int = FixtureContent.COUNT_NEEDED

var _carrier: Node3D = null
var _bag: Inventory = null


func run() -> void:
	plan(66)
	_the_key_shape_is_built_and_parsed_in_one_place()
	_the_bag_publishes_its_counts()
	_the_projection_survives_a_wipe()
	_a_step_reads_the_count()
	_the_count_can_already_be_satisfied_and_can_fall_back()
	_an_item_no_catalogue_has_is_never_satisfied()
	_the_journal_draws_the_tally()
	_the_quest_system_still_does_not_know_what_an_inventory_is()


## THE KEY IS BUILT AND PARSED BY THE SAME FILE, and every assertion here is a round trip rather
## than a comparison against a literal - a test that spelled the format out again would be the
## second copy the file exists to prevent.
func _the_key_shape_is_built_and_parsed_in_one_place() -> void:
	var key: StringName = BagKeys.key(FixtureContent.CARRIER, FixtureContent.STACK_ITEM)
	equal("the key begins with the one prefix", String(key).begins_with(BagKeys.PREFIX), true)
	equal("it is inside its carrier scope",
			String(key).begins_with(BagKeys.scope(FixtureContent.CARRIER)), true)
	equal("the carrier parses back out", BagKeys.carrier_of(key), FixtureContent.CARRIER)
	# THE ASSERTION THAT MATTERS: an item id contains a slash, so a parser splitting on the LAST
	# one would answer the second half of the id and a validator would then fail to find it.
	equal("and so does an item id that contains a slash",
			BagKeys.item_of(key), FixtureContent.STACK_ITEM)
	equal("it is recognised as one of ours", BagKeys.is_bag_key(key), true)
	equal("a flag from another namespace is not",
			BagKeys.is_bag_key(&"fixture/something"), false)
	equal("nor is a bag key with no item on the end",
			BagKeys.is_bag_key(StringName(BagKeys.scope(FixtureContent.CARRIER))), false)
	equal("nor is the bare prefix", BagKeys.is_bag_key(StringName(BagKeys.PREFIX)), false)
	equal("two carriers do not collide",
			BagKeys.key(&"fixture_other", FixtureContent.STACK_ITEM) == key, false)


## THE MIRROR ITSELF. Driven through `add` and `remove`, never by writing a flag here: the claim
## is that the real paths publish, and a test that set the flag itself would prove nothing.
func _the_bag_publishes_its_counts() -> void:
	_build_carrier()
	var key: StringName = BagKeys.key(FixtureContent.CARRIER, FixtureContent.STACK_ITEM)
	Flags.clear_all()
	equal("an empty bag publishes nothing", Flags.has_flag(key), false)
	equal("the prefix is declared derived", Flags.is_derived(key), true)
	_bag.add(FixtureContent.STACK_ITEM, 2)
	equal("adding two publishes two", Flags.get_int(key, 0), 2)
	equal("and the count itself agrees", _bag.count_of(FixtureContent.STACK_ITEM), 2)
	_bag.add(FixtureContent.STACK_ITEM, 1)
	equal("adding one more republishes three", Flags.get_int(key, 0), 3)
	_bag.remove(FixtureContent.STACK_ITEM, 2)
	equal("spending two republishes one", Flags.get_int(key, 0), 1)
	# ERASED, NOT ZEROED. A row reading 0 for something the player does not have is a row in every
	# debug dump forever, and `Equipment.unequip` settled the same question the same way.
	_bag.remove(FixtureContent.STACK_ITEM, 1)
	equal("spending the last one erases the key rather than zeroing it",
			Flags.has_flag(key), false)
	_bag.add(FixtureContent.STACK_ITEM, 4)
	_bag.clear_all()
	equal("emptying the bag erases it too", Flags.has_flag(key), false)
	# THE DERIVATION IS THE POINT: one number, saved once, by the participant that owns it.
	_bag.add(FixtureContent.STACK_ITEM, 2)
	var flag_section: Dictionary = Flags._collect_save()
	equal("the published count is NOT in the flags save section",
			flag_section.has(String(key)), false)
	Flags.set_flag(&"fixture/ordinary", 7)
	equal("while an ordinary flag beside it still is",
			Flags._collect_save().has("fixture/ordinary"), true)
	equal("the bag own section still holds the count",
			DictRead.get_int(_bag._collect_save(), String(FixtureContent.STACK_ITEM), 0), 2)
	equal("and its save version did not have to move", Inventory.SAVE_VERSION, 1)


## THE TWO MOMENTS THAT WIPE `Flags` UNDER THE MIRROR, and a missed one would leave a step
## reading zero for a full bag - or worse, reading a full bag the player no longer has.
func _the_projection_survives_a_wipe() -> void:
	var key: StringName = BagKeys.key(FixtureContent.CARRIER, FixtureContent.STACK_ITEM)
	_bag.clear_all()
	_bag.add(FixtureContent.STACK_ITEM, NEEDED)
	equal("the bag is published before the wipe", Flags.get_int(key, 0), NEEDED)
	# A LOAD. `Flags._apply_save` clears the store, and the derived keys are deliberately not in
	# the file it restores from, so `game_loaded` is what puts them back - after every section.
	Flags.clear_all()
	equal("clearing the flags loses the mirror, as it must", Flags.has_flag(key), false)
	Events.game_loaded.emit(1)
	equal("game_loaded republishes it", Flags.get_int(key, 0), NEEDED)
	# A NEW GAME. It clears the flags and then emits, so the bag has to empty rather than
	# republish - and the items themselves carried over into a fresh game before this existed.
	Events.game_started.emit()
	equal("a new game empties the bag", _bag.total_count(), 0)
	equal("and leaves no key behind", Flags.has_flag(key), false)


## THE WHOLE POINT OF THE PACKAGE: "bring me three of these" as authored data, with no field on
## `QuestStep` and no line in `QuestTracker` that knows what is being counted.
func _a_step_reads_the_count() -> void:
	var tracker: QuestTracker = _tracker()
	_bag.clear_all()
	Flags.clear_all()
	Flags.set_flag(FixtureContent.COUNT_START_FLAG, true)
	tracker.evaluate()
	equal("the counting quest is active", tracker.state_of(FixtureContent.COUNT_QUEST),
			GameEnums.QuestState.ACTIVE)
	var step: QuestStep = tracker.current_step(FixtureContent.COUNT_QUEST)
	equal("its counted step is the objective", step.step_id, FixtureContent.COUNT_STEP)
	equal("the step names a bag key and nothing else",
			BagKeys.item_of(step.condition_flag), FixtureContent.STACK_ITEM)
	equal("with an empty bag there is no progress",
			tracker.step_progress(step), Vector2i(0, NEEDED))
	_bag.add(FixtureContent.STACK_ITEM, NEEDED - 1)
	equal("one short leaves the same objective",
			tracker.current_step(FixtureContent.COUNT_QUEST).step_id, FixtureContent.COUNT_STEP)
	equal("and the progress is one short",
			tracker.step_progress(step), Vector2i(NEEDED - 1, NEEDED))
	_bag.add(FixtureContent.STACK_ITEM, 1)
	equal("the last one completes the quest", tracker.state_of(FixtureContent.COUNT_QUEST),
			GameEnums.QuestState.COMPLETE)
	# MORE THAN ENOUGH IS ENOUGH. AT_LEAST, not EQUALS, so a fourth petal must not un-finish it.
	_bag.add(FixtureContent.STACK_ITEM, 1)
	tracker.evaluate()
	equal("and a spare one does not un-finish it", tracker.state_of(FixtureContent.COUNT_QUEST),
			GameEnums.QuestState.COMPLETE)
	_free(tracker)


## THE TWO BOUNDARY CASES THE PACKAGE WAS ASKED FOR, and they answer differently ON PURPOSE.
##
## ALREADY SATISFIED when the step becomes current: the step is passed over the moment the quest
## starts, because a step is a live question and never a thing that has to be "reached".
##
## DROPPED BACK BELOW THE THRESHOLD: an ACTIVE quest objective REOPENS, and a COMPLETED one does
## not. That is the asymmetry WP-08 settled and it is the reason the latch exists at all - its own
## header names `AT_LEAST 3 on a counter` as the case. So this package needed no new decision;
## it needed the existing one asserted against the thing that finally decrements.
func _the_count_can_already_be_satisfied_and_can_fall_back() -> void:
	var tracker: QuestTracker = _tracker()
	_bag.clear_all()
	Flags.clear_all()
	_bag.add(FixtureContent.STACK_ITEM, NEEDED)
	Flags.set_flag(FixtureContent.COUNT_START_FLAG, true)
	tracker.evaluate()
	equal("a count already satisfied when the quest starts completes it at once",
			tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.COMPLETE)
	_bag.remove(FixtureContent.STACK_ITEM, NEEDED)
	equal("and spending the items afterwards does NOT reopen a finished quest",
			tracker.state_of(FixtureContent.COUNT_QUEST), GameEnums.QuestState.COMPLETE)
	# The other half, on an ACTIVE quest. Two steps would be needed for the objective to have
	# somewhere to move to, so the observation is on the step itself: satisfied, then not.
	tracker.reset()
	Flags.clear_all()
	_bag.clear_all()
	_bag.add(FixtureContent.STACK_ITEM, NEEDED)
	var step: QuestStep = QuestDb.quest(FixtureContent.COUNT_QUEST).steps[0]
	equal("the step passes with a full bag",
			FlagQuery.passes(step.condition_flag, step.condition_test, step.condition_value), true)
	_bag.remove(FixtureContent.STACK_ITEM, 1)
	equal("and stops passing the moment one is spent",
			FlagQuery.passes(step.condition_flag, step.condition_test, step.condition_value), false)
	Flags.set_flag(FixtureContent.COUNT_START_FLAG, true)
	tracker.evaluate()
	equal("so the objective is back on an active quest",
			tracker.current_step(FixtureContent.COUNT_QUEST).step_id, FixtureContent.COUNT_STEP)
	_free(tracker)


## A STEP NAMING AN ITEM NO CATALOGUE HAS. It cannot pass, and it cannot be made to pass by
## anything the player does - which is exactly why `tools/check_content.gd` fails the build on
## one rather than leaving it to be discovered by a player walking the area looking for it.
##
## The suite half of that gate is this: the failure is DULL rather than dramatic. Nothing
## crashes, nothing warns, the journal reads `0 / 1` forever. A checker is the only thing that
## can see it, and this asserts what it is seeing.
func _an_item_no_catalogue_has_is_never_satisfied() -> void:
	Flags.clear_all()
	_bag.clear_all()
	equal("the absent item really is absent from the catalogue",
			ItemDb.has(FixtureContent.ABSENT_ITEM), false)
	equal("so the bag refuses to carry it", _bag.add(FixtureContent.ABSENT_ITEM, 1), false)
	var absent: StringName = BagKeys.key(FixtureContent.CARRIER, FixtureContent.ABSENT_ITEM)
	equal("nothing publishes a count for it", Flags.has_flag(absent), false)
	equal("a step counting it never passes",
			FlagQuery.passes(absent, GameEnums.FlagTest.AT_LEAST, 1), false)
	equal("and it reads as no progress towards one, rather than as an error",
			FlagQuery.progress(absent, GameEnums.FlagTest.AT_LEAST, 1), Vector2i(0, 1))


## THE JOURNAL, AND WHAT `progress` DOES NOT COUNT. The screen is handed (have, need) and draws
## it; `need == 0` is the tracker saying "not a count", and an authored objective must not
## acquire a `0 / 0` it never asked for.
func _the_journal_draws_the_tally() -> void:
	equal("ALWAYS is not a count",
			FlagQuery.progress(&"fixture/x", GameEnums.FlagTest.ALWAYS, 3), Vector2i.ZERO)
	equal("IS_TRUE is not a count",
			FlagQuery.progress(&"fixture/x", GameEnums.FlagTest.IS_TRUE, 3), Vector2i.ZERO)
	# AT_MOST IS A CEILING, NOT A TALLY. Drawing 2 / 3 under "keep it below three" would tell the
	# player to gather more of the one thing they must not.
	equal("AT_MOST is not a count either",
			FlagQuery.progress(&"fixture/x", GameEnums.FlagTest.AT_MOST, 3), Vector2i.ZERO)
	equal("and a count of zero is not a count",
			FlagQuery.progress(&"fixture/x", GameEnums.FlagTest.AT_LEAST, 0), Vector2i.ZERO)
	equal("EQUALS is", FlagQuery.progress(&"fixture/x", GameEnums.FlagTest.EQUALS, 3),
			Vector2i(0, 3))
	var tracker: QuestTracker = _tracker()
	Flags.clear_all()
	_bag.clear_all()
	_bag.add(FixtureContent.STACK_ITEM, 1)
	Flags.set_flag(FixtureContent.COUNT_START_FLAG, true)
	tracker.evaluate()
	var screen := JournalScreen.new()
	attach(screen)
	screen.notify_opened()
	var objective: Label = _objective_for(screen, FixtureContent.COUNT_QUEST)
	equal("the objective line is drawn", objective != null, true)
	# READ, NOT GLANCED AT (gotcha 28): the numbers are asserted separately from the summary, so a
	# line that drew the right words and the wrong tally cannot pass.
	equal("it carries the authored summary",
			objective.text.contains(tr("fixture.quest.step.gather")), true)
	equal("and the tally the player is owed", objective.text.contains("1 / 3"), true)
	_bag.add(FixtureContent.STACK_ITEM, 1)
	screen.refresh()
	equal("taking one more redraws the tally",
			_objective_for(screen, FixtureContent.COUNT_QUEST).text.contains("2 / 3"), true)
	# AND THE OTHER QUEST, whose step is not a count, must be untouched by any of this.
	Flags.set_flag(FixtureContent.QUEST_START_FLAG, true)
	tracker.evaluate()
	screen.refresh()
	var plain: Label = _objective_for(screen, FixtureContent.QUEST)
	equal("an uncounted objective draws no tally at all", plain.text.contains(" / "), false)
	equal("and still draws its own line",
			plain.text.contains(tr("fixture.quest.step.first")), true)
	screen.notify_closed()
	screen.queue_free()
	_free(tracker)


## A REGRESSION GATE, AND THE MOST IMPORTANT BLOCK IN THE FILE. The exit criterion for this
## package was that a count must work WITHOUT the quest system knowing what an inventory is, and
## nothing else in the suite can fail if that stops being true - the behaviour would be identical
## and the layer rule would be gone. Text scans, for `art_contract_test.gd` reason.
func _the_quest_system_still_does_not_know_what_an_inventory_is() -> void:
	# CODE ONLY, NOT COMMENTS, which is the line `tools/check_boundary.gd` already draws and the
	# first version of this block got wrong: both files EXPLAIN in their headers why an
	# `Inventory` is not reachable from them, so a raw text scan failed on the very paragraph
	# that documents the rule. A comment naming a class teaches; a line of code depends on it.
	var tracker_source: String = _code_of("res://src/systems/quest/quest_tracker.gd")
	equal("quest_tracker.gd read", tracker_source.is_empty(), false)
	equal("and its code names no Inventory", tracker_source.contains("Inventory"), false)
	equal("nor ItemDb", tracker_source.contains("ItemDb."), false)
	equal("nor the bag key shape", tracker_source.contains("BagKeys"), false)
	var step_source: String = _code_of("res://src/content/quest/quest_step.gd")
	equal("quest_step.gd read", step_source.is_empty(), false)
	equal("a step gained no field for this", step_source.contains("@export var item"), false)
	equal("and names no Inventory either", step_source.contains("Inventory"), false)
	# THE JOURNAL OWN MUST NOT LINE, which is why the tracker has `step_progress` at all: the
	# screen needs the value of a flag and is forbidden from reading one.
	var journal: String = _code_of("res://src/ui/screens/journal_screen.gd")
	equal("journal_screen.gd read", journal.is_empty(), false)
	equal("and it reads no flag", journal.contains("Flags."), false)
	# AND THE PUBLISHER IS THE ONLY WRITER, which is what makes the check_content gate legitimate:
	# half a key is an item id, and one writer means one shape to validate.
	var bag: String = _code_of("res://src/gameplay/character/inventory.gd")
	equal("inventory.gd publishes the count key", bag.contains("BagKeys.key"), true)
	equal("and nothing else under src/ builds one",
			_files_naming_bag_keys(), ["res://src/gameplay/character/inventory.gd"])


## Every engine file that builds a bag key. One is correct; a second is the duplication `BagKeys`
## exists to prevent, and it would be invisible until the two disagreed.
func _files_naming_bag_keys() -> Array[String]:
	var out: Array[String] = []
	for path: String in _engine_scripts("res://src"):
		if _code_of(path).contains("BagKeys.key("):
			out.append(path)
	out.sort()
	return out


func _engine_scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	for directory: String in DirAccess.get_directories_at(root):
		out.append_array(_engine_scripts("%s/%s" % [root, directory]))
	for file_name: String in DirAccess.get_files_at(root):
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [root, file_name])
	return out


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## A file with its comment lines removed, so a scan can ask about behaviour rather than about
## prose. Whole-line comments only, which is all this project writes and all `check_boundary`
## strips for the same reason.
func _code_of(path: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in _source(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			out.append(line)
	return "\n".join(out)


## THE OBJECTIVE UNDER ONE NAMED QUEST, addressed through that quest's own row.
##
## IT USED TO RETURN THE LAST LABEL IN THE LIST, and that was a bet on the order
## `QuestTracker.ids_in_state` returns. The old comment here guarded the right way against the
## wrong risk — "found by type rather than by index, so a heading cannot make this assert about
## the wrong row" — while the order of the QUESTS was the thing that was not fixed: until T5.31
## `ids_in_state` sorted with `Array[StringName].sort()`, which orders by the interned handle
## rather than alphabetically (gotcha 33). So with two quests active this helper read whichever
## one the allocator happened to put last, and the bet came due the moment another system
## interned a name earlier in the boot — which is exactly how T5.31 found it.
##
## The journal draws a Button row and then that quest's objective Label, per quest, so the
## objective wanted is the first Label after the row carrying that quest's name.
func _objective_for(screen: JournalScreen, quest_id: StringName) -> Label:
	var wanted: String = tr(QuestDb.quest(quest_id).name_key)
	var under_it: bool = false
	for child: Node in screen._list.get_children():
		var row: Button = child as Button
		if row != null:
			under_it = row.text == wanted
			continue
		var label: Label = child as Label
		if under_it and label != null:
			return label
	return null


## A bag on a carrier of its own, with a `save_id` that is not the player and a `carrier_id`
## that is not either - two participants sharing a save id means one silently never saves, and
## two bags sharing a carrier id would publish over each other counts.
func _build_carrier() -> void:
	Fixtures.activate()
	_carrier = Node3D.new()
	_bag = Inventory.new()
	# Before add_child: `_ready` registers the save participant and declares the derived prefix.
	_bag.save_id = &"test_count_bag"
	_bag.carrier_id = FixtureContent.CARRIER
	_carrier.add_child(_bag)
	attach(_carrier)


func _tracker() -> QuestTracker:
	var tracker := QuestTracker.new()
	attach(tracker)
	return tracker


## Freed immediately rather than at the end of the case, for `quests_test.gd` reason: an
## unregistered save participant left alive would answer the next block collect as well.
func _free(tracker: QuestTracker) -> void:
	remove_child(tracker)
	tracker.free()
