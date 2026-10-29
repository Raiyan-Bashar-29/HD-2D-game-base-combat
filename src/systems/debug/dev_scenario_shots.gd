extends Node
## Photographs the MOMENT a scripted scenario produces. The fifth debug file, and it exists
## because three consecutive packages closed with the same admission: a feature was proved by
## assertion and by reading the code, and never once photographed happening in a real session.
##
## WHY A FIFTH FILE RATHER THAN A FLAG ON dev_probes.gd
## Two reasons, and the second is the real one. `dev_probes.gd` is at 205 of its 250 code lines
## and `dev_stage.gd` at 248, so neither has room for a probe that both drives a scenario AND
## owns a shutter. But the seam was already there: `dev_probes.gd` answers "does sequence Y
## work" and prints a NUMBER, `dev_capture.gd` answers "what does the game look like under
## condition X" and shoots at a FRAME NUMBER, and neither can photograph a moment that exists
## for six tenths of a second and only after a scripted sequence has produced it. That is this
## file's question, and it is the same question `dev_gait_shots.gd` asks about a walk cycle -
## which is why the shutter here takes that file's shape rather than a new one.
##
## AUTOMATED USE - everything after the bare `--` is passed to the game:
##
##   --gate-shot=<dir>    throw the demo's north-gate lever, open the gate, and photograph the
##                        screen shake THE GATE asked for. `dev_capture.gd`'s `--shake=` emits
##                        the same signal a gate emits, so what it photographs is the rig; this
##                        photographs the WIRE, because nothing here touches a camera or a
##                        signal - it presses the interact key. Writes gate_closed.png (the
##                        control, camera at rest), gate_shake.png (the frame of greatest
##                        displacement) and gate_open.png (settled again, the leaf gone), and
##                        logs the camera's distance from rest in metres on every frame between.
##   --autosave-write     pose a state a fresh game is not in, then TRAVEL, so the autosave is
##                        written by `Events.area_entered` and not by this probe. Run it with
##                        `--new-game`. Reports what was posed and whether the file appeared.
##   --autosave-continue=<dir>
##                        the other half, in a FRESH PROCESS and with no `--new-game`: boot to
##                        the main menu, photograph the Continue row the autosave put there,
##                        press it through a focused Button and a real `ui_accept`, and
##                        photograph where the game came back. Compare the two reports line for
##                        line - that comparison is the measurement, and the pictures are what
##                        say it reached a screen.
##
## THE PAIR IS TWO PROCESSES FOR `--save-state`'s REASON, stated in dev_probes.gd and true here:
## an in-process reload cannot tell a value that was written to disk and read back from one that
## was simply never cleared. What this pair adds to that one is the OCCASION and the DOOR - the
## autosave is written by a real arrival and read by the real Continue row, neither of which
## `--save-state` touches.
##
## READ THE LOG AND THE PICTURE TOGETHER, gotcha 64's discipline: the metres in the log are the
## measurement of the shake and the image is the corroboration, never the other way round.
##
## OWNS: driving a scenario to the moment worth photographing, and opening the shutter on it.
## MUST NOT: be depended upon by gameplay, pose a camera offset or a save file by hand, or
## reimplement anything it photographs. Deleting this file must not break the game.

