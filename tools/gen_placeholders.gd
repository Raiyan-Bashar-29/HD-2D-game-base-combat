extends SceneTree
## Generates placeholder art procedurally, so the whole game can be built and looked at
## before a single real asset exists.
##
## WHY THIS IS A REAL TOOL AND NOT A HACK
## Art is deliberately deferred on this project. Without stand-ins, every visual system
## (billboarding, sprite lighting, facing, the camera rig, depth of field) would have to be
## written blind and verified later, which is how a rendering bug survives to month three.
## These files are ugly on purpose so nobody mistakes them for finished work.
##
## AND A PLACEHOLDER THAT CANNOT SHOW A SYSTEM WORKING IS NOT DOING ITS JOB, which is what T5.8
## found. Both sheets drew ONE POSE PER GAIT and repeated it across every facing, so the facing
## system - quantised correctly, asserted at both ends, driven through the real input path - was
## invisible on screen from Phase 1 until an owner played the game and said that sideways
## movement "just slides to the side". Improving this tool is not a retraction of "art is
## deferred": the deferred thing is ART, and this is the instrument the systems are read with.
##
## RUN:  godot_console --headless --script tools/gen_placeholders.gd
## OUT:  assets/placeholder/*.png  (committed, small, regenerable at any time)
##
## Note: this script cannot use the autoloads. A --script run does not create them, so it
## uses print() directly rather than Log. That is the one place in the project where that
## is allowed.

const OUT_DIR: String = "res://assets/placeholder"

# One character cell. 32x48 at a pixel_size of 0.01 gives a figure about 0.48m wide and
# 1.7m tall, which is roughly human against the 1m world grid.
const CELL: Vector2i = Vector2i(32, 48)
const DIRECTIONS: int = 8
const FRAMES: int = 4
## FOUR BLOCKS: idle, walk, run, and - since the second-idle row - an idle BREAK. It had ONE
## until T5.2, because `animation_for` took a boolean and there was nowhere for a third to be
## named, so the template shipped an art CONTRACT that could not express the gaits its own
## controller already had. The fourth is not a gait: it is the block a standing character
## drops into every `idle_break_after` seconds, and it is here rather than left to a game
## because a chooser with nothing to choose cannot be photographed.
const ANIMATIONS: int = 4
const IDLE_BLOCK: int = 0
const WALK_BLOCK: int = 1
const RUN_BLOCK: int = 2
const IDLE_BREAK_BLOCK: int = 3
## How far the legs and arms travel in each block. Idle barely moves, a run overreaches -
## these are the numbers that make the cycles tell themselves apart in a capture. The break
## barely travels either, because its whole difference is in the ARM and a break that also
## strode would read as a walk in a funny colour.
const BLOCK_SWING: Array[int] = [1, 2, 5, 1]
## And a cloth tint per block, on the ALT sheet's reasoning (gotcha 28): a running figure
## drawn from the walk block is still a person mid-stride, so the BLOCK has to be readable
## rather than judged. This is what turns a gait capture into a checkable prediction.
const BLOCK_TINT: Array[Color] = [
	Color(0.30, 0.45, 0.62), Color(0.24, 0.52, 0.44), Color(0.62, 0.34, 0.30),
	Color(0.66, 0.58, 0.24),
]
## HOW FAR THE BREAK RAISES THE FAR ARM, in cell pixels. The break's silhouette has to differ
## from the idle's by something a person can see in a still frame at x5, and a stretch above
## the head is the one change that alters the figure's OUTLINE rather than its colour - which
## matters because gotcha 28 says a recolour alone is a judgement and not a reading.
const BREAK_ARM_LIFT: int = 11

