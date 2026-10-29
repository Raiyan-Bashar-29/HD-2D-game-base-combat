extends TestCase
## A slot's header says where it was saved, and a slot whose header cannot be read says DAMAGED.
##
## THE DEFECT, AS IT STOOD. `SaveSystem.slot_info` answers {} for a file that does not parse, and
## `SaveScreen` drew every {} as "empty" — so a corrupted save told the player they had never
## made it. And nothing in a header named a place, because `core` cannot ask `Director` and
## nothing above it had been given a way to add to the header.
##
## THREE HALVES, EACH ABLE TO BREAK ALONE. The HOOK — `WorldMap` sets it, a second map replaces
## it, freeing the first does not blank the second — is asserted on `SaveSystem` directly. The
## HEADER is asserted through `slot_text`, the string the player reads. DAMAGED is asserted on
## files this case writes by hand, including one `slot_info` must refuse although it PARSES, and
## through both directions of a real screen, since a damaged slot is a note one way and a row
## that asks first the other.
##
## Fixture content only: the place is `FixtureContent.PLACE_A`, whose name key is deliberately
## untranslated, so `tr()` hands the key back and a row can be matched against it exactly.
## Every file lands in `SaveFixture.root()`, never in the player's own saves.
##
## OWNS: assertions about the save header's place, and the damaged slot.
## MUST NOT: re-assert the slot list's direction policy (menus_test.gd), the confirm screen itself
## (confirm_test.gd), or the loader's refusals (save_recovery_test.gd).

const PLACE: StringName = FixtureContent.PLACE_A
## An id no fixture and no game defines, so `AreaDb` has no name for it.
const UNMAPPED: StringName = &"slot_header_unmapped"
const MAPPED_SLOT: int = 0
const UNMAPPED_SLOT: int = 1
const BARE_SLOT: int = 2
const BROKEN_SLOT: int = 3
const FUTURE_SLOT: int = 4

var _stack: UiRoot = null
var _map: WorldMap = null
var _was_area: StringName = &""


func run() -> void:
	plan(32)
	_set_up()
	_the_map_sets_the_hook_and_takes_it_back()
	_a_header_names_where_it_was_saved()
	_a_place_it_cannot_name_is_said_so()
	_a_file_that_cannot_be_read_is_damaged_not_empty()
	_the_load_list_notes_a_damaged_slot()
	_overwriting_a_damaged_slot_still_asks()
	_the_keys_exist()
	_tear_down()


func _set_up() -> void:
	SaveFixture.activate()
	Fixtures.activate()
	_was_area = Director.current_area_id
	_stack = UiRoot.new()
	attach(_stack)
	_map = WorldMap.new()
	attach(_map)


## The hook is the map's while the map lives, and "only if it is still ours" is what lets a
## replacement survive the old one leaving.
func _the_map_sets_the_hook_and_takes_it_back() -> void:
	equal("a map in the tree sets the header hook", SaveSystem.header_provider.is_valid(), true)
	var second := WorldMap.new()
	attach(second)
	var theirs: Callable = SaveSystem.header_provider
	remove_child(_map)
	_map.free()
	equal("the first map leaving does not blank the second's hook",
		SaveSystem.header_provider == theirs and theirs.is_valid(), true)
	remove_child(second)
	second.free()
	equal("the last map leaving clears it", SaveSystem.header_provider.is_valid(), false)
	_map = WorldMap.new()
	attach(_map)


func _a_header_names_where_it_was_saved() -> void:
	Director.current_area_id = PLACE
	equal("a slot is written", SaveSystem.save_to_slot(MAPPED_SLOT), OK)
	var header: Dictionary = DictRead.get_dict(SaveSystem.slot_info(MAPPED_SLOT), "header")
	equal("its header carries the area id", DictRead.get_string(header, WorldMap.HEADER_AREA, ""),
		String(PLACE))
	var name_key: String = AreaDb.area(PLACE).name_key
	equal("and the map turns it back into that area's name key", WorldMap.place_key(header), name_key)
	var screen := SaveScreen.new()
	attach(screen)
	equal("the row the player reads names the place", screen.slot_text(MAPPED_SLOT).contains(tr(name_key)), true)
	equal("and still names the slot", screen.slot_text(MAPPED_SLOT).begins_with(
		tr(SaveScreen.SLOT_KEY).format({"slot": MAPPED_SLOT + 1}).get_slice("·", 0)), true)
	remove_child(screen)
	screen.free()


## Two ways to have no name, and both read the same: an area with no `AreaDef`, and a save written
## with no hook at all — which is every save made before T6.4.
func _a_place_it_cannot_name_is_said_so() -> void:
	var screen := SaveScreen.new()
	attach(screen)
	var unknown: String = tr(SaveScreen.PLACE_UNKNOWN_KEY)
	Director.current_area_id = UNMAPPED
	equal("a slot saved in an unmapped area is written", SaveSystem.save_to_slot(UNMAPPED_SLOT), OK)
	equal("the map has no name for it", WorldMap.place_key(
		DictRead.get_dict(SaveSystem.slot_info(UNMAPPED_SLOT), "header")), "")
	equal("so the row says the place is unknown", screen.slot_text(UNMAPPED_SLOT).contains(unknown), true)
	var hook: Callable = SaveSystem.header_provider
	SaveSystem.header_provider = Callable()
	equal("a slot is written with no hook set", SaveSystem.save_to_slot(BARE_SLOT), OK)
	equal("its header has no extras at all", SaveSystem.slot_info(BARE_SLOT).has("header"), false)
	equal("and its row says unknown too, rather than misprinting", screen.slot_text(BARE_SLOT).contains(unknown), true)
	SaveSystem.header_provider = hook
	remove_child(screen)
	screen.free()