## Frames to let the boot transition settle. Same wait, same reason, as every probe in this
## project: gotcha 9.
const SETTLE_FRAMES: int = 30
## Frames to sample the camera for after the gate opens. `Gate.SHAKE_SECONDS` is 0.6, so at 60 Hz
## this covers the whole decay with room to spare - and the peak is FOUND rather than guessed,
## which is this file's answer to gotcha 52.
const SHAKE_FRAMES: int = 44
## Where the probe stands to reach something. The interaction reach is a 1.5 m sphere, so this is
## inside it and outside the object.
const REACH: Vector3 = Vector3(0.0, 0.0, 1.1)
## Frames to let an interaction be processed and the world answer it.
const ACT_FRAMES: int = 20
## How many times to press the cycle key looking for a named target. THE FIRST RUN OF THIS PROBE
## PRESSED INTERACT ON THE WRONG OBJECT: the sensor's reach is 2.4 m, the courtyard's lever has
## a barter action within that, and standing beside a thing does not select it. Six is more than
## any authored cluster in this template.
const CYCLE_TRIES: int = 6
## Per-frame camera movement below which the rig counts as parked, in metres. `follow_lag` is
## exponential, so it approaches its target and never arrives; this is small enough that the
## remainder is four orders of magnitude under the shake being measured.
const STILL_METRES: float = 0.00001
## Frames to give the rig to park before the control shot. THE SECOND DEFECT THE FIRST RUN FOUND:
## `rest` sampled twenty frames after teleporting the player is not rest at all, and the 0.4288 m
## the probe then reported as a shake was the smoothing tail of a gate that never opened.
const STILL_FRAMES: int = 240


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard, same reason, as its four
	# siblings, and check_boundary.gd fails without it - the exemption this directory has from
	# the demo-content boundary rests on exactly this line.
	if not OS.is_debug_build():
		return
	_parse_arguments()


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gate-shot="):
			_gate_shot(argument.trim_prefix("--gate-shot="))
		elif argument == "--autosave-write":
			_autosave_write()
		elif argument.begins_with("--autosave-continue="):
			_autosave_continue(argument.trim_prefix("--autosave-continue="))


## T5.9's gap, closed. That row photographed the shake by ASKING for it on the command line,
## which proves the rig; the gate's own emit was proved by reading four lines of `perform()`.
## This presses the interact key on a lever and then on a gate, and touches nothing else.
##
## THE CONTROL IS SHOT AFTER THE LEVER, which looks backwards and is not: it has to be the frame
## immediately before the shake, from the same camera at the same parked rest, and throwing the
## lever moves the player. The refusal reason is logged from the gate itself before the press,
## so "the flag was down, and then it was up" is in the transcript rather than assumed.
func _gate_shot(directory: String) -> void:
	var player: PlayerController = await _wait_for_player(directory)
	if player == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		Log.error("test", "--gate-shot found no camera")
		return
	await _press_on(player, "GateLever")
	var gate: Interactable = await _focus(player, "NorthGate")
	if gate == null:
		return
	await _camera_still(camera)
	var rest: Vector3 = camera.global_position
	await _shoot(directory, "gate_closed")
	Log.info("test", "--gate-shot camera parked at %s, gate refusal %d" % [
		str(rest), int(gate.refusal(player)),
	])
	_key(Actions.INTERACT, true)
	await get_tree().physics_frame
	_key(Actions.INTERACT, false)
	await _sample_shake(directory, camera, rest)


## Wait until the rig stops moving. Nothing here may be sampled against a camera still catching
## up with a teleported player - see STILL_FRAMES, which is the defect this closes.
func _camera_still(camera: Camera3D) -> void:
	var last: Vector3 = camera.global_position
	for frame: int in STILL_FRAMES:
		await get_tree().physics_frame
		var step: float = camera.global_position.distance_to(last)
		last = camera.global_position
		if step < STILL_METRES:
			Log.info("test", "  camera parked after %d frames" % frame)
			return
	Log.warn("test", "  camera never parked in %d frames" % STILL_FRAMES)


## The measurement. The player is standing still, so `_place()` puts the camera in the same spot
## every frame and any distance from `rest` is the shake and nothing else. The peak frame is kept
## as an IMAGE rather than as a frame number, so the number in the log and the picture on disk
## come from one frame by construction.
func _sample_shake(directory: String, camera: Camera3D, rest: Vector3) -> void:
	var best: float = 0.0
	var best_frame: int = -1
	var best_image: Image = null
	for frame: int in SHAKE_FRAMES:
		await RenderingServer.frame_post_draw
		var moved: float = camera.global_position.distance_to(rest)
		Log.info("test", "  frame %2d: camera %.6f m from rest" % [frame, moved])
		if moved > best:
			best = moved
			best_frame = frame
			best_image = get_viewport().get_texture().get_image()
	if best_image != null:
		best_image.save_png("%s/gate_shake.png" % directory)
	Log.info("test", "--gate-shot peak %.6f m on frame %d, camera now %.6f m from rest" % [
		best, best_frame, camera.global_position.distance_to(rest),
	])
	await _shoot(directory, "gate_open")


