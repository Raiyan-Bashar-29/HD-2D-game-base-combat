class_name MainMenuScreen
extends MenuScreen
## The first thing the game shows. New game, continue, load, settings, controls, quit.
##
## THE BOOT PATH CHANGED FOR THIS SCREEN. GameRoot used to request `courtyard` in its _ready;
## it now emits `main_menu_requested` and this screen chooses. The comment above the old
## constant said "when the main menu exists, it will choose instead", and this is that.
##
## closes_on_cancel IS FALSE, and that is not an oversight. There is nothing behind the main
## menu to go back to - dismissing it would leave a paused, cameraless, empty world with no way
## to reach any screen again. It is the one screen in the game with no exit but its own rows.
##
## CONTINUE AND LOAD ARE OMITTED WHEN NO SAVE EXISTS, not shown disabled. Same reasoning the
## dialogue system uses for a failing choice, and the opposite of the locked gate: a gate you
## cannot open teaches you there is somewhere to come back to, while a Continue you cannot press
## teaches you only that saves are a thing. A first-run menu is New Game, Settings and Quit.
##
## OWNS: which rows the main menu offers and what each one asks for.
## MUST NOT: load an area itself, clear a flag itself, or pause anything. `Director` owns
## starting a game, `SaveSystem` owns restoring one, and `UiRoot` owns the pause.

const SCREEN_ID: StringName = &"main_menu"
const TITLE_KEY: String = "ui.menu.title"
const NEW_KEY: String = "ui.menu.new_game"
const CONTINUE_KEY: String = "ui.menu.continue"
## T5.10 named the autosave file rather than numbering it, precisely so nobody would read it as
## a seventh manual slot — and then the Continue row printed "Slot 7", which is that reading
## arriving by the one route the file name could not close. The slot is still what is LOADED;
## only the label changes, and the save screen has said "Autosave" since T5.10.
const CONTINUE_AUTOSAVE_KEY: String = "ui.menu.continue_autosave"
const LOAD_KEY: String = "ui.menu.load"
const SETTINGS_KEY: String = "ui.menu.settings"
const CONTROLS_KEY: String = "ui.menu.controls"
const QUIT_KEY: String = "ui.menu.quit"


## Flags in _init, never in _build. _build runs from _ready, i.e. after a caller has had its
## chance to override one, so setting them there silently discards the override.
func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = false
	title_key = TITLE_KEY
	opaque = true


func _fill() -> void:
	add_row(tr(NEW_KEY), _on_new_game)
	var latest: int = SaveSystem.latest_slot()
	if latest >= 0:
		add_row(_continue_text(latest), _on_continue.bind(latest))
		add_row(tr(LOAD_KEY), _on_load)
	add_row(tr(SETTINGS_KEY), _on_settings)
	add_row(tr(CONTROLS_KEY), _on_controls)
	add_row(tr(QUIT_KEY), _on_quit)


## What the Continue row says. A separate function rather than an inline ternary because the
## two keys take different arguments: one is numbered and one is named.
func _continue_text(slot: int) -> String:
	if slot == SaveSystem.AUTOSAVE_SLOT:
		return tr(CONTINUE_AUTOSAVE_KEY)
	return tr(CONTINUE_KEY).format({"slot": slot + 1})


func _on_new_game() -> void:
	depart(Director.start_new_game)


func _on_continue(slot: int) -> void:
	depart(_load_slot.bind(slot))


## Bound rather than inlined so `depart` still takes a plain Callable, and so the error path is
## in one place: a Continue that cannot read its own slot must put the curtain back up rather
## than leave the player looking at black.
func _load_slot(slot: int) -> void:
	if SaveSystem.load_from_slot(slot) == OK:
		return
	Log.error("ui", "Continue could not read slot %d" % slot)
	Events.screen_fade_requested.emit(false, DEPART_FADE)
	refresh()


func _on_load() -> void:
	push(SaveScreen.new())


func _on_settings() -> void:
	push(SettingsScreen.new())


func _on_controls() -> void:
	push(RebindScreen.new())


func _on_quit() -> void:
	Events.quit_requested.emit()