## One file that does not parse and one that parses but that `load_from_slot` refuses. The second
## is the sharper case: its header is perfectly readable, and drawing it would offer a load that
## fails. Its stamp is the latest possible, so Continue would pick it if anything let it through.
func _a_file_that_cannot_be_read_is_damaged_not_empty() -> void:
	_write_raw(SaveSystem.slot_path(BROKEN_SLOT), "this is not json {{{")
	_write_raw(SaveSystem.slot_path(FUTURE_SLOT), '{"version":99,"saved_utc":"9999-12-31T23:59:59","sections":{}}')
	_write_raw(SaveSystem.slot_path(SaveSystem.AUTOSAVE_SLOT), "")
	var screen := SaveScreen.new()
	attach(screen)
	var damaged: String = tr(SaveScreen.DAMAGED_KEY).format({"slot": BROKEN_SLOT + 1})
	equal("a file that does not parse is damaged", screen.slot_text(BROKEN_SLOT), damaged)
	equal("which is not what an empty slot says",
		damaged != tr(SaveScreen.EMPTY_KEY).format({"slot": BROKEN_SLOT + 1}), true)
	equal("a file from a newer build has no header either", SaveSystem.slot_info(FUTURE_SLOT).is_empty(), true)
	equal("so it is damaged too", screen.slot_text(FUTURE_SLOT),
		tr(SaveScreen.DAMAGED_KEY).format({"slot": FUTURE_SLOT + 1}))
	equal("which agrees with the loader", SaveSystem.load_from_slot(FUTURE_SLOT), ERR_FILE_CORRUPT)
	equal("and Continue never points at it", SaveSystem.latest_slot() in [MAPPED_SLOT, UNMAPPED_SLOT, BARE_SLOT], true)
	equal("a damaged autosave says so as the autosave",
		screen.slot_text(SaveSystem.AUTOSAVE_SLOT), tr(SaveScreen.AUTOSAVE_DAMAGED_KEY))
	remove_child(screen)
	screen.free()


## Reading: a damaged slot is shown and cannot be pressed, for the empty slot's reason.
func _the_load_list_notes_a_damaged_slot() -> void:
	var loading := SaveScreen.new()
	_stack.open(loading)
	var texts: Array[String] = loading.row_texts()
	equal("the load list shows the damaged slot", texts.has(loading.slot_text(BROKEN_SLOT)), true)
	equal("but as a note: nothing it could load", _button(loading, loading.slot_text(BROKEN_SLOT)) == null, true)
	equal("while the three readable saves can be pressed", _button_count(loading), 3)
	_stack.close_all()


## Writing: DAMAGED COUNTS AS OCCUPIED. The file is on disk and may be recoverable by hand, so
## writing over it asks, with the damaged header as the detail; only "yes" replaces it.
func _overwriting_a_damaged_slot_still_asks() -> void:
	var saving := SaveScreen.for_saving()
	_stack.open(saving)
	var damaged: String = saving.slot_text(BROKEN_SLOT)
	var row: Button = _button(saving, damaged)
	equal("the save list offers the damaged slot as a row", row != null, true)
	if row == null:
		_stack.close_all()
		return
	row.pressed.emit()
	var asked: ConfirmScreen = _stack.top() as ConfirmScreen
	equal("pressing it asks first", asked != null and asked.detail == damaged, true)
	equal("and the damaged file is untouched while it asks", SaveSystem.slot_info(BROKEN_SLOT).is_empty(), true)
	if asked != null:
		asked.on_yes.call()
	equal("yes replaces it with a readable save", SaveSystem.slot_info(BROKEN_SLOT).is_empty(), false)
	_stack.close_all()


func _the_keys_exist() -> void:
	for key: String in [SaveScreen.DAMAGED_KEY, SaveScreen.AUTOSAVE_DAMAGED_KEY, SaveScreen.PLACE_UNKNOWN_KEY]:
		equal("key %s is translated" % key, tr(key) != key, true)
	equal("and both header rows have a place in them",
		tr(SaveScreen.SLOT_KEY).contains("{place}") and tr(SaveScreen.AUTOSAVE_KEY).contains("{place}"), true)


func _tear_down() -> void:
	Director.current_area_id = _was_area
	remove_child(_map)
	_map.free()
	_stack.close_all()
	remove_child(_stack)
	_stack.free()


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _button(screen: MenuScreen, text_value: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text_value:
			return button
	return null


func _button_count(screen: MenuScreen) -> int:
	var count: int = 0
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion():
			count += 1
	return count