## Stand beside a named object and SELECT IT, by pressing the cycle key until the sensor is
## holding the thing this probe named.
##
## STANDING BESIDE A THING DOES NOT SELECT IT, and the first run of this probe is the proof: it
## teleported the player to the courtyard's gate lever, pressed interact, and the log says the
## sensor was holding a barter action on the garden-keeper two metres away. Nothing was red - a
## real object was really interacted with - and the lever was never thrown, so the gate that this
## probe exists to open refused with LOCKED and the picture was of a shut gate. Cycling is what a
## player does about the same problem, and `--cycle=` on dev_stage.gd exists for it.
func _focus(player: PlayerController, node_name: String) -> Interactable:
	var target: Node3D = get_tree().root.find_child(node_name, true, false) as Node3D
	if target == null:
		Log.error("test", "found no node called '%s'" % node_name)
		return null
	player.global_position = target.global_position + REACH
	for _i: int in ACT_FRAMES:
		await get_tree().physics_frame
	var sensor: InteractionSensor = player.get_node_or_null(
		^"InteractionSensor") as InteractionSensor
	for _try: int in CYCLE_TRIES:
		var current: Interactable = null if sensor == null else sensor.current()
		if current != null and current.name == node_name:
			Log.info("test", "  selected '%s' after %d cycles, refusal %d" % [
				node_name, _try, int(current.refusal(player)),
			])
			return current
		_key(Actions.INTERACT_CYCLE, true)
		await get_tree().physics_frame
		_key(Actions.INTERACT_CYCLE, false)
		await get_tree().physics_frame
	Log.error("test", "could not select '%s' in %d cycles" % [node_name, CYCLE_TRIES])
	return null


## Select a named object and press the interact key on it for real.
func _press_on(player: PlayerController, node_name: String) -> void:
	var target: Interactable = await _focus(player, node_name)
	if target == null:
		return
	_key(Actions.INTERACT, true)
	await get_tree().physics_frame
	_key(Actions.INTERACT, false)
	for _i: int in ACT_FRAMES:
		await get_tree().physics_frame


## T5.10's gap, first half. The autosave is written by `Events.area_entered` - this poses a state
## and then TRAVELS, and never calls `Autosave.request()`, because a probe that asked for the
## save itself would prove the writer and not the occasion.
func _autosave_write() -> void:
	var player: PlayerController = await _wait_for_player("")
	if player == null:
		return
	Inventory.of(player).add(&"item/rose_key", 1)
	Clock.set_time(4, 22, 15)
	# STORM, not CLEAR: the boot value IS clear, so a clear day read back proves nothing.
	Weather.force(GameEnums.WeatherKind.STORM)
	Log.info("test", "--autosave-write posed: %s" % _state_report())
	Events.area_change_requested.emit(&"lantern_hall", &"from_courtyard")
	await _settled()
	# Longer than the one frame `Autosave` waits for, so the write has certainly been attempted.
	for _i: int in ACT_FRAMES:
		await get_tree().process_frame
	Log.info("test", "--autosave-write file present: %s, latest slot %d" % [
		str(SaveSystem.has_slot(SaveSystem.AUTOSAVE_SLOT)), SaveSystem.latest_slot(),
	])
	Log.info("test", "--autosave-write before quit: %s" % _state_report())


## The other half, in a fresh process. No `--new-game`, so the boot report below is taken with
## nothing loaded at all - which is what makes the report after the press evidence about a FILE
## rather than about anything this session set up.
func _autosave_continue(directory: String) -> void:
	await _settled()
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(directory)
	Log.info("test", "--autosave-continue at boot: %s" % _state_report())
	Log.info("test", "--autosave-continue latest slot is %d, autosave slot is %d" % [
		SaveSystem.latest_slot(), SaveSystem.AUTOSAVE_SLOT,
	])
	await _shoot(directory, "autosave_menu")
	var pressed: bool = await _press_continue()
	if not pressed:
		return
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	Log.info("test", "--autosave-continue after: %s" % _state_report())
	await _shoot(directory, "autosave_continued")


