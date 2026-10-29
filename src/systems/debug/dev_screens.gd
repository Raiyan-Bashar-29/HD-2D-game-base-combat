extends Node
## Staging that puts a SCREEN over an already-posed world. The sixth debug file.
##
## WHY A SIXTH FILE RATHER THAN A FLAG ON dev_stage.gd
## `dev_stage.gd` had two lines of budget left, so something had to move — but the line it moved
## along was already in the reasoning, exactly as it was the twice before. The other five files
## each answer one question: `dev_capture.gd` "what does this LOOK like", `dev_probes.gd` "does
## this sequence work", `dev_gait_shots.gd` and `dev_scenario_shots.gd` "WHEN does the shutter
## open", and `dev_stage.gd` "what is TRUE in the world" — where the player stands, what is in
## the bag, what is in hand, what a flag says, who thinks what of them. This file asks the one
## question left over: "and what is DRAWN OVER it". That is why every flag here ends in a
## `UiRoot.open()` and none of the flags left next door does.
##
## THE SEAM IS ALSO A DEPENDENCY FACT, which is what makes it a seam rather than a filing
## preference. These five flags are the only staging that touches the `ui` layer at all —
## `UiRoot`, `ScreenKeys`, `InventoryScreen`, `DialogueScreen`, `DebugConsoleScreen`. What stays
## in `dev_stage.gd` reaches `Director`, `Flags`, `Standing`, `Equipment` and the interaction
## sensor and never once names a screen. The split puts the upward references in one file.
##
## EVERY FLAG HERE GOES THROUGH THE REAL PATH, and the note in `dev_stage.gd` applies unchanged:
## a conversation opens through the same bus signal a `Speaker` emits, a console line goes
## through the same `submit()` the enter key calls, a menu is pushed onto the real stack. A
## staging tool that reached past the game to pose it would photograph a mock.
##
## EVERYTHING AFTER THE BARE `--` IS PASSED TO THE GAME:
##
##   --open-inventory     push the inventory screen over a stopped world. Apply --give first,
##                        or the capture shows an empty bag.
##   --talk=<id>          open a conversation: --talk=talk/gardener
##   --talk-advance=<n>   press through n lines, to capture a branch rather than the opening.
##   --open-menu=<list>   push menus by name, innermost last: main_menu, pause, settings,
##                        saves, controls, journal, map. `--open-menu=pause,settings` puts
##                        settings over the pause menu, and `--goto=X --open-menu=map` shows the
##                        map from X.
##   --console=<lines>    open the debug console and run lines through it, separated by ';':
##                        --console="time 18:40;flag met/someone:true". The lines go through
##                        DebugConsoleScreen.submit(), which is the same path the enter key
##                        takes, so a capture shows a real transcript. Waits for the world to
##                        stay still - gotcha 35, this puts something on screen.
##
## GOTCHA 35 APPLIES TO EVERY FLAG IN THIS FILE BY CONSTRUCTION, which is the split's one real
## dividend. The rule was "any staging flag that puts something on SCREEN waits for a SETTLED
## area, not merely for an area" — and it was stated in a header shared with eleven flags that
## do not draw, which is how `--stand-by` went four packages without following it (T4.2). Here
## the rule is the file's whole subject, so a seventh screen flag added below inherits it by
## being in the right place rather than by somebody remembering.
##
## ORDER RELATIVE TO dev_stage.gd IS THE NODE ORDER IN `game_root.tscn`, and `DevScreens` sits
## immediately AFTER `DevStage` there deliberately: these flags draw over what that file poses,
## so they must never resume a frame earlier than they did when the two were one file.
##
## OWNS: pushing a screen over a posed world for a capture, and pressing through a conversation.
## MUST NOT: be depended upon by gameplay, measure anything, pose world state that is not a
## screen, or reach past the game to pose it. Deleting this file must not break the game.

## How long the world must stay settled before a flag here acts. Same value and same reasoning as
## `dev_stage.gd`'s: generous on purpose, because it costs a capture a fraction of a second and
## removes a race that costs an hour to diagnose.
const SETTLE_FRAMES: int = 20

var _talk_advance: int = 0
## Set from the command line, read by every flag here: a screen pushed before the transition
## lands is closed again by it, because ScreenKeys unwinds the stack on every travel.
##
## READ IN A PRE-PASS RATHER THAN IN THE DISPATCH LOOP, and it matters that this is equivalent
## rather than merely tidier. In `dev_stage.gd` the same field is set by the `--new-game` branch
## as the loop reaches it, so a flag typed BEFORE `--new-game` would read it unset — except that
## every reader awaits at least one frame first, by which point the loop has finished. Asking the
## argument list directly makes that independence explicit instead of load-bearing.
var _fresh_game: bool = false


func _ready() -> void:
	# Staging has to work with a screen open: half of what is worth photographing is a screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard, same reason, as
	# dev_stage.gd and dev_capture.gd: until T1.2 a release export still answered these flags.
	if not OS.is_debug_build():
		return
	_parse_arguments()


func _parse_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_fresh_game = arguments.has("--new-game")
	for argument: String in arguments:
		if argument == "--open-inventory":
			_open_inventory()
		elif argument.begins_with("--talk-advance="):
			_talk_advance = maxi(0, argument.trim_prefix("--talk-advance=").to_int())
		elif argument.begins_with("--talk="):
			_talk(StringName(argument.trim_prefix("--talk=")))
		elif argument.begins_with("--open-menu="):
			_open_menu(argument.trim_prefix("--open-menu="))
		elif argument.begins_with("--console="):
			_console(argument.trim_prefix("--console="))


