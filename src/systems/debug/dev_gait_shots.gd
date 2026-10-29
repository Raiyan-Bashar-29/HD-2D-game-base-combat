extends Node
## Photographs a character in every gait its sheet declares, and - since T5.8 - in every
## DIRECTION it can walk. The fourth debug file, and it exists because Phase T5.s last exit
## criterion is a PICTURE.
##
## WHY A FOURTH FILE RATHER THAN A FLAG ON dev_stage.gd
## The other three each answer one question - `dev_capture.gd` "what does this LOOK like",
## `dev_probes.gd` "does this sequence work", `dev_stage.gd` "put the world in that state" -
## and a gait capture needs all three at once, per gait, five times in one run. It also owns a
## fact none of them has: WHEN to open the shutter. A gait has no still moment to aim a frame
## number at (gotcha 52), so this waits until the character is actually in the gait and shoots
## then, rather than guessing a frame and hoping the area had loaded.
##
## AUTOMATED USE - everything after the bare `--` is passed to the game:
##   godot_console --resolution 960x540 --quit-after 600 -- --new-game --freeze-time \
##       --gait-shots=<dir>
##
##   --gait-shots=<dir>     drive the player through idle, walk, run, sneak and climb through
##                          the real input path, and for each one write <dir>/gait_<name>.png,
##                          a x5 nearest-neighbour crop beside it, and a log line decoding the
##                          block, column and cell out of sprite.frame.
##   --turn-shots=<dir>     photograph the player before and after a turn asked for on the bus,
##                          and report the fraction of pixels that differ between the two crops.
##   --facing-shots=<dir>   walk the player north, east, south and west and photograph each,
##                          same shutter and same decode, into <dir>/facing_<name>.png.
##   --idle-shots=<dir>     leave the player standing perfectly still and WATCH, sampling the
##                          decoded block every few frames for eight seconds; photograph the
##                          an early and a late cell of each distinct block into
##                          <dir>/idle_block_<n>_<early|late>.png, and log the whole sequence
##                          of blocks seen.
##
## WHY THE IDLE PASS IS HERE TOO, and it is the same answer a third time: a second idle is a
## shutter problem with the axis substituted again. What differs is that it presses NOTHING -
## the whole input for this pass is standing still long enough - so it needs no `_hold` and no
## `_press`, and it cannot aim a frame number at the moment of interest because that moment is
## decided by a threshold on the SHEET, which this file must not know (gotcha 52's shape once
## more). So it watches instead of aiming: sample the block repeatedly, photograph each block
## the first time it is seen, and report the whole sequence. The sequence is the claim - a
## single "the break block was drawn" shot cannot show that it STARTED and ENDED, and those two
## are exactly what a chooser has to get right.
##
## WHY THE FACING PASS IS HERE AND NOT IN A FIFTH FILE. It is the same shutter problem with the
## other axis substituted: hold a real key, wait for the character to be actually doing it, then
## read the number and the picture in the same frame. Everything a facing capture needs -
## SETTLE_FRAMES, HOLD_FRAMES, the post-draw await of gotcha 59, the logical-size crop of
## gotcha 60 - is already here and would have been copied verbatim. What the split would have
## bought is a more accurate FILE NAME, which is not worth four duplicated gotchas.
##
## T5.6 RECORDED THE ABSENCE AS ITS OWN GAP: every capture this project had ever taken was of
## column 0 or column 1, so the facing system had never been photographed at all - and when it
## finally was, the sheet turned out to draw one pose eight times (T5.8).
##
## READ THE LOG AND THE PICTURE TOGETHER, because neither is sufficient. A sprite drawn from the
## wrong cell is still a person (gotcha 28), so the photograph alone proves nothing about WHICH
## cell; and --headless shades nothing (gotcha 2), so the decoded number alone proves nothing
## about whether it reached a screen. The alt placeholder sheet carries three pip tallies for
## exactly this reason: the number in the log and the pips in the image have to agree.
##
## OWNS: driving a character through its gaits and its facings, and capturing each.
## MUST NOT: be depended upon by gameplay, pose a velocity or a sprite frame by hand, or know
## anything about a particular sheet. It presses the keys a player presses and reads what the
## game drew. Deleting this file must not break the game.

