extends Node
## Screenshot capture and lighting overrides. Lives in the game root.
##
## WHY THIS IS A REAL SYSTEM AND NOT A THROWAWAY SNIPPET
## The look of an HD-2D game is its whole point, and the look changes with the hour and the
## weather. Verifying it by launching the game and waiting twenty real minutes for dusk is
## not verification, it is hope. This node makes any lighting condition reachable in one
## command, and captures the result to a file that can be compared against last week's.
##
## MANUAL USE
##   F12   save a screenshot to user://screenshots/
##
## AUTOMATED USE — everything after the bare `--` is passed to the game:
##   godot_console --quit-after 40 -- --shot=user://shots/dusk.png --shot-frame=30 --time=19:10
##   godot_console --quit-after 40 -- --shot=user://shots/rain.png --weather=RAIN
##
##   --shot=<path>        where to write the capture. res:// and user:// both work.
##   --shot-frame=<int>   which frame to capture on. Default 30. Allow enough frames for
##                        the fade-in to finish and for volumetric fog to converge, or the
##                        image will be darker than the real thing.
##   --time=HH:MM         force the clock before capturing.
##   --locale=<code>      switch language before capturing. Goes through Settings, so it is
##                        the same path the options screen takes - and it PERSISTS, because
##                        a language choice does. Pass --locale=en to put it back.
##   --freeze-time        stop the clock, so a capture is reproducible to the pixel.
##   --skip-to-hour=<int> perform the same time skip a rest point does, after --time.
##   --weather=<KIND>     force weather. Any GameEnums.WeatherKind name.
##   --shake=<0..1>       fire one screen shake, through the same `Events.camera_shake_requested`
##                        a gate emits, once the area has settled. It runs for SHAKE_SECONDS,
##                        which is long enough that any sane --shot-frame lands MID-shake. Two
##                        runs of the same command differing only by `gameplay/camera_shake` in
##                        user://settings.cfg is how the feature was photographed - see T5.9.
##   --wet=<0..1>         set how soaked the ground is, skipping the eight-second soak. A
##                        capture lasts under a second, so without this every rain shot would
##                        photograph a courtyard that has only just started getting wet.
##   --dry-for=<seconds>  then run the wetness forward that many simulated seconds under the
##                        current weather. --wet=1 --weather=CLEAR --dry-for=20 photographs a
##                        specific moment of a dry-out that really takes twenty-six seconds.
##
## The scenario probes — --goto, --give, --talk, --round-trips, --npc-day and the rest — are
## documented in dev_probes.gd, which owns them.
##
## THE SCENARIO PROBES LIVE NEXT DOOR, in dev_probes.gd, and this file deliberately knows
## nothing about them. This one answers "what does the game LOOK like under condition X"; that
## one answers "does sequence Y actually work". They were one file until it hit 310 of its 250
## allowed code lines, which is the budget checker doing precisely its job: the split was
## already there in the reasoning and only the line count made it visible.
##
## OWNS: capture, and CLI-driven overrides for time, weather and one screen shake.
## MUST NOT: be depended upon by gameplay, or drive a scenario. Deleting this file must not
## break the game.

const SHOT_DIR: String = "user://screenshots"
const DEFAULT_SHOT_FRAME: int = 30
## How long --shake runs for. Deliberately far longer than `Gate.SHAKE_SECONDS`: a capture has
## to still be shaking when the shutter opens, and a probe that had to guess the frame a 0.6s
## jolt is halfway through would be gotcha 52 all over again.
const SHAKE_SECONDS: float = 8.0

var _shot_path: String = ""
var _shot_frame: int = DEFAULT_SHOT_FRAME
var _frames: int = 0
var _captured: bool = false
## Negative means "--wet was not passed", which is not the same as --wet=0.
var _wet_to: float = -1.0
var _dry_seconds: float = 0.0
## Negative means --shake was not passed.
var _shake: float = -1.0


func _ready() -> void:
	# Captures must work while the game is paused - proving that a screen stops the world is
	# exactly what the capture is for. Pause table: src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Until T1.2 only the F12 hotkey was
	# gated, so a release export still answered --give=, --standing= and --goto= from the
	# command line: every one of these flags reaches past the game to pose it, and a player who
	# found the list could hand themselves any item in the game.
	if not OS.is_debug_build():
		return
	_parse_arguments()


func _process(_delta: float) -> void:
	if _shot_path == "" or _captured:
		return
	_frames += 1
	if _frames >= _shot_frame:
		_captured = true
		_capture(_shot_path)


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(Actions.DEBUG_SCREENSHOT):
		var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "-")
		_capture("%s/shot_%s.png" % [SHOT_DIR, stamp])


## Reads the viewport's own texture, so what lands in the file is exactly what was on
## screen, post-processing and all.
func _capture(path: String) -> void:
	var view: Viewport = get_viewport()
	if view == null:
		Log.error("test", "Capture failed: no viewport")
		return
	var image: Image = view.get_texture().get_image()
	var directory: String = path.get_base_dir()
	if directory != "":
		var made: Error = DirAccess.make_dir_recursive_absolute(directory)
		if made != OK and made != ERR_ALREADY_EXISTS:
			Log.error("test", "Cannot create %s" % directory)
			return
	var err: Error = image.save_png(path)
	if err == OK:
		# THE CAMERA POSITION GOES IN THE LOG BESIDE THE PICTURE, on this project's standing
		# rule that a number and a photograph are read together. It is what makes two captures
		# comparable at all: the image says the world moved, this says by how much and that the
		# move was the camera.
		var eye: Camera3D = view.get_camera_3d()
		Log.info("test", "Captured %dx%d to %s, camera at %s" % [
			image.get_width(), image.get_height(), path,
			"none" if eye == null else str(eye.global_position),
		])
	else:
		Log.error("test", "Capture to %s failed: %s" % [path, error_string(err)])

