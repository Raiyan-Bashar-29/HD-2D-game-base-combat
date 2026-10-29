class_name PauseMenuScreen
extends MenuScreen
## The menu the pause key raises. Resume, save, load, settings, controls, main menu, quit.
##
## IT DOES NOT PAUSE THE GAME. It declares `pauses_world = true` and `UiRoot` sets
## `get_tree().paused`, decides the UiMode, and announces it; the player's own components take
## their `&"ui"` token on hearing that. This screen contains no pause call, no input lock and no
## "is a menu open" boolean, and the whole of WP-02 exists so that stays true.
##
## RETURNING TO THE MAIN MENU DOES NOT TEAR THE WORLD DOWN, deliberately. The area stays loaded
## behind an opaque, world-stopping main menu, and the next New Game or Continue replaces it
## through the ordinary guarded transition - which fades out, unloads, and reports both ends in
## the log. Freeing the area from under a menu instead would leave `Director.current_area_id`
## empty, so the transition that followed would believe it was the first of the session and skip
## its fade-out entirely.
##
## OWNS: which rows the pause menu offers.
## MUST NOT: pause the tree, lock the player, unload an area, or write a save itself.

const SCREEN_ID: StringName = &"pause"
const TITLE_KEY: String = "ui.pause.title"
const STATUS_KEY: String = "ui.pause.status"
const AREA_PREFIX: String = "area."
const RESUME_KEY: String = "ui.pause.resume"
const SAVE_KEY: String = "ui.pause.save"
const LOAD_KEY: String = "ui.menu.load"
const SETTINGS_KEY: String = "ui.menu.settings"
const CONTROLS_KEY: String = "ui.menu.controls"
const MAIN_MENU_KEY: String = "ui.pause.main_menu"
const QUIT_KEY: String = "ui.menu.quit"
const HINT_KEY: String = "ui.pause.hint"


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


func _fill() -> void:
	add_note(_status())
	add_row(tr(RESUME_KEY), request_close)
	add_row(tr(SAVE_KEY), _on_save)
	if SaveSystem.latest_slot() >= 0:
		add_row(tr(LOAD_KEY), _on_load)
	add_row(tr(SETTINGS_KEY), _on_settings)
	add_row(tr(CONTROLS_KEY), _on_controls)
	add_row(tr(MAIN_MENU_KEY), _on_main_menu)
	add_row(tr(QUIT_KEY), _on_quit)


## Where you are and how long you have been there. Read from Director and SaveSystem rather
## than cached, so it cannot go stale between two openings of the same screen.
func _status() -> String:
	var area_id: StringName = Director.current_area_id
	var area_name: String = tr("%s%s.name" % [AREA_PREFIX, area_id]) if area_id != &"" else ""
	return tr(STATUS_KEY).format({
		"area": area_name,
		"played": played_as_text(SaveSystem.playtime()),
	})


func _on_save() -> void:
	push(SaveScreen.for_saving())


func _on_load() -> void:
	push(SaveScreen.new())


func _on_settings() -> void:
	push(SettingsScreen.new())


func _on_controls() -> void:
	push(RebindScreen.new())


## Ask to be closed FIRST, then ask for the menu. Both are honoured in the same idle frame, so
## the main menu lands on a stack this screen has already left rather than on top of it.
func _on_main_menu() -> void:
	request_close()
	Events.main_menu_requested.emit()


func _on_quit() -> void:
	Events.quit_requested.emit()