const GAITS: Array[GameEnums.MoveState] = [
	GameEnums.MoveState.IDLE, GameEnums.MoveState.WALK, GameEnums.MoveState.RUN,
	GameEnums.MoveState.SNEAK, GameEnums.MoveState.CLIMB,
]
## Physics frames to hold a gait before shooting. Long enough for acceleration to reach the
## gait's real speed and for the cycle to leave cell 0, short enough that the player is still
## in shot - at run speed they clear the courtyard in about a second.
const HOLD_FRAMES: int = 22
## How far up an authored climb this probe lifts the player. A ladder, not a flight.
const CLIMB_HEIGHT: float = 2.2
## Frames to let the boot transition settle before the first gait. Same wait every probe in
## this project opens with, and for the same reason: gotcha 9.
const SETTLE_FRAMES: int = 30
## The four directions the facing pass walks, named by the SCREEN. Which sheet column each one
## reaches depends on the camera's yaw and is deliberately not assumed here - it is read out of
## `sprite.frame` and logged, so the picture and the number can be checked against each other.
const COMPASS: Array[StringName] = [&"north", &"east", &"south", &"west"]
## HOW LONG THE IDLE PASS WATCHES, and how often it looks. The shipped placeholder layout
## breaks after 3s into a 4-cell block at 3fps, so eight seconds spans a full dwell, the break,
## the return, and the start of the next dwell - with room for a game that retunes the number
## upward a little. Sampling every 10 physics frames is six times per second, which cannot miss
## a block that is on screen for a second and a third.
const IDLE_FRAMES: int = 480
const IDLE_SAMPLE: int = 10
## Where the turn probe asks the player to look, relative to where the player is standing. Far
## enough that the direction is unambiguous, and diagonal so it cannot coincide with the facing
## a single held key produced.
const TURN_TOWARDS: Vector3 = Vector3(-6.0, 0.0, -6.0)

var _dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gait-shots="):
			_dir = argument.trim_prefix("--gait-shots=")
			_run()
		elif argument.begins_with("--turn-shots="):
			_dir = argument.trim_prefix("--turn-shots=")
			_run_turns()
		elif argument.begins_with("--facing-shots="):
			_dir = argument.trim_prefix("--facing-shots=")
			_run_facings()
		elif argument.begins_with("--idle-shots="):
			_dir = argument.trim_prefix("--idle-shots=")
			_run_idle()


func _run() -> void:
	var player: PlayerController = await _wait_for_player()
	if player == null:
		return
	var home: Vector3 = player.global_position
	for gait: GameEnums.MoveState in GAITS:
		await _one(player, gait, home)
	Log.info("test", "--gait-shots done")


## THE SAME CHARACTER WALKING NORTH, EAST, SOUTH AND WEST, which nothing in this repository had
## ever photographed before T5.8 - every capture ever taken was of column 0 or column 1. The
## directions are pressed as KEYS and named by the screen, because that is what an owner watching
## the game sees; which sheet COLUMN each one reaches is the decoded number in the log, and the
## two together are the claim.
func _run_facings() -> void:
	var player: PlayerController = await _wait_for_player()
	if player == null:
		return
	var home: Vector3 = player.global_position
	for compass: StringName in COMPASS:
		player.global_position = home
		var action: StringName = _compass_action(compass)
		_hold(action, true)
		for _i: int in HOLD_FRAMES:
			await get_tree().physics_frame
		await _shoot(player, "facing_%s" % compass)
		_hold(action, false)
	Log.info("test", "--facing-shots done")


## THE ONE PASS THAT PRESSES NOTHING. A second idle is the only thing this file photographs
## that a player triggers by NOT acting, so the probe's whole job is to stand still and watch.
##
## IT ASSUMES NOTHING ABOUT WHICH BLOCK IS THE BREAK. The row and the threshold are read off the
## layout and LOGGED rather than compared against a constant here, because a game swaps that
## resource and this file must survive the swap - the same reason `_run_facings` logs the column
## it reached instead of predicting it. What the pass asserts by construction is only that the
## sequence of blocks a standing character draws has more than one value in it.
func _run_idle() -> void:
	var player: PlayerController = await _wait_for_player()
	if player == null:
		return
	var layout: SpriteSheetLayout = player.visual.layout
	var blocks: PackedStringArray = PackedStringArray()
	# The crops are KEPT, not only saved, so the run can end with the three numbers that say
	# whether the pictures differ by more than a tint. Keyed by the same label as the file.
	var shot: Dictionary[String, Variant] = {}
	@warning_ignore("integer_division")
	var samples: int = IDLE_FRAMES / IDLE_SAMPLE
	for _sample: int in samples:
		for _i: int in IDLE_SAMPLE:
			await get_tree().physics_frame
		var block: int = _block_of(player)
		blocks.append(str(block))
		# EARLY AND LATE CELL OF EACH BLOCK, NOT JUST THE FIRST SIGHTING. The first draft keyed
		# these shots on the block alone and both came back at cellframe 0 - so the pair proved
		# the block (its cloth tint differs, gotcha 28's answer) and proved nothing whatever
		# about the cycle inside it, while the placeholder sheet's break puts its whole
		# silhouette change on the LATE cells. Two shots per block is the difference between
		# photographing a second idle and photographing a recolour.
		var label: String = "idle_block_%d_%s" % [
			block, "late" if _cell_of(player) >= 2 else "early",
		]
		if not shot.has(label):
			shot[label] = await _shoot(player, label)
	Log.info("test", "idle: the sheet names break row %d after %.1fs; blocks seen were %s" % [
		layout.idle_break_row, layout.idle_break_after, ", ".join(blocks),
	])
	_report_spread(shot)
	Log.info("test", "--idle-shots done")


