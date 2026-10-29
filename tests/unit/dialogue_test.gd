extends TestCase
## The dialogue runner: conditions, branching, effects, and what happens to a conversation that
## is saved in the middle.
##
## THE HEADLINE ASSERTION IS _the_whole_exit_criterion(). One conversation that reads a flag,
## branches on it, sets another, and is then saved mid-line — which is the WP-05 criterion
## verbatim, walked in one go rather than inferred from four separate cases.
##
## Driven through the runner directly, never through the screen: `TestCase.run()` is
## synchronous, so a typewriter reveal that needs frames cannot be asserted here. What the box
## draws is proved by a windowed capture instead.
##
## OWNS: assertions about conversation data, condition evaluation, branching and effects.
## MUST NOT: assert what the dialogue box looks like, or re-assert the input lock. ui_test.gd
## owns the lock, and the capture owns the look.

const TALK: StringName = FixtureContent.TALK
const MET: StringName = FixtureContent.MET_FLAG
const TALLY: StringName = FixtureContent.TALLY_FLAG
const SLOT: int = 4

var _runner: DialogueRunner = null
var _lines: Array[StringName] = []
var _started: Array[StringName] = []
var _ended: Array[StringName] = []


func run() -> void:
	plan(65)
	_the_authored_catalogue_is_sound()
	_set_up()
	_the_catalogue_is_sound()
	_conditions_choose_the_entry_point()
	_a_hidden_choice_is_omitted_not_disabled()
	_a_dangling_link_ends_it_rather_than_hanging()
	_the_whole_exit_criterion()
	_a_node_whose_choices_all_fail_still_advances()
	_a_choice_is_taken_by_identity_not_by_index()
	_a_stale_choice_is_refused()
	_tear_down()


## The conversations a GAME has authored, checked as data. Every rule the runner has is proved
## below against a fixture graph instead, so this block is the only part that needs the demo -
## and what it is really asking is whether the authoring format is still being authored right.
func _the_authored_catalogue_is_sound() -> void:
	if not Fixtures.has_demo_content():
		skip("the authored conversations are sound", "no content in data/dialogue", 2)
		return
	DialogueDb.rescan()
	equal("the authored catalogue is clean: %s" % str(DialogueDb.problems()),
		DialogueDb.problems().size(), 0)
	var dangling: int = 0
	for talk_id: StringName in DialogueDb.all():
		dangling += DialogueDb.conversation(talk_id).problems().size()
	equal("no authored conversation has a dangling link", dangling, 0)


func _set_up() -> void:
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Flags.clear_all()
	Fixtures.activate()
	_runner = DialogueRunner.new()
	_runner.name = "TestRunner"
	attach(_runner)
	_runner.line_changed.connect(_on_line_changed)
	Events.dialogue_started.connect(_on_started)
	Events.dialogue_finished.connect(_on_ended)


## The authored conversation, checked as data before anything walks it. A test that only walks
## the happy path passes on a conversation with three broken links in the branches nobody took.
func _the_catalogue_is_sound() -> void:
	equal("the fixture conversation exists", DialogueDb.has(TALK), true)
	equal("and the catalogue is clean", DialogueDb.problems().size(), 0)
	var talk: Conversation = DialogueDb.conversation(TALK)
	equal("its id matches its filename", talk.id, TALK)
	equal("it has nodes", talk.nodes.size() > 0, true)
	equal("no dangling links anywhere in it", talk.problems().size(), 0)
	equal("an invented conversation is null", DialogueDb.conversation(&"talk/nobody"), null)


## The entry point is the first node whose condition PASSES, not nodes[0]. That is what makes
## "greet me differently once we have met" two nodes in authored order and no wiring at all.
func _conditions_choose_the_entry_point() -> void:
	Flags.clear_all()
	equal("a stranger is greeted", _runner.begin(TALK), true)
	equal("with the first-meeting line", _runner.current_node().node_id, FixtureContent.FIRST_NODE)
	equal("and dialogue_started was announced", _started, [TALK] as Array[StringName])
	equal("arriving set the met flag", Flags.get_bool(MET), true)
	equal("a second begin is refused while running", _runner.begin(TALK), false)
	_runner.stop()
	equal("and dialogue_finished was announced", _ended, [TALK] as Array[StringName])

	equal("now the same call greets an acquaintance", _runner.begin(TALK), true)
	equal("with the other line", _runner.current_node().node_id, FixtureContent.AGAIN_NODE)
	equal("which counts the visit", Flags.get_int(TALLY), 1)
	_runner.stop()
	equal("and again", _runner.begin(TALK), true)
	equal("counting each time", Flags.get_int(TALLY), 2)
	_runner.stop()