# THE EIGHT FACINGS ARE EIGHT POSES, AND UNTIL T5.8 THEY WERE ONE POSE DRAWN EIGHT TIMES.
# Measured on the sheet this replaces, over the figure band: facing 4 - the BACK, 180 degrees
# from the front - differed from facing 0 by 0.7% of the cell, which was the two eyes and
# nothing else, and facings 2 and 3 were BYTE-IDENTICAL. The code was never wrong. `_aim`
# quantises the facing and `update_from_velocity` advances the cycle, both asserted since
# Phase 1; the sheet had nothing different to draw, so every capture this project ever took
# showed a facing system that appeared to do nothing.
#
# FIVE POSES AND A MIRROR. Facing 0 is towards the camera and the facings run clockwise, so
# facings 1-3 turn towards screen right and 5-7 are their mirror images. Drawing the right half
# and flipping it is what makes east differ from west by a whole asymmetric figure rather than
# by which shoulder a flash sits on - and it is why a cell is now drawn into a CELL-sized image
# and blitted, which turns gotcha 57's cell bleed from an assertion into an impossibility.
const TURN_FRONT: int = 0
const TURN_SIDE: int = 2
const TURN_AWAY: int = 3
const TURN_BACK: int = 4
const FACING_TURN: Array[int] = [0, 1, 2, 3, 4, 3, 2, 1]
const FACING_MIRROR: Array[bool] = [false, false, false, false, false, true, true, true]
## Per turn - front, three-quarter, side, three-quarter back, back. The torso narrows and steps
## forward as the figure turns away, the legs close up into a front-to-back stride, the hair
## wraps further round the head, and the eyes go 2, 2, 1, 0, 0.
const TORSO_W: Array[int] = [12, 10, 7, 10, 12]
const TORSO_X: Array[int] = [10, 12, 13, 12, 10]
const HEAD_X: Array[int] = [16, 17, 18, 17, 16]
const LEG_GAP: Array[int] = [3, 3, 1, 3, 3]
const HAIR_WRAP: Array[int] = [0, 4, 8, 12, 15]
const EYE_COUNT: Array[int] = [2, 2, 1, 0, 0]
## A bright shoulder flash on the turned facings, kept from the sheet this replaces: it is the
## one mark that says "not square on" before the pose has been read at all.
const FLASH: Color = Color(0.92, 0.76, 0.35)

# THE SECOND SHEET, and it exists to be a DIFFERENT SHAPE rather than a second character.
# T2.1's headline claim is that a game swaps in a sheet with another cell and frame count and
# edits no code, so the proof needs a sheet that disagrees with the first one on every number:
# 4 facings not 8, a 24x40 cell not 32x48, and 3 frames in each of FIVE animation blocks rather
# than 4 frames in three. Its layout is assets/placeholder/character_alt_layout.tres.
#
# IT HAD TWO BLOCKS UNTIL T5.6, and that gap is the reason that row existed. T5.2 gave the
# DEFAULT sheet three blocks and left this one at idle and walk, so a sheet with a different
# cell size AND a full gait set existed nowhere in the repository - while the phase's whole
# claim is that a future game inherits working characters and changes only assets. A swap that
# proves only the GRID moves proves half of it. This sheet now names all five gaits
# SpriteSheetLayout can address: idle, walk, run, sneak, climb.
#
# AND ITS FOUR COLUMNS WERE THE SAME FIGURE UNTIL T5.8, exactly as the default sheet's eight
# were - three of them differed only by the column tally. Its three poses come from the same
# table: column 0 is the front, columns 1 and 3 are a profile and its mirror, column 2 the back.
#
# EVERY CELL IS SELF-LABELLING, which is the point. A character drawn from the wrong cell still
# looks like a character (gotcha 2, in the one form headless cannot answer), so each cell carries
# a column tally down its left edge, a frame tally along its foot and - since the gait set - a
# BLOCK tally down its right edge. A windowed capture can then be READ rather than judged: three
# left pips, two foot pips and four right pips is column 2, frame 1, block 3, and no amount of
# plausible-looking pixel art can fake that. Without the third tally the block would be the one
# thing in a capture that had to be inferred from a tint, which is exactly the judgement
# gotcha 28 says not to make.
const ALT_CELL: Vector2i = Vector2i(24, 40)
const ALT_DIRECTIONS: int = 4
const ALT_FRAMES: int = 3
## FIVE BLOCKS: idle, walk, run, sneak, climb - the whole of GameEnums.MoveState that
## SpriteSheetLayout can name a row for.
const ALT_ANIMATIONS: int = 5
const ALT_SNEAK_BLOCK: int = 3
const ALT_CLIMB_BLOCK: int = 4
## A colour per block, so which one is playing reads at a glance before the pips are counted.
const ALT_BLOCK_TINT: Array[Color] = [
	Color(0.28, 0.55, 0.42), Color(0.72, 0.38, 0.22), Color(0.78, 0.24, 0.30),
	Color(0.42, 0.30, 0.62), Color(0.20, 0.58, 0.68),
]
## How far the legs travel per block, and how far the body tips into it. A run overreaches and
## leans; a sneak barely shifts its weight; a climb does not stride at all.
const ALT_SWING: Array[int] = [0, 2, 4, 1, 0]
const ALT_LEAN: Array[int] = [0, 0, -1, 0, 0]
## Three poses on a four-facing sheet - front, side, back - and the west column is the east
## column mirrored, on the default sheet's reasoning above.
const ALT_SIDE: int = 1
const ALT_BACK: int = 2
const ALT_FACING_POSE: Array[int] = [0, 1, 2, 1]
const ALT_FACING_MIRROR: Array[bool] = [false, false, false, true]
const ALT_TORSO_W: Array[int] = [9, 6, 9]
const ALT_TORSO_X: Array[int] = [8, 10, 8]
const ALT_HEAD_X: Array[int] = [12, 13, 12]
const ALT_LEG_GAP: Array[int] = [2, 1, 2]
const ALT_HAIR_WRAP: Array[int] = [0, 6, 11]
const ALT_EYE_COUNT: Array[int] = [2, 1, 0]
const PIP: Color = Color(1.0, 0.95, 0.35)
## The block tally is WHITE against the column and frame tallies' yellow, so a capture read at a
## glance cannot mistake one edge's count for another's.
const BLOCK_PIP: Color = Color(1.0, 1.0, 1.0)

