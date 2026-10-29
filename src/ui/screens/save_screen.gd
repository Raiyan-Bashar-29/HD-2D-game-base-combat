class_name SaveScreen
extends MenuScreen
## The six slots, with their headers, in either direction: pick one to write, or pick one to
## restore. One screen for both, because a save list and a load list differ in exactly two
## things - the title, and whether an empty slot can be pressed.
##
## THE HEADER IS READ, NOT THE SAVE. `SaveSystem.slot_info` parses the file and drops the
## sections before handing anything back, so drawing this list can never apply a save by
## accident, and a slot whose SECTIONS are corrupt still shows a readable header.
##
## A FILE WHOSE HEADER CANNOT BE READ IS DAMAGED, NOT EMPTY. `slot_info` answers {} both for no
## file and for one `load_from_slot` would refuse, and until T6.4 this screen drew both as
## "empty" — inviting the player to believe a save they made was never there. `has_slot` tells
## the two apart. A damaged slot is a note when loading, for the empty slot's reason: pressing it
## can only fail. When saving it is a row, and it COUNTS AS OCCUPIED for the overwrite question —
## the file is still on disk, a player may be able to recover it by hand, and writing over it is
## as irreversible as writing over a good one. One press to answer is cheap; a lost file is not.
##
## AN EMPTY SLOT IS A NOTE WHEN LOADING AND A ROW WHEN SAVING. Not a disabled button: there is
## nothing to come back for in an empty slot, so showing one you cannot press teaches nothing.
## Same reasoning the dialogue system omits a failing choice by, and the deliberate opposite of
## the locked gate, which is shown precisely because it can be opened later.
##
## OWNS: the slot list, its headers, and which direction this instance is facing.
## MUST NOT: write, read or migrate a save file itself, decide what a section contains, or draw
## its own "are you sure" — `ConfirmScreen` asks every such question the same way.
## `SaveSystem` owns the format; this screen names a slot number and nothing else.

const SCREEN_ID: StringName = &"saves"
const SAVE_TITLE_KEY: String = "ui.save.title"
const LOAD_TITLE_KEY: String = "ui.load.title"
const SLOT_KEY: String = "ui.save.slot"
const EMPTY_KEY: String = "ui.save.empty"
const DAMAGED_KEY: String = "ui.save.damaged"
## A header with no place it can name: a save from before headers carried one, or an area with no
## `AreaDef`. Said, rather than the field silently dropped, so every row has the same shape.
const PLACE_UNKNOWN_KEY: String = "ui.save.place_unknown"
## The autosave reads as its own row and not as "Slot 7", because it is not one: it is outside
## the numbering the six manual rows share, and a number would invite the player to look for
## six others like it.
const AUTOSAVE_KEY: String = "ui.save.autosave"
const AUTOSAVE_EMPTY_KEY: String = "ui.save.autosave_empty"
const AUTOSAVE_DAMAGED_KEY: String = "ui.save.autosave_damaged"
const SAVED_KEY: String = "notify.game_saved"
const FAILED_KEY: String = "notify.save_failed"
const HINT_KEY: String = "ui.save.hint"
const OVERWRITE_KEY: String = "ui.save.overwrite"
const TOAST_SECONDS: float = 2.5

## Which way this instance faces. Set through `for_saving()` before the screen is opened, never
## afterwards: `_build` runs from `_ready`, which runs on add_child.
var writing: bool = false


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = LOAD_TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## The writing half. `SaveScreen.new()` is the reading half, which is the commoner case and so
## the default - the main menu offers loading and never offers saving.
static func for_saving() -> SaveScreen:
	var screen := SaveScreen.new()
	screen.writing = true
	screen.title_key = SAVE_TITLE_KEY
	return screen


## THE TWO DIRECTIONS LIST DIFFERENT THINGS, and that asymmetry IS the slot policy made visible.
## `MAX_SLOTS` is the manual range, so the writing half cannot offer the autosave slot and this
## screen needs no filter to avoid it — it simply never counts that high. The reading half adds
## it, because an autosave the player cannot come back to is not an autosave. Writing offers every
## slot; reading offers only one with a readable header, and says what the others are.
func _fill() -> void:
	for slot: int in SaveSystem.MAX_SLOTS:
		_add_slot(slot)
	if not writing:
		_add_slot(SaveSystem.AUTOSAVE_SLOT)


func _add_slot(slot: int) -> void:
	if writing or not SaveSystem.slot_info(slot).is_empty():
		add_row(slot_text(slot), _on_slot.bind(slot))
	else:
		add_note(slot_text(slot))


## What one slot's row says. Public so a test asserts the string the player reads rather than
## re-deriving the format and then asserting its own arithmetic.
func slot_text(slot: int) -> String:
	var info: Dictionary = SaveSystem.slot_info(slot)
	var auto: bool = SaveSystem.is_autosave(slot)
	if info.is_empty() and SaveSystem.has_slot(slot):
		return tr(AUTOSAVE_DAMAGED_KEY) if auto else tr(DAMAGED_KEY).format({"slot": slot + 1})
	if info.is_empty():
		return tr(AUTOSAVE_EMPTY_KEY) if auto else tr(EMPTY_KEY).format({"slot": slot + 1})
	var place: String = WorldMap.place_key(DictRead.get_dict(info, "header"))
	return tr(AUTOSAVE_KEY if auto else SLOT_KEY).format({
		"slot": slot + 1,
		"place": tr(PLACE_UNKNOWN_KEY if place == "" else place),
		"when": DictRead.get_string(info, "saved_utc", ""),
		"played": played_as_text(DictRead.get_float(info, "playtime_seconds", 0.0)),
	})


## AN OCCUPIED SLOT ASKS FIRST, AN EMPTY ONE DOES NOT. Overwriting is the one thing on this
## screen a player cannot take back, and an empty slot has nothing to lose — asking there too
## would teach the player to press through the question. The detail is the header about to go.
## `has_slot`, not a readable header, so a DAMAGED slot asks too; the header explains why.
func _on_slot(slot: int) -> void:
	if writing and SaveSystem.has_slot(slot):
		push(ConfirmScreen.asking(OVERWRITE_KEY, slot_text(slot), _write.bind(slot)))
		return
	if writing:
		_write(slot)
		return
	depart(_restore.bind(slot))


## Written in place, with the list redrawn over the top of it, so the new header is visible
## immediately. No curtain and no departure: saving does not hand control anywhere.
func _write(slot: int) -> void:
	var err: Error = SaveSystem.save_to_slot(slot)
	var key: String = SAVED_KEY if err == OK else FAILED_KEY
	Events.notify_requested.emit(key, TOAST_SECONDS, {"slot": slot + 1})
	refresh()


## A failed restore puts the curtain back up rather than leaving the player on black. The stack
## unwinds itself on the way out: `SaveSystem` hands the area to `Director`, which emits
## `area_change_requested`, which is what `ScreenKeys` closes every screen on.
func _restore(slot: int) -> void:
	if SaveSystem.load_from_slot(slot) == OK:
		return
	Log.error("ui", "Slot %d could not be restored" % slot)
	Events.screen_fade_requested.emit(false, DEPART_FADE)
	refresh()
