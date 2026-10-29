class_name SpriteSheetLayout
extends Resource
## How a character sprite sheet is cut up, as authored data. The art CONTRACT this template
## ships, and the reason a game with a different sheet edits no code.
##
## WHY THIS EXISTS. CharacterVisual used to carry `FACING_COUNT = 8` and `FRAME_COUNT = 4` as
## constants, and the eight-way sector maths as a SEPARATE literal `TAU / 8.0` that had to agree
## with the first by hand. Two places holding one number is a bug waiting for the first game whose
## sheet has four facings. Here the count appears once and the sector width is DERIVED from it, so
## the two cannot disagree.
##
## THE SHEET IS COLUMNS OF FACING BY ROWS OF FRAME, and the rows are grouped into ANIMATIONS:
##
##     facings = 4, frames = 3, animations = 2, idle_row = 0, walk_row = 1
##
##             col 0    col 1    col 2    col 3
##     row 0   idle.0   idle.0   idle.0   idle.0     <- animation 0 (idle), frame 0
##     row 1   idle.1   ...                          <- animation 0, frame 1
##     row 2   idle.2   ...                          <- animation 0, frame 2
##     row 3   walk.0   ...                          <- animation 1 (walk), frame 0
##     row 4   walk.1   ...
##     row 5   walk.2   ...
##
## So `sheet_rows()` is `frames * animations`, and an animation is addressed by its INDEX, not by
## its first row — an author who moves the walk block down does not have to recount.
## `animations = 1` with both rows at 0 is the single-block sheet this project shipped before
## T2.1, which is why every existing sheet keeps working unchanged.
##
## A FACING IS NOT A COLUMN. `GameEnums.Facing` has eight values because that is what the GAME
## reasons about — which way a character is turned. How many of those the ART distinguishes is a
## separate question this resource answers, and `column_for_angle` answers it by quantising the
## angle into `facings` sectors rather than by mapping down from eight.
##
## OWNS: the dimensions of one sheet, and validating them against the texture.
## MUST NOT: hold a texture, touch a node, know what animation a character is playing, or touch
## an autoload — tools/ loads content classes under `--script`, where autoload identifiers do not
## resolve, so a single `Log` call here would break a build gate.

## Cells across: how many directions the art distinguishes. The sector width is derived from
## this and nothing else.
@export_range(1, 32, 1) var facings: int = 8
## Cells down within ONE animation: the length of its cycle.
@export_range(1, 64, 1) var frames: int = 4
## How many animation blocks are stacked down the sheet. 1 is a sheet with a single cycle.
@export_range(1, 32, 1) var animations: int = 1
## One cell in texture pixels. DECLARED rather than divided out of the texture, so a sheet of the
## wrong size is a named problem instead of every character in the game silently misplaced.
@export var cell_size: Vector2i = Vector2i(32, 48)
## Which animation block plays when standing still, and which when moving. Equal values mean the
## sheet has no separate idle, which is legal and was the only possibility before T2.1.
@export_range(0, 31, 1) var idle_row: int = 0
@export_range(0, 31, 1) var walk_row: int = 0
## THE GAITS, and -1 MEANS "REPLAY THE WALK BLOCK". A sheet with no distinct run cycle is the
## normal case and was the ONLY case before T5.2 - `animation_for` took a bool, so run and
## sneak drew the walk block faster and nothing else. Declaring these as -1 rather than 0
## matters: 0 is a real row, so a default of 0 would silently draw the IDLE block for a
## running character on every sheet that had not been updated.
@export_range(-1, 31, 1) var run_row: int = -1
@export_range(-1, 31, 1) var sneak_row: int = -1
@export_range(-1, 31, 1) var climb_row: int = -1