const SKIN: Color = Color(0.85, 0.68, 0.52)
const BOOT: Color = Color(0.28, 0.22, 0.18)
const HAIR: Color = Color(0.16, 0.12, 0.10)
const EYE: Color = Color(0.09, 0.09, 0.12)


func _initialize() -> void:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		print("FAIL could not create ", OUT_DIR)
		quit(1)
		return

	_save(_build_character_sheet(), "character_placeholder.png")
	_save(_build_alt_sheet(), "character_alt.png")
	_save(_build_grid(256, 32, Color(0.42, 0.44, 0.38), Color(0.36, 0.38, 0.33)), "ground_grid.png")
	_save(_build_grid(128, 16, Color(0.55, 0.52, 0.47), Color(0.47, 0.44, 0.40)), "stone.png")
	_save(_build_noise(128, Color(0.33, 0.42, 0.26), Color(0.24, 0.33, 0.19)), "grass.png")
	_save(_build_noise(128, Color(0.45, 0.33, 0.22), Color(0.36, 0.26, 0.17)), "wood.png")
	_save(_build_marker(64), "marker.png")
	print("OK placeholder art written to ", OUT_DIR)
	quit(0)


## A full gait sheet: 8 facings across, and FOUR 4-frame blocks down - idle, walk, run, and the
## idle break. Rows run idle.0-3, walk.0-3, run.0-3, break.0-3, which is the order
## `frame_index` reads and `SpriteSheetLayout` names through `idle_row`, `walk_row`, `run_row`
## and `idle_break_row`.
##
## EACH CELL IS DRAWN INTO A CELL-SIZED IMAGE AND BLITTED, for two reasons. The mirror is then
## free - `flip_x` on a cell is the whole west half of the sheet - and `_plot`'s bounds check
## becomes a check against the CELL rather than against the sheet, which is gotcha 57 answered
## by construction instead of by an assertion that notices afterwards.
func _build_character_sheet() -> Image:
	var rows: int = FRAMES * ANIMATIONS
	var sheet: Image = Image.create(CELL.x * DIRECTIONS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for facing: int in DIRECTIONS:
		for block: int in ANIMATIONS:
			for frame: int in FRAMES:
				var cell: Image = _character_cell(FACING_TURN[facing], frame, block)
				if FACING_MIRROR[facing]:
					cell.flip_x()
				var row: int = block * FRAMES + frame
				sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL),
					Vector2i(facing * CELL.x, row * CELL.y))
	return sheet


