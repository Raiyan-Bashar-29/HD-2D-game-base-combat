extends TestCase
## Losing window focus: who announces it, what each latch the base owns does on hearing it, and
## the setting that turns it into a pause.
##
## WHAT IS NOT HERE, AND WHY. The engine's own half - a key held at the moment of an alt-tab reads
## released afterwards - was MEASURED windowed at T6.5 with injected keystrokes, not asserted:
## headless has no window to lose. The DEVLOG entry has the command and the numbers. What stays is
## the base's half, the state no engine can know to drop.
##
## FOCUS LOSS ARRIVES BY `propagate_notification()`, WHICH IS HOW THE ENGINE SENDS IT, and that is
## the lesson of this row. The first version of this file called `notification()` on the stack
## alone, which does not mark it busy, and passed over a pause menu the windowed run showed could
## not be added: the engine was mid-walk of the stack. So the first case propagates, and
## asserts nothing is answered inside the walk. After that the cases call
## `UiRoot.announce_focus_lost()`, the deferred call's target. Nothing here emits the bus signal.
##
## THE LATCHES ARE SET BY WRITING THE FIELD, on `settings_effects_test.gd`'s precedent for
## `Director._transitioning`: the suite is synchronous and cannot press a key, so a toggled run
## and a hold part-way to firing can only be reached by putting them there.
##
## OWNS: the announcement, the three latches, and pause-on-focus-loss.
## MUST NOT: re-assert the pause table (ui_test.gd), the pause key (menus_test.gd), or a rebind
##   itself (menus_test.gd), and must not name demo content.

const SETTING: String = ScreenKeys.PAUSE_ON_FOCUS_LOSS
const PLAYER_SCENE: String = "res://scenes/characters/player.tscn"
const STEP: float = 1.0 / 60.0

var _stack: UiRoot = null
var _keys: ScreenKeys = null
var _heard: int = 0
var _was: bool = false


func run() -> void:
	plan(30)
	_set_up()
	_the_root_announces_application_focus_loss_only()
	_a_toggled_run_is_released()
	_a_hold_in_progress_is_dropped()
	_a_rebind_stops_listening()
	_pausing_is_opt_in()
	_pausing_happens_only_where_the_pause_key_would()
	_the_setting_is_drawn()
	_tear_down()


func _set_up() -> void:
	_was = Settings.get_bool(SETTING)
	Settings.set_value(SETTING, false)
	_stack = UiRoot.new()
	attach(_stack)
	_keys = ScreenKeys.new()
	attach(_keys)
	Events.focus_lost.connect(_on_focus_lost)


func _tear_down() -> void:
	Events.focus_lost.disconnect(_on_focus_lost)
	_stack.close_all()
	Settings.set_value(SETTING, _was)
	_keys.free()
	_stack.free()


func _lose_focus() -> void:
	_stack.announce_focus_lost()


## APPLICATION focus and not WINDOW focus: a popup of this game taking focus is not the player
## leaving, and a focus coming BACK is not a loss.
##
## THE PLANT THIS CASE IS FOR: emit inside `_notification` again, and the propagation below is
## answered mid-walk - `_heard` reads 1 and the stack records a pause menu the engine refused.
func _the_root_announces_application_focus_loss_only() -> void:
	equal("losing the application's focus is a focus loss",
		UiRoot.is_focus_loss(Node.NOTIFICATION_APPLICATION_FOCUS_OUT), true)
	equal("getting it back is not",
		UiRoot.is_focus_loss(Node.NOTIFICATION_APPLICATION_FOCUS_IN), false)
	equal("and one window losing it to another of ours is not either",
		UiRoot.is_focus_loss(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT), false)
	Settings.set_value(SETTING, true)
	_stack.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	equal("the engine's propagation is not answered inside itself", _heard, 0)
	equal("so nothing is added to the stack mid-walk", _stack.depth(), 0)
	Settings.set_value(SETTING, false)
	_lose_focus()
	equal("the deferred announcement is heard once", _heard, 1)
	_a_screen_the_engine_refuses_is_not_recorded()



