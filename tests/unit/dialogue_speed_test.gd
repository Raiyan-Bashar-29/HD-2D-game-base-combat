extends TestCase
## Dialogue for fast and slow readers (T6.7): a skip to the end of a conversation, and
## auto-advance. Split from `dialogue_test.gd` because that file is at its line budget, and
## because these assertions drive the SCREEN where that file drives the runner alone.
##
## The screen's frame clock is stepped by calling `_process` with a chosen delta: `TestCase.run()`
## is synchronous, so no real frame ever comes. That is what makes "half the hold is not enough"
## an exact assertion rather than a timing race.
##
## OWNS: when a skip or auto-advance moves a conversation on, and where each stops.
## MUST NOT: assert what the box looks like, which the windowed capture owns, or re-assert how a
## conversation branches, which is `dialogue_test.gd`.

const TALK: StringName = FixtureContent.TALK
const TALLY: StringName = FixtureContent.TALLY_FLAG

var _lines: Array[StringName] = []


func run() -> void:
	plan(25)
	Flags.clear_all()
	Fixtures.activate()
	_a_skip_keeps_every_effect_and_stops_at_a_choice()
	_a_skip_over_a_cycle_stops()
	_auto_advance_moves_plain_lines_and_waits_at_a_choice()
	# The .tres resources are cached by path, so every edit above was undone by hand; this only
	# drops the fixture root before the real one comes back.
	DialogueDb.rescan()
	Flags.clear_all()
## T6.7, FOR A FAST READER. A skip walks the runner rather than jumping it, so every node passed
## is arrived at and its effect fires; and it STOPS at a choice, because a branch is the player's
## to take. The effect is planted on the menu, which the skip reaches, and removed afterwards.
func _a_skip_keeps_every_effect_and_stops_at_a_choice() -> void:
	var menu: DialogueNode = DialogueDb.conversation(TALK).node(FixtureContent.MENU_NODE)
	menu.effect_flag = TALLY
	menu.effect_write = GameEnums.FlagWrite.ADD
	menu.effect_value = 1
	Flags.clear_all()
	_lines.clear()
	var screen: DialogueScreen = _open_screen()
	var closes: Array[int] = [0]
	screen.close_requested.connect(func() -> void: closes[0] += 1)
	equal("the box opens on the first line", _node_of(screen),
		FixtureContent.FIRST_NODE)

	screen.skip()
	equal("a skip stops at the choice", _node_of(screen),
		FixtureContent.MENU_NODE)
	equal("with the conversation still running", screen.runner.is_running(), true)
	equal("the choice is shown, not left hidden behind a reveal", screen._choice_box.visible, true)
	equal("and its line is whole", screen.reveal_complete(), true)
	equal("every node passed was announced", _lines,
		[FixtureContent.FIRST_NODE, FixtureContent.MENU_NODE] as Array[StringName])
	equal("the effect of the node it reached fired", Flags.get_int(TALLY), 1)
	screen.skip()
	equal("a second skip answers nothing", _node_of(screen),
		FixtureContent.MENU_NODE)
	equal("and fires nothing twice", Flags.get_int(TALLY), 1)

	equal("the player answers", screen.runner.take(_offered(screen, 0)), true)
	screen.skip()
	equal("a skip through a plain line lands on the next choice",
		_node_of(screen), FixtureContent.MENU_NODE)
	equal("arriving again fired again, as reading would have", Flags.get_int(TALLY), 2)

	var final_choice: DialogueChoice = _offered(screen, 1)
	equal("the player picks the closing line", screen.runner.take(final_choice), true)
	screen.skip()
	equal("with no choice left, a skip runs to the end", screen.runner.is_running(), false)
	equal("and the box asks to close, once", closes[0], 1)

	menu.effect_flag = &""
	menu.effect_write = GameEnums.FlagWrite.NONE
	menu.effect_value = 0
	_close_screen(screen)


## A cycle of plain lines is authorable, and a skip over one must stop rather than hang the game.
func _a_skip_over_a_cycle_stops() -> void:
	var onward: DialogueNode = DialogueDb.conversation(TALK).node(FixtureContent.ONWARD_NODE)
	onward.next_node = FixtureContent.ONWARD_NODE
	Flags.clear_all()
	var screen: DialogueScreen = _open_screen()
	screen.skip()
	screen.runner.take(_offered(screen, 0))
	screen.skip()
	equal("a cycling conversation stops the skip rather than the game",
		_node_of(screen), FixtureContent.ONWARD_NODE)
	onward.next_node = FixtureContent.MENU_NODE
	_close_screen(screen)


## T6.7, FOR A SLOW READER. Off by default and never hurried when off; on, a whole line is held
## for `hold_seconds()` and then moves on; and it never answers a choice.
func _auto_advance_moves_plain_lines_and_waits_at_a_choice() -> void:
	equal("auto-advance is off by default", Settings.DEFAULTS[DialogueScreen.AUTO_ADVANCE], false)
	Settings.set_value(DialogueScreen.AUTO_ADVANCE, false)
	Flags.clear_all()
	var screen: DialogueScreen = _open_screen()
	screen._process(100.0)
	screen._process(1000.0)
	equal("off, a whole line waits however long", _node_of(screen),
		FixtureContent.FIRST_NODE)
	var plain_hint: String = screen._hint.text

	Settings.set_value(DialogueScreen.AUTO_ADVANCE, true)
	equal("turning it on marks the hint at once", screen._hint.text != plain_hint, true)
	equal("and the hint still names the skip key",
		screen._hint.text.contains(KeyBindings.text_for(Actions.CANCEL, false)), true)
	var hold: float = screen.hold_seconds()
	equal("the hold is longer than the fixed part alone",
		hold > DialogueScreen.AUTO_HOLD_SECONDS, true)
	screen._process(hold * 0.5)
	equal("half the hold is not enough", _node_of(screen),
		FixtureContent.FIRST_NODE)
	screen._process(hold * 0.6)
	equal("the whole hold moves it on", _node_of(screen),
		FixtureContent.MENU_NODE)
	screen._process(100.0)
	screen._process(1000.0)
	equal("at a choice it waits for the player", _node_of(screen),
		FixtureContent.MENU_NODE)
	equal("still running", screen.runner.is_running(), true)

	Settings.set_value(DialogueScreen.AUTO_ADVANCE, false)
	_close_screen(screen)


func _open_screen() -> DialogueScreen:
	var screen: DialogueScreen = DialogueScreen.for_conversation()
	attach(screen)
	screen.runner.line_changed.connect(_on_line_changed)
	screen.runner.begin(TALK)
	return screen


func _close_screen(screen: DialogueScreen) -> void:
	screen.runner.stop()
	remove_child(screen)
	screen.queue_free()


func _on_line_changed(node: DialogueNode, _choices: Array[DialogueChoice]) -> void:
	_lines.append(node.node_id)


## Where the conversation stands, or nothing once it has ended. Null-safe so a broken skip fails
## on a named assertion rather than on a script error half-way through the case.
func _node_of(screen: DialogueScreen) -> StringName:
	var node: DialogueNode = screen.runner.current_node()
	return node.node_id if node != null else &""


func _offered(screen: DialogueScreen, index: int) -> DialogueChoice:
	var offered: Array[DialogueChoice] = screen.runner.available_choices()
	return offered[index] if index < offered.size() else null