## THE SECOND IDLE, AND THE THING THAT CHOOSES IT. Every row above is chosen by a
## `GameEnums.MoveState` the game already knows; this one is not, because standing still is not
## a state the game distinguishes from standing still. So the sheet has to carry the chooser
## too, and these two fields ARE it: `idle_break_row` names the block and `idle_break_after`
## says how many seconds of unbroken standing start it.
##
## WHY DWELL AND NOT WEATHER, A SCHEDULE, OR AN AREA TAG. Those were the other candidates and
## each of them needs an autoload - `Weather`, `Clock`, `Flags` - which this file's MUST NOT
## line forbids outright and which `CharacterVisual`'s forbids from the other side: it is told
## a velocity and a state, and it draws. Dwell is the one trigger derivable from what the
## visual is ALREADY handed every frame, so it is the only one of the four that needs no new
## dependency anywhere. The others are not lost: a game that wants a rain idle pushes a
## MoveState, or swaps the layout resource, and neither needs a line in this file.
##
## BOTH OR NEITHER, and `problems()` says so. A row with no delay is a block nothing ever
## plays, and a delay with no row is a timer that fires nothing - gotcha 38's shape twice over,
## because either half alone looks configured and draws exactly what it drew before.
@export_range(-1, 31, 1) var idle_break_row: int = -1
@export_range(0.0, 120.0, 0.5) var idle_break_after: float = 0.0




## WHICH ANIMATION BLOCK A MOVE STATE PLAYS. It took a BOOLEAN until T5.2, which is why a sheet
## could only ever have an idle cycle and a walk cycle: run and sneak replayed the walk block at a
## different rate and there was nowhere to put a distinct one. `GameEnums.MoveState` had ten
## values and `Events.player_state_changed` was emitted and listened to by nothing, so the
## information existed and had no way to reach the sprite.
##
## THE FALLBACK CHAIN IS THE POINT, not a convenience. A gait row left at -1 inherits the WALK
## block, so every sheet authored before this existed behaves exactly as it did, and a game adds a
## run cycle by drawing one and naming its row - no code, in this file or anywhere else. States
## with no gait of their own fall to IDLE: there is no jumping and no swimming in this template,
## and BUSY and LOCKED are "something else is driving", which looks like standing there.
##
## Clamped rather than trusted, because a row past the end of the sheet should draw the last block
## instead of an out-of-range cell - and `problems()` reports it so the author hears about it.
func animation_for(state: GameEnums.MoveState) -> int:
	return clampi(_row_for(state), 0, animations - 1)


func _row_for(state: GameEnums.MoveState) -> int:
	match state:
		GameEnums.MoveState.WALK:
			return walk_row
		GameEnums.MoveState.RUN:
			return run_row if run_row >= 0 else walk_row
		GameEnums.MoveState.SNEAK:
			return sneak_row if sneak_row >= 0 else walk_row
		GameEnums.MoveState.CLIMB:
			return climb_row if climb_row >= 0 else walk_row
		_:
			return idle_row


## Every gait this layout actually draws separately, for a report a person can read. A sheet whose
## run and walk are the same block is not a problem - it is the common case - but it is worth
## being able to SEE which blocks a sheet really has rather than inferring it from four numbers.
func distinct_gaits() -> int:
	var rows: Dictionary[int, bool] = {}
	for state: GameEnums.MoveState in [
		GameEnums.MoveState.IDLE, GameEnums.MoveState.WALK,
		GameEnums.MoveState.RUN, GameEnums.MoveState.SNEAK, GameEnums.MoveState.CLIMB,
	]:
		rows[animation_for(state)] = true
	return rows.size()

## DOES THIS SHEET HAVE A SECOND IDLE AT ALL? Both halves, deliberately: a caller asking
## "may this character fidget" must get `false` from a half-configured sheet rather than a
## `true` it then has to qualify, because the one consumer would otherwise compare a dwell
## against a threshold of zero and break on the very first frame it stood still.
func has_idle_break() -> bool:
	return idle_break_row >= 0 and idle_break_after > 0.0


