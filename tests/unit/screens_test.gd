extends TestCase
## What the two real screens of WP-03 actually render, and what opens them.
##
## THE HEADLINE ASSERTION IS _rows_follow_the_bag(). A screen bound to `inventory_changed`
## that does not redraw is the failure this file exists to catch, and it is invisible to every
## other rung: the boot run reports no error, the budget checker is happy, and the picture
## looks right because the capture was taken before anything changed.
##
## Driven by direct calls, never by simulated input: TestCase.run() is synchronous, so the
## screens are opened through UiRoot.open() and ScreenKeys is asked for its binding directly.
##
## OWNS: assertions about rendered rows, headings, focus and the localization keys behind them.
## MUST NOT: re-assert the pause table or the input lock. ui_test.gd owns those.

const PETAL: StringName = FixtureContent.STACK_ITEM
const KEY_ITEM: StringName = FixtureContent.UNIQUE_ITEM
const GHOST: StringName = &"item/nothing_here"

var _stack: UiRoot = null
var _bag: Inventory = null
var _carrier: Node = null


func run() -> void:
	plan(60)
	_set_up()
	_empty_bag_says_so()
	_rows_follow_the_bag()
	_a_missing_definition_still_shows()
	_the_key_binds_to_the_screen()
	_hud_clock_reads_the_clock()
	_every_key_this_package_uses_exists()
	_tear_down()


func _set_up() -> void:
	Fixtures.activate()
	_stack = UiRoot.new()
	attach(_stack)
	_carrier = Node.new()
	_bag = Inventory.new()
	# A save_id of its own: "inventory" is the player's, and two participants sharing one
	# means the second silently replaces the first.
	_bag.save_id = &"test_screen_bag"
	_carrier.add_child(_bag)
	attach(_carrier)


## The empty state is a real state, not an oversight. A bag with nothing in it must say so
## rather than render a blank panel the player reads as a broken screen.
func _empty_bag_says_so() -> void:
	var screen: InventoryScreen = InventoryScreen.for_carrier(_carrier)
	equal("the screen declares its id", screen.screen_id, InventoryScreen.SCREEN_ID)
	equal("and that it stops the world", screen.pauses_world, true)
	equal("it opens", _stack.open(screen), true)
	equal("an empty bag draws one line", _row_texts(screen).size(), 1)
	equal("and it is the empty message", _row_texts(screen)[0], tr(InventoryScreen.EMPTY_KEY))
	equal("nothing has focus, because nothing is focusable", _focused_text(screen), "")
	equal("it closes", _stack.close_top(), true)


## THE HEADLINE. Open the screen, change the bag behind it, and the rows must follow without
## anyone telling the screen to redraw.
func _rows_follow_the_bag() -> void:
	_bag.add(PETAL, 3)
	var screen: InventoryScreen = InventoryScreen.for_carrier(_carrier)
	equal("the screen opens over one item", _stack.open(screen), true)
	var rows: Array[String] = _row_texts(screen)
	equal("a heading and a row", rows.size(), 2)
	equal("the heading is the category", rows[0], tr("item.category.material"))
	equal("the row names the item and the count", rows[1], "%s  x3" % _name_of(PETAL))
	equal("the first row has focus", _focused_text(screen), rows[1])

	_bag.add(KEY_ITEM, 1)
	rows = _row_texts(screen)
	equal("the screen followed inventory_changed", rows.size(), 4)
	# ids() sorts by category ordinal, and KEY_ITEM (2) precedes MATERIAL (4).
	equal("key items come first", rows[0], tr("item.category.key_item"))
	equal("with their row", rows[1], "%s  x1" % _name_of(KEY_ITEM))
	equal("then materials", rows[2], tr("item.category.material"))

	_bag.remove(PETAL, 3)
	rows = _row_texts(screen)
	equal("removing follows too", rows.size(), 2)
	equal("leaving only the key", rows[1], "%s  x1" % _name_of(KEY_ITEM))
	equal("the screen closes", _stack.close_top(), true)
	equal("a closed screen is out of the tree", screen.is_inside_tree(), false)


## Inventory keeps a count whose .tres has vanished, on purpose, so that a renamed definition
## cannot silently delete a player's key item. The screen has to be able to draw one.
func _a_missing_definition_still_shows() -> void:
	_bag.clear_all()
	equal("no definition exists for the ghost", ItemDb.has(GHOST), false)
	# add() refuses an unknown id by design, so the count arrives the way a stale save's does.
	_bag._apply_save({String(GHOST): 2}, Inventory.SAVE_VERSION)
	var screen: InventoryScreen = InventoryScreen.for_carrier(_carrier)
	equal("the screen opens", _stack.open(screen), true)
	var rows: Array[String] = _row_texts(screen)
	equal("the ghost is grouped under unknown", rows[0], tr(InventoryScreen.UNKNOWN_KEY))
	equal("and its row names the raw id", rows[1].contains(String(GHOST)), true)
	equal("so the count is still visible", rows[1].contains("x2"), true)
	equal("the screen closes", _stack.close_top(), true)
	_bag.clear_all()