## HOW FAR APART THE FOUR CROPS ACTUALLY ARE, as fractions of the crop that differ - because
## "the second idle looks different" is a judgement and this project's standard is a number
## (gotcha 28, and T5.8's measure applied to the screen). Three numbers, and the third is the
## one that matters: the two BLOCKS have to differ by more than either block's own cycle does,
## or what was photographed is a recolour with a wobble rather than a second idle.
##
## A MISSING CROP IS REPORTED AND NOT ASSUMED. A run whose shutter never caught a late cell of
## some block has no third number to give, and saying so beats printing a 1.0 that means
## "absent" while reading like "completely different".
func _report_spread(shot: Dictionary[String, Variant]) -> void:
	for pair: Array in [
		["idle_block_0_early", "idle_block_0_late"],
		["idle_block_3_early", "idle_block_3_late"],
		["idle_block_0_early", "idle_block_3_early"],
	]:
		var a: Variant = shot.get(pair[0])
		var b: Variant = shot.get(pair[1])
		if a is not Image or b is not Image:
			Log.info("test", "idle: %s vs %s - one of the two was never caught" % pair)
			continue
		Log.info("test", "idle: %s vs %s differ by %.4f of the crop" % [
			pair[0], pair[1], _difference(a as Image, b as Image),
		])


## The animation block a character is drawing, decoded out of the one number Sprite3D exposes.
## The same arithmetic `_shoot` logs, needed separately because the idle pass reads the block
## on every sample and photographs only some of them.
func _block_of(player: PlayerController) -> int:
	var layout: SpriteSheetLayout = player.visual.layout
	@warning_ignore("integer_division")
	var row: int = player.visual.sprite.frame / layout.facings
	@warning_ignore("integer_division")
	var block: int = row / layout.frames
	return block


## The cell WITHIN that block, which is what decides whether a shot is worth taking twice.
func _cell_of(player: PlayerController) -> int:
	var layout: SpriteSheetLayout = player.visual.layout
	@warning_ignore("integer_division")
	var row: int = player.visual.sprite.frame / layout.facings
	return row % layout.frames


## THE SAME CHARACTER PHOTOGRAPHED BEFORE AND AFTER A TURN IN PLACE, which is the only evidence
## T5.14 could offer: a turn is a VISUAL claim and --headless shades nothing (gotcha 2), while
## `sprite.frame` alone proves only that a number changed (gotcha 28). So this reports BOTH -
## the decoded column either side, and the fraction of pixels that actually differ between the
## two crops. T5.8's standard, with the axis substituted.
##
## IT ASKS ON THE BUS RATHER THAN WALKING UP TO SOMETHING. What needs photographing is the
## LISTENER end - that a request becomes a different figure on a screen - and the two askers'
## occasions are the suite's business, where they are staged exactly and cheaply. A probe that
## walked the player at an authored object would be photographing the courtyard's furniture
## placement as much as the turn.
func _run_turns() -> void:
	var player: PlayerController = await _wait_for_player()
	if player == null:
		return
	# Face one way through the real input path first, so the turn is FROM somewhere known
	# rather than from whatever the boot transition left behind.
	_hold(Actions.MOVE_RIGHT, true)
	for _i: int in HOLD_FRAMES:
		await get_tree().physics_frame
	_hold(Actions.MOVE_RIGHT, false)
	for _i: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var before: Image = await _shoot(player, "turn_before")
	# THE CONTROL, and without it the headline number is worthless: this sheet's idle block
	# animates, so two shots one shutter apart already differ by a whole cell. Shoot the same
	# gap again with NO turn asked for, and the turn's number is the one above that floor.
	var control: Image = await _shoot(player, "turn_control")
	Events.turn_requested.emit(player, player.global_position + TURN_TOWARDS)
	var after: Image = await _shoot(player, "turn_after")
	Log.info("test", "turn: the idle cycle alone moves %.4f of the crop, the turn moves %.4f" % [
		_difference(before, control), _difference(control, after),
	])
	Log.info("test", "--turn-shots done")