## Which block the break draws. Falls back to the IDLE animation rather than to 0, on
## `_row_for`'s reasoning exactly: 0 is a real row, so a sheet whose idle lives at row 2 would
## otherwise have its break draw somebody else's cycle. Clamped for the same reason
## `animation_for` is - a row past the end draws the last block and `problems()` reports it.
func idle_break_animation() -> int:
	if idle_break_row < 0:
		return animation_for(GameEnums.MoveState.IDLE)
	return clampi(idle_break_row, 0, animations - 1)


## `distinct_gaits()` DELIBERATELY DOES NOT COUNT THE BREAK, and this is the note that saves
## the next session from re-deciding it: a gait is a `GameEnums.MoveState`, that method
## iterates them, and a break is not one - it is a variant of one. The break's report is
## `problems()`, which is where a half-configured one becomes a sentence a person reads.


## Total rows down the sheet. Derived: an author sets the cycle length and the block count.
func sheet_rows() -> int:
	return frames * animations


## The whole sheet in texture pixels, for validating a texture against this layout.
func sheet_size() -> Vector2i:
	return Vector2i(cell_size.x * facings, cell_size.y * sheet_rows())


## Width of one direction sector in radians. THE derivation — one number, one place.
func sector_radians() -> float:
	return TAU / float(facings)


## Quantise an angle (0 = towards the camera, increasing clockwise) into a sheet column.
func column_for_angle(angle: float) -> int:
	return posmod(roundi(angle / sector_radians()), facings)



## The Sprite3D `frame` for one cell. Sprite3D numbers cells left to right, then top to bottom,
## so the row has to be multiplied by the column count and not by anything else.
func frame_index(column: int, frame: int, animation: int) -> int:
	var row: int = clampi(animation, 0, animations - 1) * frames + posmod(frame, frames)
	return row * facings + posmod(column, facings)


## Everything wrong with this layout, as data rather than a log line, so the same check serves
## the game, the test suite and a headless validator. `texture` may be null: a layout is valid
## on its own, and only a MISMATCH is a problem.
func problems(texture: Texture2D = null) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if cell_size.x <= 0 or cell_size.y <= 0:
		found.append("%s declares a cell of %s, which has no area" % [resource_path, cell_size])
	# EVERY named row, not just the two that existed before T5.2. A gait row past the end of the
	# sheet is exactly gotcha 38's shape - the loader keeps whatever number was typed, the clamp
	# in `animation_for` quietly draws the last block, and the character animates plausibly and
	# wrongly. -1 is not a problem: it MEANS "inherit the walk block".
	var named: Dictionary[String, int] = {
		"idle_row": idle_row, "walk_row": walk_row, "run_row": run_row,
		"sneak_row": sneak_row, "climb_row": climb_row, "idle_break_row": idle_break_row,
	}
	for field: String in named:
		if named[field] >= animations:
			found.append("%s names %s row %d, past its %d animation(s)" % [
				resource_path, field, named[field], animations,
			])
	found.append_array(_idle_break_problems())
	if texture != null and Vector2i(texture.get_size()) != sheet_size():
		found.append("%s expects a %s sheet; the texture is %s" % [
			resource_path, sheet_size(), Vector2i(texture.get_size()),
		])
	return found


## THE THREE WAYS A SECOND IDLE IS CONFIGURED AND STILL DRAWS NOTHING NEW. Split out of
## `problems()` because that function was already at the length where one more branch starts
## hiding the others, and because these three share a subject the size and row checks do not.
##
## All three are gotcha 38's shape: the loader keeps whatever was typed, nothing is out of
## range, the character animates plausibly, and the block the author drew is never once shown.
func _idle_break_problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if idle_break_row >= 0 and idle_break_after <= 0.0:
		found.append("%s names idle break row %d but never lets it start" % [
			resource_path, idle_break_row,
		])
	if idle_break_after > 0.0 and idle_break_row < 0:
		found.append("%s waits %.1fs for an idle break it names no row for" % [
			resource_path, idle_break_after,
		])
	if idle_break_row >= 0 and idle_break_row == idle_row:
		found.append("%s breaks its idle to row %d, which is its idle block" % [
			resource_path, idle_break_row,
		])
	return found