## The binding, without simulated input. Pressing I twice must open and then close, and must
## never open a second window over something else.
func _the_key_binds_to_the_screen() -> void:
	var keys := ScreenKeys.new()
	attach(keys)
	equal("the key opens the inventory", keys.toggle_inventory(_stack), true)
	equal("the stack has it", _stack.has_screen(InventoryScreen.SCREEN_ID), true)
	equal("pressing it again closes it", keys.toggle_inventory(_stack), true)
	equal("and the stack is empty", _stack.depth(), 0)

	var other := InventoryScreen.new()
	other.screen_id = &"pretend_confirmation"
	equal("something else is on top", _stack.open(other), true)
	equal("the key does not reach past it", keys.toggle_inventory(_stack), false)
	equal("and opened nothing", _stack.depth(), 1)
	equal("cleanup", _stack.close_top(), true)
	keys.queue_free()


## The clock readout, driven by the real Clock rather than by a fabricated signal, so the
## assertion fails if minute_passed ever stops carrying what the HUD reads.
func _hud_clock_reads_the_clock() -> void:
	var script: GDScript = load("res://src/ui/hud/hud_clock.gd") as GDScript
	var made: Object = script.new()
	var readout: Label = made as Label
	attach(readout)
	Clock.set_time(3, 19, 5)
	equal("the HUD names the day", readout.text.contains("3"), true)
	equal("and the time", readout.text.contains("19:05"), true)
	equal("and the phase, localized", readout.text.contains(tr("time.phase.dusk")), true)
	equal("no key leaked through untranslated", readout.text.contains("time.phase."), false)
	Clock.set_time(1, 6, 0)
	equal("and it followed the change", readout.text.contains("06:00"), true)
	readout.queue_free()


## tr() returns the key itself when a row is missing, so a key that renders as its own name is
## the failure mode. Asserted mechanically for the enum-built keys, exactly as the prompt's
## verb keys are, because no text scan can find a key that is never written down whole.
func _every_key_this_package_uses_exists() -> void:
	for entry: String in GameEnums.ItemCategory.keys():
		var key: String = "%s%s" % [InventoryScreen.CATEGORY_PREFIX, entry.to_lower()]
		equal("category key %s is translated" % key, tr(key) != key, true)
	for entry: String in GameEnums.DayPhase.keys():
		var key: String = "time.phase.%s" % entry.to_lower()
		equal("phase key %s is translated" % key, tr(key) != key, true)
	for key: String in [
		InventoryScreen.TITLE_KEY, InventoryScreen.EMPTY_KEY, InventoryScreen.HINT_KEY,
		InventoryScreen.ROW_KEY, InventoryScreen.UNKNOWN_KEY, "ui.hud.clock",
	]:
		equal("screen key %s is translated" % key, tr(key) != key, true)


## Every Label and Button under the list, in draw order. The screen exposes no model of its
## rows on purpose, so the test reads what is actually on screen rather than what the screen
## believes it drew.
func _row_texts(screen: InventoryScreen) -> Array[String]:
	var out: Array[String] = []
	for child: Node in _list_of(screen).get_children():
		# A row freed by the last refresh is still a child until the frame ends, and this
		# suite never reaches a frame boundary.
		if child.is_queued_for_deletion():
			continue
		var label: Label = child as Label
		var button: Button = child as Button
		if label != null:
			out.append(label.text)
		elif button != null:
			out.append(button.text)
	return out


func _focused_text(screen: InventoryScreen) -> String:
	for child: Node in _list_of(screen).get_children():
		var button: Button = child as Button
		if button != null and button.has_focus():
			return button.text
	return ""


func _list_of(screen: InventoryScreen) -> VBoxContainer:
	return screen._list


## What the screen must draw for an item: whatever tr() makes of its authored name_key. Read
## from the definition rather than written out, so this asserts the SCREEN and not the CSV -
## a fixture item deliberately has no row, and tr() then returns the key unchanged.
func _name_of(item_id: StringName) -> String:
	return tr(ItemDb.definition(item_id).name_key)


func _tear_down() -> void:
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	_bag = null
	_carrier = null