## One 32x48 figure, drawn facing screen-right for every turn that is not square on. Deliberately
## simple: a readable silhouette whose front, three-quarter, side and back tell themselves apart
## at a glance, which is the whole of this sheet's job.
func _character_cell(turn: int, frame: int, block: int) -> Image:
	var cell: Image = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	# A two-frame leg swing, held for two frames each, so the cycle reads at low framerates. The
	# BLOCK scales how far it travels: a run overreaches, an idle barely shifts its weight.
	var swing: int = [0, 1, 0, -1][frame] * BLOCK_SWING[block]
	# A run leans into it, which reads at a glance even before the tint is noticed.
	var lean: int = -1 if block == RUN_BLOCK else 0
	# A BREAK STRETCHES, and only on the second half of its cycle - so the block is not one
	# pose held for four cells, and `_an_idle_break_advances` has something to measure.
	var lift: int = BREAK_ARM_LIFT if block == IDLE_BREAK_BLOCK and frame >= 2 else 0
	# A back is a back because it is in its own shadow, not only because it has no face.
	var body: Color = BLOCK_TINT[block].darkened(0.30) if turn >= TURN_AWAY else BLOCK_TINT[block]
	var sleeve: Color = body.darkened(0.35)
	var width: int = TORSO_W[turn]
	var left: int = TORSO_X[turn] + lean
	var centre: int = left + width / 2

	_rect(cell, Vector2i(centre - LEG_GAP[turn] - 2, 36 + swing), Vector2i(4, 11), BOOT)
	_rect(cell, Vector2i(centre + LEG_GAP[turn] - 2, 36 - swing), Vector2i(4, 11), BOOT)
	_rect(cell, Vector2i(left, 20), Vector2i(width, 17), body)
	_rect(cell, Vector2i(left, 20), Vector2i(width, 3), sleeve)
	# A profile shows the NEAR arm only. Drawing the far one anyway is part of what made every
	# facing on the old sheet the same width and the same silhouette.
	if turn != TURN_SIDE:
		_rect(cell, Vector2i(left - 3, 22 - swing - lift), Vector2i(3, 12), sleeve)
	_rect(cell, Vector2i(left + width, 22 + swing - lift), Vector2i(3, 12), sleeve)
	_draw_head(cell, turn, HEAD_X[turn] + lean * 2, 13, 7)
	if turn != TURN_FRONT and turn != TURN_BACK:
		_rect(cell, Vector2i(left + width - 4, 21), Vector2i(4, 4), FLASH)
	return cell


## Head, hair and face - the half of a facing a player actually reads, and shared by both sheets
## because both need exactly the same five answers from it.
##
## THE HAIR WRAPS RATHER THAN MOVES. It is painted OVER the skin, so a back view is a head of
## hair with the same round silhouette rather than a box, and `wrap` reaching the full width of
## the head is what makes it faceless. `big` picks which sheet's tables to read: the default
## sheet has five turns and the alt sheet three, and they are the same question at two sizes.
func _draw_head(cell: Image, turn: int, head_x: int, at_y: int, radius: int) -> void:
	var big: bool = radius > 5
	var wrap: int = HAIR_WRAP[turn] if big else ALT_HAIR_WRAP[turn]
	var eyes: int = EYE_COUNT[turn] if big else ALT_EYE_COUNT[turn]
	var cap: Vector2i = Vector2i(head_x - radius, at_y - radius)
	_disc(cell, Vector2i(head_x, at_y), radius, SKIN)
	_rect(cell, cap, Vector2i(radius * 2 + 1, radius - 1), HAIR)
	_recolour(cell, cap, Vector2i(wrap, radius * 2 + 2), SKIN, HAIR)
	if eyes == 0:
		return
	_rect(cell, Vector2i(head_x + radius - 4, at_y + 1), Vector2i(2, 2), EYE)
	if eyes == 1:
		# A nose past the edge of the face. On a front view it would be a smudge; on a profile
		# it is the mark that says which way the head is pointing.
		_rect(cell, Vector2i(head_x + radius, at_y + 1), Vector2i(2, 2), SKIN)
		return
	_rect(cell, Vector2i(head_x - radius + 2, at_y + 1), Vector2i(2, 2), EYE)


## A grid texture. Reads scale and motion instantly, which is what a placeholder is for.
func _build_grid(size: int, cell: int, base: Color, line: Color) -> Image:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var on_line: bool = (x % cell == 0) or (y % cell == 0)
			image.set_pixel(x, y, line if on_line else base)
	return image