## Wait for a transition to finish and for the freed area to actually leave the tree.
## The fifth copy of these five lines, and deliberately so — the note in dev_stage.gd applies
## here too: five lines repeated once is a better trade than a shared base class binding two
## independent debug nodes together.
func _settled() -> void:
	while Director.is_transitioning():
		await get_tree().process_frame
	for _i: int in 4:
		await get_tree().process_frame


func _wait_for_area() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()


## Wait until the world has been settled for `frames` CONSECUTIVE frames, and start counting
## again the moment it is not. Gotcha 21's persistence shape, applied to staging.
##
## WHY A COUNTER AND NOT A LONGER WAIT. `--goto` and `--open-menu` both begin by waiting for the
## first area, so they come out of that wait on the same frame and race: if the menu opens first,
## the travel `--goto` is about to request unwinds it, and the capture is of an empty screen with
## every rung green. A fixed number of extra frames only moves the race. This one cannot be won
## early, because a transition starting resets the count.
func _settle_stable(frames: int) -> void:
	var stable: int = 0
	while stable < frames:
		if Director.current_area_id == &"" or Director.is_transitioning():
			stable = 0
		else:
			stable += 1
		await get_tree().process_frame


## Pushes the inventory screen so a windowed capture can show a real screen over a real, stopped
## world. Deferred by two frames: UiRoot is a sibling built in the same _ready() pass as this
## node, and --give needs its own frame before this one reads the bag.
##
## AND THEN FOR THE AREA, when --new-game is on the same line. Without that it drew over the
## title screen and the arriving transition unwound it — the same shape as gotcha 32, and the
## third flag to need this wait after --open-menu and --flag. Any new flag that puts something on
## screen needs it too.
func _open_inventory() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
	var stack: UiRoot = UiRoot.find(self)
	if stack == null:
		Log.error("test", "--open-inventory found no UiRoot in the tree")
		return
	var opened: bool = stack.open(InventoryScreen.for_carrier(Director.player))
	Log.info("test", "--open-inventory pushed the inventory screen: %s" % str(opened))


## Open a conversation for a capture. Goes through the SAME bus signal a Speaker emits, so what
## is photographed is the real path and not a screen posed by hand.
func _talk(talk_id: StringName) -> void:
	await _wait_for_area()
	Events.dialogue_requested.emit(talk_id)
	await get_tree().process_frame
	var stack: UiRoot = UiRoot.find(self)
	var screen: DialogueScreen = stack.top() as DialogueScreen
	if screen == null:
		Log.error("test", "--talk opened no dialogue screen for '%s'" % talk_id)
		return
	Log.info("test", "--talk opened '%s' at node '%s'" % [
		talk_id, screen.runner.current_node().node_id,
	])
	for _i: int in _talk_advance:
		await _reveal_done(screen)
		screen.runner.advance()
		await get_tree().process_frame
	await _reveal_done(screen)
	Log.info("test", "--talk resting on node '%s', %d choices" % [
		screen.runner.current_node().node_id, screen.runner.available_choices().size(),
	])


## Let the typewriter finish. A capture taken mid-reveal photographs half a sentence, which
## looks like a truncation bug rather than the feature it is.
func _reveal_done(screen: DialogueScreen) -> void:
	for _i: int in 240:
		if screen.reveal_complete():
			return
		await get_tree().process_frame


## Open the debug console and run lines through it, so a capture shows a real transcript rather
## than an empty box. Goes through `submit()`, which is precisely what the enter key calls — the
## key itself cannot be pressed by anything but a probe (gotcha 15), and the WP-14b probe that
## did press it is quoted in DEVLOG.md.
##
## `_settle_stable`, not `_wait_for_area`, and gotcha 35 is why: this puts something on screen,
## and any staging flag that does leaves `_wait_for_area` on the same frame as `--goto` and races
## it. Sixth flag to need this after --open-menu, --flag, --open-inventory, --give and --equip.
func _console(script: String) -> void:
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
		await _settle_stable(SETTLE_FRAMES)
	var stack: UiRoot = UiRoot.find(self)
	var screen: DebugConsoleScreen = ScreenKeys.menu_for(
		DebugConsoleScreen.SCREEN_ID) as DebugConsoleScreen
	if stack == null or screen == null or not stack.open(screen):
		Log.error("test", "--console found no stack, or no console to open")
		return
	for line: String in script.split(";", false):
		Log.info("test", "--console '%s' -> %s" % [line, screen.submit(line)])


## Push menus by name for a capture, innermost last.
##
## Waits for the transition when --new-game is on the same line, because `ScreenKeys` unwinds
## the stack on every travel — a menu pushed before the area lands is closed again by it.
##
## AND THEN FOR THE WORLD TO STAY STILL, which is what makes `--goto=X --open-menu=map` a usable
## pair: `_wait_for_area` alone returns on the same frame `--goto` asks to travel, and the travel
## unwinds the menu that was pushed a moment earlier. See `_settle_stable`.
func _open_menu(list: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _fresh_game:
		await _wait_for_area()
		await _settle_stable(SETTLE_FRAMES)
	var stack: UiRoot = UiRoot.find(self)
	for menu_id: String in list.split(",", false):
		var screen: UiScreen = ScreenKeys.menu_for(StringName(menu_id))
		if stack == null or screen == null:
			Log.error("test", "--open-menu=%s found no stack or no such menu" % menu_id)
			return
		Log.info("test", "--open-menu %s pushed: %s" % [menu_id, str(stack.open(screen))])