## A choice whose condition fails is NOT SHOWN, and `choose(index)` indexes what is on screen
## rather than the authored array. The two differ the moment a condition hides an option, and
## indexing the wrong one silently takes the wrong branch.
func _a_hidden_choice_is_omitted_not_disabled() -> void:
	var talk: Conversation = DialogueDb.conversation(TALK)
	var menu: DialogueNode = talk.node(FixtureContent.MENU_NODE)
	equal("the menu exists", menu != null, true)
	var authored: int = menu.choices.size()
	equal("it has more than one option", authored > 1, true)

	# Hide the first option by giving it a condition that cannot pass right now.
	var hidden: DialogueChoice = menu.choices[0]
	var restore_flag: StringName = hidden.condition_flag
	var restore_test: GameEnums.FlagTest = hidden.condition_test
	hidden.condition_flag = &"test/never"
	hidden.condition_test = GameEnums.FlagTest.IS_TRUE

	Flags.clear_all()
	equal("the conversation opens", _runner.begin(TALK), true)
	_runner.advance()
	equal("we are at the menu", _runner.current_node().node_id, FixtureContent.MENU_NODE)
	var offered: Array[DialogueChoice] = _runner.available_choices()
	equal("one option is withheld", offered.size(), authored - 1)
	equal("and it is not the hidden one", offered.has(hidden), false)
	equal("choosing past the end is refused", _runner.choose(offered.size()), false)
	equal("and a negative index too", _runner.choose(-1), false)
	_runner.stop()

	hidden.condition_flag = restore_flag
	hidden.condition_test = restore_test
	Flags.clear_all()
	equal("restored, every option is offered again", _offered_count_at_menu(), authored)


## A `next_node` naming a node that does not exist must END the conversation and hand control
## back. The alternative is a player standing in a box with no way out, which is worse than a
## conversation that stops early.
func _a_dangling_link_ends_it_rather_than_hanging() -> void:
	var talk: Conversation = DialogueDb.conversation(TALK)
	var node: DialogueNode = talk.node(FixtureContent.ONWARD_NODE)
	var restore: Array[DialogueChoice] = node.choices.duplicate()
	var restore_next: StringName = node.next_node
	node.choices = [] as Array[DialogueChoice]
	node.next_node = &"nowhere_at_all"

	Flags.clear_all()
	_ended.clear()
	equal("it opens", _runner.begin(TALK), true)
	_runner.advance()
	equal("at the menu", _runner.current_node().node_id, FixtureContent.MENU_NODE)
	equal("taking the first branch works", _runner.choose(0), true)
	equal("we reached the broken node", _runner.current_node().node_id, FixtureContent.ONWARD_NODE)
	_runner.advance()
	equal("the dangling link ended it", _runner.is_running(), false)
	equal("and control was handed back", _ended, [TALK] as Array[StringName])

	node.choices = restore
	node.next_node = restore_next


## THE HEADLINE, and the WP-05 exit criterion walked end to end: read a flag, branch on it, set
## another, then save in the middle.
func _the_whole_exit_criterion() -> void:
	Flags.clear_all()
	Flags.set_flag(MET, true)
	_lines.clear()

	equal("it READ the flag and branched", _runner.begin(TALK), true)
	equal("taking the acquaintance line", _runner.current_node().node_id, FixtureContent.AGAIN_NODE)
	equal("and SET another flag on arrival", Flags.get_int(TALLY), 1)
	_runner.advance()
	equal("we are at the branch", _runner.current_node().node_id, FixtureContent.MENU_NODE)
	equal("every line was announced to the UI", _lines.size(), 2)
	equal("taking a branch moves us", _runner.choose(1), true)
	equal("to the node the choice named", _runner.current_node().node_id, FixtureContent.FINAL_NODE)

	# SAVED MID-CONVERSATION. The conversation is deliberately not persisted: a saved node id
	# would make every node id in every .tres a permanent public identifier, and renaming one
	# would load old saves into a position that no longer exists.
	equal("the save succeeds", SaveSystem.save_to_slot(SLOT), OK)
	equal("and the conversation is still running for the player", _runner.is_running(), true)
	_ended.clear()

	equal("the load succeeds", SaveSystem.load_from_slot(SLOT), OK)
	equal("the conversation was ENDED rather than resumed", _runner.is_running(), false)
	equal("control was handed back", _ended.has(TALK), true)
	equal("the flags it set survived", Flags.get_bool(MET), true)
	equal("including the counter", Flags.get_int(TALLY), 1)
	SaveSystem.delete_slot(SLOT)


func _offered_count_at_menu() -> int:
	_runner.begin(TALK)
	_runner.advance()
	var count: int = _runner.available_choices().size()
	_runner.stop()
	return count


func _on_line_changed(node: DialogueNode, _choices: Array[DialogueChoice]) -> void:
	_lines.append(node.node_id)