## How far apart two crops of the same character are, as the fraction of pixels that differ at
## all. The same measure `sheet_facings_test.gd` uses on cells of a sheet, applied to the screen
## instead - so a number here is comparable with the numbers T5.8 recorded.
func _difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var differ: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				differ += 1
	return float(differ) / float(a.get_width() * a.get_height())


## The wait every probe in this file opens with, and the player it found. Null means the run has
## already logged why, so a caller only has to stop.
func _wait_for_player() -> PlayerController:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var player: PlayerController = get_tree().root.find_child("Player", true, false)
	if player == null:
		Log.error("test", "%s found no Player" % _dir)
		return null
	DirAccess.make_dir_recursive_absolute(_dir)
	return player


func _one(player: PlayerController, gait: GameEnums.MoveState, home: Vector3) -> void:
	player.global_position = home
	_press(gait, true)
	if gait == GameEnums.MoveState.CLIMB:
		player.begin_climb(home + Vector3(0.0, CLIMB_HEIGHT, 0.0))
	for _i: int in HOLD_FRAMES:
		await get_tree().physics_frame
	await _shoot(player, "gait_%s" % str(GameEnums.MoveState.keys()[gait]).to_lower())
	_press(gait, false)


## The shutter, and the one thing this file owns that no other debug file does.
##
## THE NUMBER AND THE PICTURE MUST COME FROM THE SAME FRAME. Reading sprite.frame BEFORE the
## post-draw await put a physics step between them, so the log said cellframe 2 while the
## photograph showed one foot pip - two honest measurements of two different moments, which
## reads exactly like the sheet being wrong.
func _shoot(player: PlayerController, label: String) -> Image:
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var layout: SpriteSheetLayout = player.visual.layout
	var cell: int = player.visual.sprite.frame
	Log.info("test", "%s: %s block=%d column=%d cellframe=%d" % [
		label, player.visual.describe(), (cell / layout.facings) / layout.frames,
		cell % layout.facings, (cell / layout.facings) % layout.frames,
	])
	shot.save_png("%s/%s.png" % [_dir, label])
	var crop: Image = _zoom(shot, player)
	crop.save_png("%s/%s_zoom.png" % [_dir, label])
	return crop


## Screen north, east, south and west as the action a player holds. A function rather than a
## const table because `Actions` is an autoload, and an autoload identifier does not resolve in
## a const initialiser.
func _compass_action(compass: StringName) -> StringName:
	match compass:
		&"north":
			return Actions.MOVE_UP
		&"east":
			return Actions.MOVE_RIGHT
		&"south":
			return Actions.MOVE_DOWN
	return Actions.MOVE_LEFT


func _hold(action: StringName, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)


## The pips are two screen pixels wide at this framing, so the full capture proves the swap and
## this proves the CELL. Nearest-neighbour, because a smoothed pip cannot be counted.
##
## `unproject_position` ANSWERS IN THE VIEWPORT'S LOGICAL SIZE, NOT IN WINDOW PIXELS. The
## project scales content from 1920x1080, so at a --resolution of 960x540 every unprojected
## point came back at exactly twice its place in the captured image and the first five crops
## were photographs of grass. Scale by the ratio the shot itself reports rather than by a
## number, or the crop is right at one resolution and silently wrong at every other.
func _zoom(shot: Image, player: PlayerController) -> Image:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var logical: Vector2 = camera.get_viewport().get_visible_rect().size
	var scale: Vector2 = Vector2(shot.get_size()) / logical
	var at: Vector2i = Vector2i(camera.unproject_position(
		player.global_position + Vector3(0.0, 0.75, 0.0)) * scale)
	var box: Rect2i = Rect2i(at - Vector2i(45, 55), Vector2i(90, 110))
	var crop: Image = shot.get_region(box.intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
	crop.resize(crop.get_width() * 5, crop.get_height() * 5, Image.INTERPOLATE_NEAREST)
	return crop


## Real input, through Input.parse_input_event, because a probe that posed the velocity by hand
## would photograph a mock. A climb is the exception and goes through begin_climb(), which is
## the same public call ClimbPoint makes.
func _press(gait: GameEnums.MoveState, down: bool) -> void:
	var held: Array[StringName] = []
	match gait:
		GameEnums.MoveState.WALK:
			held = [Actions.MOVE_RIGHT]
		GameEnums.MoveState.RUN:
			held = [Actions.MOVE_RIGHT, Actions.RUN]
		GameEnums.MoveState.SNEAK:
			held = [Actions.MOVE_RIGHT, Actions.SNEAK]
	for action: StringName in held:
		_hold(action, down)