## THE STACK'S OWN HALF OF GOTCHA 80. Even a listener that DOES open a screen inside a propagation -
## a game's, say - must not strand the player: `open` refuses rather than recording a screen the
## engine would not add. A child of the stack opens one while the engine walks the stack.
func _a_screen_the_engine_refuses_is_not_recorded() -> void:
	var opener := Opener.new()
	opener.stack = _stack
	_stack.add_child(opener)
	_stack.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	equal("a screen opened mid-propagation is refused", opener.opened, false)
	equal("and the stack does not record it", _stack.depth(), 0)
	equal("so the world is not paused under nothing", _stack.mode(), GameEnums.UiMode.GAMEPLAY)
	opener.free()

## The SETTING stays on: dropping the toggle is not the same as turning toggle-run off.
func _a_toggled_run_is_released() -> void:
	var player: PlayerController = build(PLAYER_SCENE) as PlayerController
	attach(player)
	player.run_is_toggle = true
	player._run_toggled = true
	equal("a toggled run is running", player._is_running(), true)
	_lose_focus()
	equal("focus loss drops it", player._is_running(), false)
	equal("but toggle-run is still the player's choice", player.run_is_toggle, true)
	player.free()


## The TARGET is kept, so the prompt still has something to offer the moment the player returns.
func _a_hold_in_progress_is_dropped() -> void:
	var body := CharacterBody3D.new()
	var sensor := InteractionSensor.new()
	body.add_child(sensor)
	attach(body)
	var chest := Interactable.new()
	chest.hold_seconds = 1.0
	chest.label_key = "fixture.target.label"
	attach(chest)
	sensor._current = chest
	sensor._hold = 0.5
	equal("a hold is half way", sensor.hold_progress(), 0.5)
	_lose_focus()
	equal("focus loss drops it to nothing", sensor.hold_progress(), 0.0)
	equal("and keeps the target", sensor.current() == chest, true)
	chest.free()
	body.free()


func _a_rebind_stops_listening() -> void:
	var screen := RebindScreen.new()
	equal("the controls screen opens", _stack.open(screen), true)
	var action: StringName = Actions.REBINDABLE[0]
	screen.listen(action)
	equal("a row is waiting for a key", screen.listening(), action)
	_lose_focus()
	equal("focus loss stops the wait", screen.listening(), &"")
	equal("and the row reads its binding again", screen.row_text(action) == tr(RebindScreen.LISTENING_KEY).format({"action": tr(RebindScreen.action_key(action))}), false)
	equal("the screen itself stays open", _stack.depth(), 1)
	_stack.close_all()


## Off by default, and OPEN rather than toggle: the window going twice must not close the menu.
func _pausing_is_opt_in() -> void:
	equal("pausing on focus loss is off out of the box", Settings.DEFAULTS[SETTING], false)
	equal("the keys find this stack, so the bus route is the one under test", UiRoot.find(_keys) == _stack, true)
	_lose_focus()
	equal("off, losing focus opens nothing", _stack.depth(), 0)
	Settings.set_value(SETTING, true)
	_lose_focus()
	equal("on, it opens the pause menu", _stack.has_screen(PauseMenuScreen.SCREEN_ID), true)
	equal("which stops the world", _stack.mode(), GameEnums.UiMode.MODAL)
	_lose_focus()
	equal("losing it again leaves the menu up", _stack.depth(), 1)
	_stack.close_all()
	Settings.set_value(SETTING, false)


## Over another screen the pause key does nothing, and neither does the window.
func _pausing_happens_only_where_the_pause_key_would() -> void:
	Settings.set_value(SETTING, true)
	var other := RebindScreen.new()
	equal("another screen is up", _stack.open(other), true)
	equal("over a screen, focus loss opens no pause menu", _keys.pause_for_focus_loss(_stack), false)
	equal("so the stack is unchanged", _stack.depth(), 1)
	_stack.close_all()
	Settings.set_value(SETTING, false)


## `settings_screen.gd` generates a row per key, so the row's label key has to exist.
func _the_setting_is_drawn() -> void:
	var label_key: String = "ui.settings.%s" % SETTING.replace("/", ".")
	equal("the setting's row has a translation", tr(label_key) != label_key, true)


func _on_focus_lost() -> void:
	_heard += 1


## Opens a screen from inside a notification, as a careless listener would.
class Opener:
	extends Node
	var stack: UiRoot = null
	var opened: bool = true

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT and stack != null:
			opened = stack.open(UiScreen.new())