func _on_started(talk_id: StringName) -> void:
	_started.append(talk_id)


func _on_ended(talk_id: StringName) -> void:
	_ended.append(talk_id)


func _tear_down() -> void:
	if _runner != null:
		_runner.stop()
	if Events.dialogue_started.is_connected(_on_started):
		Events.dialogue_started.disconnect(_on_started)
	if Events.dialogue_finished.is_connected(_on_ended):
		Events.dialogue_finished.disconnect(_on_ended)
	# Every field this case edits, it edits back, and it has to: the .tres resources are CACHED
	# by path, so a reload hands back the SAME instance with the edit still on it. Reloading is
	# still worth doing - it drops the fixture root's entries before the runner restores the
	# real one - but it is not what undoes an edit.
	DialogueDb.rescan()
	Flags.clear_all()
	_runner = null


## THE SOFT-LOCK. A node whose every choice fails its condition rendered a box with no buttons
## that would not advance and could not be escaped, because `advance()` asked the AUTHORED array
## while the screen drew the FILTERED one. `closes_on_cancel` is false for a conversation and
## the inventory key refuses while a screen is up, so the only way out was killing the process.
func _a_node_whose_choices_all_fail_still_advances() -> void:
	var talk: Conversation = DialogueDb.conversation(TALK)
	var menu: DialogueNode = talk.node(FixtureContent.MENU_NODE)
	var restore: Array[GameEnums.FlagTest] = []
	for choice: DialogueChoice in menu.choices:
		restore.append(choice.condition_test)
		choice.condition_flag = &"test/never_true"
		choice.condition_test = GameEnums.FlagTest.IS_TRUE

	Flags.clear_all()
	_ended.clear()
	equal("the conversation opens", _runner.begin(TALK), true)
	_runner.advance()
	equal("we reach the branch node", _runner.current_node().node_id, FixtureContent.MENU_NODE)
	equal("it authored some choices", menu.choices.size() > 0, true)
	equal("but none are on offer", _runner.available_choices().size(), 0)
	_runner.advance()
	equal("advancing is NOT swallowed", _runner.is_running(), false)
	equal("and control came back", _ended.has(TALK), true)

	for index: int in menu.choices.size():
		menu.choices[index].condition_flag = &""
		menu.choices[index].condition_test = restore[index]


## A UI must name the choice it drew, not its position. The world keeps running behind a
## dialogue box, so a flag written while it is open can hide an option and shift every index
## under the player's finger between the frame a button was built and the frame it was pressed.
func _a_choice_is_taken_by_identity_not_by_index() -> void:
	Flags.clear_all()
	equal("the conversation opens", _runner.begin(TALK), true)
	_runner.advance()
	var offered: Array[DialogueChoice] = _runner.available_choices()
	equal("three options are offered", offered.size(), 3)
	# A LATER option that leads somewhere. It must not be the one about to be hidden, and it
	# must not be the goodbye - taking that ends the conversation and asserts nothing about
	# where we landed.
	var target: DialogueChoice = null
	for index: int in range(1, offered.size()):
		if offered[index].target_node != &"" and target == null:
			target = offered[index]
	equal("a later option leads somewhere", target != null, true)

	# Hide the FIRST option, exactly as a flag written mid-conversation would. Every index at or
	# below the target now points one place to the left.
	offered[0].condition_flag = &"test/never_true"
	offered[0].condition_test = GameEnums.FlagTest.IS_TRUE
	equal("only two remain", _runner.available_choices().size(), 2)
	equal("the target moved down an index",
		_runner.available_choices().find(target), offered.find(target) - 1)

	equal("taking the object still works", _runner.take(target), true)
	equal("and lands where THAT option pointed", _runner.current_node().node_id,
		target.target_node)

	offered[0].condition_flag = &""
	offered[0].condition_test = GameEnums.FlagTest.ALWAYS
	_runner.stop()


## A choice that has left the offer between drawing and pressing is REFUSED, not silently
## resolved to a neighbour. Firing the wrong node's effect is worse than doing nothing.
func _a_stale_choice_is_refused() -> void:
	Flags.clear_all()
	equal("the conversation opens", _runner.begin(TALK), true)
	_runner.advance()
	var offered: Array[DialogueChoice] = _runner.available_choices()
	var vanishing: DialogueChoice = offered[0]
	var before: StringName = _runner.current_node().node_id

	vanishing.condition_flag = &"test/never_true"
	vanishing.condition_test = GameEnums.FlagTest.IS_TRUE
	equal("the stale choice is refused", _runner.take(vanishing), false)
	equal("and nothing moved", _runner.current_node().node_id, before)
	equal("a null choice is refused too", _runner.take(null), false)

	vanishing.condition_flag = &""
	vanishing.condition_test = GameEnums.FlagTest.ALWAYS
	_runner.stop()