## Deterministic pseudo-noise. No RandomNumberGenerator, so the output is identical every
## run and does not show up as a spurious change in version control.
func _build_noise(size: int, low: Color, high: Color) -> Image:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var h: int = (x * 73856093) ^ (y * 19349663)
			var t: float = float(absi(h) % 1000) / 1000.0
			image.set_pixel(x, y, low.lerp(high, t))
	return image


## A magenta-and-black target, the traditional "this is missing" texture.
func _build_marker(size: int) -> Image:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: int = size / 2
	for y: int in size:
		for x: int in size:
			var checker: bool = ((x / (half / 2)) + (y / (half / 2))) % 2 == 0
			image.set_pixel(x, y, Color.MAGENTA if checker else Color.BLACK)
	return image


func _rect(image: Image, at: Vector2i, size: Vector2i, color: Color) -> void:
	for y: int in size.y:
		for x: int in size.x:
			_plot(image, at.x + x, at.y + y, color)


func _disc(image: Image, centre: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				_plot(image, centre.x + x, centre.y + y, color)


## Repaint one colour as another inside a box, and nothing else. This is how the hair gets round
## a head without becoming a rectangle: it can only take pixels the skin already owns.
func _recolour(image: Image, at: Vector2i, size: Vector2i, from: Color, to: Color) -> void:
	for y: int in size.y:
		for x: int in size.x:
			var point: Vector2i = at + Vector2i(x, y)
			if point.x < 0 or point.y < 0 \
					or point.x >= image.get_width() or point.y >= image.get_height():
				continue
			var found: Color = image.get_pixelv(point)
			# QUANTISED, so this cannot be is_equal_approx. An RGBA8 image stores 0.68 as 173/255,
			# which reads back as 0.6784 - near enough to see and far enough to fail an epsilon
			# compare, which is how the first run of this drew five bald heads.
			if absf(found.r - from.r) + absf(found.g - from.g) + absf(found.b - from.b) < 0.02:
				image.set_pixelv(point, to)


func _plot(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)


func _save(image: Image, file_name: String) -> void:
	var path: String = "%s/%s" % [OUT_DIR, file_name]
	var err: Error = image.save_png(path)
	if err == OK:
		print("  wrote %-30s %dx%d" % [file_name, image.get_width(), image.get_height()])
	else:
		print("  FAILED %s: %s" % [file_name, error_string(err)])


## The second sheet: 4 facings across, and 3 frames down in each of 5 animation blocks, so the
## rows run idle.0-2, walk.0-2, run.0-2, sneak.0-2, climb.0-2. See ALT_CELL for why it exists.
##
## THE PIPS GO ON AFTER THE MIRROR. A tally that flipped with the figure would put the column
## count down the right edge for half the sheet, and a reader counting pips off a capture has no
## way to know which half they are looking at - which would undo the one thing this sheet is for.
func _build_alt_sheet() -> Image:
	var rows: int = ALT_FRAMES * ALT_ANIMATIONS
	var sheet: Image = Image.create(
		ALT_CELL.x * ALT_DIRECTIONS, ALT_CELL.y * rows, false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0, 0, 0, 0))
	for column: int in ALT_DIRECTIONS:
		for row: int in rows:
			var cell: Image = _alt_cell(ALT_FACING_POSE[column], row / ALT_FRAMES,
				row % ALT_FRAMES)
			if ALT_FACING_MIRROR[column]:
				cell.flip_x()
			_draw_alt_pips(cell, column, row / ALT_FRAMES, row % ALT_FRAMES)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, ALT_CELL),
				Vector2i(column * ALT_CELL.x, row * ALT_CELL.y))
	return sheet