func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot_path = argument.trim_prefix("--shot=")
		elif argument.begins_with("--shot-frame="):
			_shot_frame = maxi(1, argument.trim_prefix("--shot-frame=").to_int())
		elif argument.begins_with("--time="):
			_force_time(argument.trim_prefix("--time="))
		elif argument.begins_with("--locale="):
			_force_locale(argument.trim_prefix("--locale="))
		elif argument == "--freeze-time":
			Clock.paused = true
			Log.info("test", "Clock frozen by command line")
		elif argument.begins_with("--skip-to-hour="):
			_skip_to_hour(argument.trim_prefix("--skip-to-hour="))
		elif argument.begins_with("--weather="):
			_force_weather(argument.trim_prefix("--weather="))
		elif argument.begins_with("--wet="):
			_wet_to = clampf(argument.trim_prefix("--wet=").to_float(), 0.0, 1.0)
		elif argument.begins_with("--dry-for="):
			_dry_seconds = maxf(0.0, argument.trim_prefix("--dry-for=").to_float())
		elif argument.begins_with("--shake="):
			_shake = clampf(argument.trim_prefix("--shake=").to_float(), 0.0, 1.0)
	# Both wetness flags are served by ONE coroutine, deliberately. Two would each await the
	# area load and then race to resume, so --dry-for could run before --wet had soaked.
	if _wet_to >= 0.0 or _dry_seconds > 0.0:
		_soak_and_dry()
	if _shake >= 0.0:
		_start_shake()



## Through `DevCommands`, which is where the four verbs the in-game console offers actually
## happen. `--time=` and the console's `time` are now one implementation, so a fix to either is a
## fix to both — see src/systems/debug/dev_commands.gd for why that mattered enough to move.
func _force_time(value: String) -> void:
	Log.info("test", "--time %s" % DevCommands.set_time(value))


func _force_weather(value: String) -> void:
	var names: Array = GameEnums.WeatherKind.keys()
	var index: int = names.find(value.to_upper())
	if index < 0:
		Log.warn("test", "Unknown weather '%s'. Valid: %s" % [value, ", ".join(names)])
		return
	Weather.force(index as GameEnums.WeatherKind)
	Log.info("test", "Weather forced to %s by command line" % value.to_upper())


## Pose the wetness for a capture. Goes through WeatherVisuals rather than writing a material,
## so what is photographed is the real path: the same soak() a save-load will call and the same
## evaporate() the dry-out runs on, not a screenshot posed by hand.
func _soak_and_dry() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	var found: Node = get_tree().root.find_child("WeatherVisuals", true, false)
	var visuals: WeatherVisuals = found as WeatherVisuals
	if visuals == null:
		Log.error("test", "--wet/--dry-for found no WeatherVisuals in the tree")
		return
	if _wet_to >= 0.0:
		visuals.soak(_wet_to)
	if _dry_seconds > 0.0:
		visuals.evaporate(_dry_seconds)
	Log.info("test", "--wet %.2f --dry-for %.1fs left wetness at %.3f" % [
		_wet_to, _dry_seconds, visuals.wetness(),
	])


## The same time skip a rest point performs, reachable from the command line, so a before and
## after capture can prove that skip_to_hour really drives the lighting rather than only
## moving a number. Deliberately Clock.skip_to_hour and not a second implementation: a debug
## path that reimplements the thing it verifies verifies nothing.
func _skip_to_hour(value: String) -> void:
	var skipped: int = Clock.skip_to_hour(value.to_int())
	Log.info("test", "Skipped %d minutes to %02d:00 by command line" % [skipped, Clock.hour])


## Fills the player's bag from the command line, so a capture of the inventory shows real rows
## produced by the real Inventory.add() rather than a mock the screen was posed against.
## Deferred: GameRoot spawns the player in the same _ready() pass that reads these arguments.


## Wait for a transition to finish and for the freed area to actually leave the tree.
## The third copy of these five lines, and deliberately so — the note in dev_stage.gd applies
## here too. This one was MISSING until T1.2: the WP-13 merge added the `await _settled()` in
## `_soak_and_dry` without the function, so this entire file failed to parse and F12, --shot,
## --time and --weather had all been dead since. The boot rung still printed
## `0 warnings, 0 errors`, because Log counts Log.error calls and an engine parse error is
## neither. See the gotcha in docs/CONTEXT.md.
func _settled() -> void:
	while Director.is_transitioning():
		await get_tree().process_frame
	for _i: int in 4:
		await get_tree().process_frame


## Switch language for a capture. Deliberately through `Settings.set_value` rather than straight
## to `TranslationServer`: the criterion is that switching the SETTING changes what is on screen,
## and a flag that set the translation server itself would photograph a path no player can take.
func _force_locale(code: String) -> void:
	if code == "":
		return
	Settings.set_value(Settings.LOCALE, code)
	Log.info("capture", "Locale forced to %s" % TranslationServer.get_locale())


## Fire one shake through the REAL path, which is the whole point of the flag: it emits the
## signal a `Gate` emits and touches no camera itself, so what a capture photographs is the
## feature and not a posed offset. If the area's scene has no rig, nothing listens and the
## picture is honestly unchanged.
func _start_shake() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	Events.camera_shake_requested.emit(_shake, SHAKE_SECONDS)
	Log.info("test", "--shake %.2f for %.1fs" % [_shake, SHAKE_SECONDS])