## Press the main menu's own Continue row, through a focused `Button` and a real `ui_accept`.
## The row is found by the TEXT the screen builds it from and not by its index: `_fill` adds
## Continue only when a save exists, so an index would press Settings on a first-run menu and
## Load on the one run where this probe means anything.
##
## A `Button` ACTS ON RELEASE by default, so a press alone never fires one - the fact
## `dev_probes.gd`'s header records, and the reason both events are sent here.
##
## THE SCREEN IS TAKEN FROM `UiRoot.top()` AND NOT BY NODE NAME. `find_child("MainMenuScreen")`
## found nothing at all: a screen is `.new()`d, so its node name is the name of the ENGINE class
## it extends and never the script's `class_name`. The stack is the thing that knows which screen
## is open, and it is public because a screen's identity is not its node name.
func _press_continue() -> bool:
	var stack: UiRoot = UiRoot.find(self)
	var screen: MainMenuScreen = null if stack == null else stack.top() as MainMenuScreen
	if screen == null or screen.rows == null:
		Log.error("test", "--autosave-continue found no main menu")
		return false
	# The menu NAMES the autosave rather than numbering it, and this still built "Slot 7" after it
	# stopped, so the one run this probe exists for found no row. T6.10 found it.
	var wanted: String = tr(MainMenuScreen.CONTINUE_AUTOSAVE_KEY) \
		if SaveSystem.latest_slot() == SaveSystem.AUTOSAVE_SLOT \
		else tr(MainMenuScreen.CONTINUE_KEY).format({"slot": SaveSystem.latest_slot() + 1})
	for child: Node in screen.rows.get_children():
		var row: Button = child as Button
		if row == null or row.text != wanted:
			continue
		row.grab_focus()
		await get_tree().process_frame
		_key(&"ui_accept", true)
		await get_tree().process_frame
		_key(&"ui_accept", false)
		Log.info("test", "--autosave-continue pressed the '%s' row" % row.text)
		return true
	Log.error("test", "--autosave-continue found no Continue row on the main menu")
	return false


## Everything the two halves have to agree about. Deliberately the same shape `dev_probes.gd`'s
## own `_state_report` prints, so a reader comparing an autosave round trip against a
## `--save-state` one is comparing like with like.
func _state_report() -> String:
	var body: PlayerController = Director.player
	var place: String = "none" if body == null else "%.2f,%.2f" % [
		body.global_position.x, body.global_position.z,
	]
	var bag: Inventory = null if body == null else Inventory.of(body)
	return "area='%s' at=%s day=%d time=%02d:%02d weather=%d carrying=%d" % [
		Director.current_area_id, place, Clock.day, Clock.hour, Clock.minute,
		int(Weather.current()), 0 if bag == null else bag.total_count(),
	]


## The shutter. `frame_post_draw` first, gotcha 59: a picture and a number taken either side of a
## frame boundary are two honest measurements of two different moments.
func _shoot(directory: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	shot.save_png("%s/%s.png" % [directory, label])
	Log.info("test", "%s: %dx%d" % [label, shot.get_width(), shot.get_height()])


## The wait every probe in this file opens with, and the player it found. An empty directory
## means the caller wants no files, which is the write half of the autosave pair.
func _wait_for_player(directory: String) -> PlayerController:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var player: PlayerController = get_tree().root.find_child("Player", true, false)
	if player == null:
		Log.error("test", "found no Player")
		return null
	if directory != "":
		DirAccess.make_dir_recursive_absolute(directory)
	return player


## Wait for a transition to finish and for the freed area to actually leave the tree. The fourth
## copy of these five lines, and deliberately so: the note in dev_stage.gd applies here too.
func _settled() -> void:
	while Director.is_transitioning():
		await get_tree().process_frame
	for _i: int in 4:
		await get_tree().process_frame


## Real input, through `Input.parse_input_event`, because a probe that called a handler directly
## would photograph a mock.
func _key(action: StringName, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)