## One labelled figure. Simple on purpose: a readable body, a tint and a posture per gait, a pose
## per facing, and the three pip tallies that let a capture be read rather than believed.
##
## EACH GAIT DIFFERS IN SILHOUETTE AND NOT ONLY IN TINT. A capture whose only difference is a
## colour is still a judgement, and a sneak that merely wore purple would photograph as a walk
## in the wrong shirt: the crouch, the run's lean and the climb's raised arms are what make the
## five blocks tell themselves apart at a glance, with the pips there to settle it exactly.
func _alt_cell(pose: int, block: int, frame: int) -> Image:
	var cell: Image = Image.create(ALT_CELL.x, ALT_CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	var body: Color = ALT_BLOCK_TINT[block].darkened(0.30) if pose == ALT_BACK \
		else ALT_BLOCK_TINT[block]
	var swing: int = [0, 1, -1][frame] * ALT_SWING[block]
	# Only the idle block shifts its weight vertically; the moving blocks say it with the legs.
	var bob: int = [0, 1, 0][frame] if block == 0 else 0
	var lean: int = ALT_LEAN[block]
	# A sneak drops the whole figure and shortens the stride. Nothing else in the sheet changes
	# the character's HEIGHT, which is what makes it unmistakable beside a walk.
	var crouch: int = 4 if block == ALT_SNEAK_BLOCK else 0
	var top: int = 14 + bob + crouch
	var width: int = ALT_TORSO_W[pose]
	var left: int = ALT_TORSO_X[pose] + lean
	var centre: int = left + width / 2

	_rect(cell, Vector2i(centre - ALT_LEG_GAP[pose] - 1, 27 + swing + crouch),
		Vector2i(3, 9 - crouch), BOOT)
	_rect(cell, Vector2i(centre + ALT_LEG_GAP[pose] - 1, 27 - swing + crouch),
		Vector2i(3, 9 - crouch), BOOT)
	_rect(cell, Vector2i(left, top), Vector2i(width, 15 - crouch), body)
	_draw_alt_arms(cell, pose, block, frame, body, top, left)
	_draw_head(cell, pose, ALT_HEAD_X[pose] + lean, 9 + bob + crouch, 5)
	return cell


## Arms, and the climb is the one that matters. A ladder is the only gait in this template whose
## POSE differs rather than its pace, and it is also the gait T5.3 found undrawable for two
## rows - so it gets the silhouette that cannot be mistaken for anything else on the sheet. A
## profile hides its far arm, exactly as the default sheet's does.
func _draw_alt_arms(image: Image, pose: int, block: int, frame: int, body: Color,
		top: int, left: int) -> void:
	var sleeve: Color = body.darkened(0.35)
	var width: int = ALT_TORSO_W[pose]
	if block == ALT_CLIMB_BLOCK:
		var reach: int = [0, 3, 6][frame]
		if pose != ALT_SIDE:
			_rect(image, Vector2i(left - 4, top - 6 - reach), Vector2i(3, 10 + reach), sleeve)
		_rect(image, Vector2i(left + width + 1, top - reach), Vector2i(3, 4 + reach), sleeve)
		return
	# Everything else swings its arms opposite its legs, by the same reach as the block's stride.
	var swing: int = [0, 1, -1][frame] * ALT_SWING[block]
	if pose != ALT_SIDE:
		_rect(image, Vector2i(left - 3, top - swing), Vector2i(3, 10), sleeve)
	_rect(image, Vector2i(left + width, top + swing), Vector2i(3, 10), sleeve)


## The three tallies. column + 1 down the left edge, frame + 1 across the foot, block + 1 down
## the right edge - so a windowed capture is COUNTED rather than judged, which is the only
## answer to gotcha 28 that survives a sheet with five blocks instead of two.
##
## THE FOOT TALLY SITS AT y - 7 AND NOT AT y - 3, because at y - 3 IT COULD NOT BE READ IN THE
## GAME. The sprite is anchored by its feet, so its last few rows meet the ground plane and are
## occluded by it: the first gait capture of T5.6 showed one foot pip where the decoded frame
## said three. The tally was correct, the sheet was correct, and the photograph was unreadable -
## which is a capture standard failing rather than a drawing failing, and exactly the kind of
## thing only a windowed run finds.
func _draw_alt_pips(cell: Image, column: int, block: int, frame: int) -> void:
	for pip: int in column + 1:
		_rect(cell, Vector2i(1, 2 + pip * 4), Vector2i(2, 2), PIP)
	for pip: int in frame + 1:
		_rect(cell, Vector2i(2 + pip * 4, ALT_CELL.y - 7), Vector2i(2, 2), PIP)
	for pip: int in block + 1:
		_rect(cell, Vector2i(ALT_CELL.x - 3, 2 + pip * 4), Vector2i(2, 2), BLOCK_PIP)
