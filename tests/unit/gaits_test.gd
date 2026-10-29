extends TestCase
## WHETHER A DECLARED GAIT IS ACTUALLY DRAWN, which is the half T5.2 left open.
##
## `art_contract_test.gd` proves `SpriteSheetLayout.animation_for` maps every `MoveState` to a
## block, and `traversal_test.gd` proves a climbing body reports `MoveState.CLIMB`. Both ends
## were asserted and the WIRE between them was not, so `climb_row` was exported, defaulted,
## range-limited, validated by `problems()` and impossible to draw: `_physics_process` returns
## early while a climb owns the body, so the visual was never told. This file asserts the wire.
##
## IT ALSO ASSERTS THAT A CYCLE ADVANCES, which nothing did. `update_from_velocity` pinned the
## frame to 0 whenever the character was not moving horizontally, so a four-cell idle block drew
## its first cell forever - "more than one idle" was on the roadmap while ONE idle had never
## animated. Whether a standing character breathes is the SHEET's answer: a sheet whose idle
## block is its walk block has nothing to play and must keep holding the pose, because animating
## that case is walking on the spot.
##
## FRAME NUMBERS ARE DECODED, NOT ASSUMED. `frame_index` is
## `(animation * frames + frame) * facings + column`, so the block and the cell within it are
## both recoverable from the one number `Sprite3D` exposes. Asserting the decoded BLOCK is what
## makes these assertions fail on the real defect: a state that never arrives leaves the idle
## block drawn, which looks exactly like a character standing still.
##
## OWNS: that a MoveState reaches the sprite and that a block's cycle advances.
## MUST NOT: re-assert the layout's own block mapping (art_contract_test), the direction-to-
##   column mapping (facing_test), or name demo content.

const FACINGS: int = 8
const FRAMES: int = 4
const CELL: Vector2i = Vector2i(32, 48)
## A sheet with four distinct blocks: idle, walk, run, climb.
const BLOCKS: int = 4
const IDLE_ROW: int = 0
const WALK_ROW: int = 1
const RUN_ROW: int = 2
const CLIMB_ROW: int = 3
## One physics frame at 60Hz.
const STEP: float = 1.0 / 60.0
## Straight up a ladder: no horizontal component at all, which is the case that was broken.
const CLIMB_VELOCITY: Vector3 = Vector3(0.0, 2.6, 0.0)
const WALK_VELOCITY: Vector3 = Vector3(1.0, 0.0, 0.0)

var _visual: CharacterVisual = null


func run() -> void:
	plan(12)
	_a_vertical_climb_draws_the_climb_block()
	_a_named_gait_reaches_the_sprite()
	_an_idle_block_of_its_own_animates()
	_an_idle_that_is_the_walk_block_holds_its_pose()


## THE REGRESSION. A climb is entirely vertical, so `Vector2(velocity.x, velocity.z)` is zero
## and "moving" derived from it is false - which pinned the frame AND fell through to the idle
## block. Both halves are asserted here because either one alone still hides the sheet's climb
## cycle: the right block held at cell 0 is as wrong as the wrong block advancing.
func _a_vertical_climb_draws_the_climb_block() -> void:
	_open_character(true)
	equal("a standing character starts on the idle block", _block(), IDLE_ROW)
	_visual.update_from_velocity(CLIMB_VELOCITY, STEP, GameEnums.MoveState.CLIMB)
	equal("a vertical climb draws the climb block", _block(), CLIMB_ROW)
	var first: int = _cell()
	_advance_for(1.0, CLIMB_VELOCITY, GameEnums.MoveState.CLIMB)
	equal("and its cycle advances over a second", _cell() != first, true)
	equal("without leaving the climb block", _block(), CLIMB_ROW)
	# Facing must survive a climb: quantising a zero horizontal vector would swing the character
	# round to face the camera halfway up the ladder.
	var facing: GameEnums.Facing = _visual.facing()
	_advance_for(1.0, CLIMB_VELOCITY, GameEnums.MoveState.CLIMB)
	equal("a vertical climb does not turn the character", _visual.facing(), facing)
	_close_character()


## The other named gaits still arrive, so the fix did not buy the climb at their expense.
func _a_named_gait_reaches_the_sprite() -> void:
	_open_character(true)
	_visual.update_from_velocity(WALK_VELOCITY, STEP, GameEnums.MoveState.WALK)
	equal("walking draws the walk block", _block(), WALK_ROW)
	_visual.update_from_velocity(WALK_VELOCITY, STEP, GameEnums.MoveState.RUN)
	equal("running draws the run block", _block(), RUN_ROW)
	# A state the sheet names no row for is standing there, not walking on the spot.
	_visual.update_from_velocity(Vector3.ZERO, STEP, GameEnums.MoveState.BUSY)
	equal("a held character falls back to the idle block", _block(), IDLE_ROW)
	_close_character()


## ONE idle that animates, which is what "a standing character is not a held pose" actually
## needed - a second idle block is a chooser on top of this, not a substitute for it.
func _an_idle_block_of_its_own_animates() -> void:
	_open_character(true)
	var first: int = _cell()
	_advance_for(1.0, Vector3.ZERO, GameEnums.MoveState.IDLE)
	equal("a distinct idle block advances while standing still", _cell() != first, true)
	equal("and stays on the idle block", _block(), IDLE_ROW)
	_close_character()


## The compatibility half, and the reason the sheet decides rather than a flag: every sheet
## authored before T2.1 had one block, so `idle_row == walk_row`. Animating it would replay the
## walk cycle on the spot, which is the bug T5.2 fixed for run and sneak from the other side.
func _an_idle_that_is_the_walk_block_holds_its_pose() -> void:
	_open_character(false)
	_advance_for(1.0, Vector3.ZERO, GameEnums.MoveState.IDLE)
	equal("a single-block sheet holds cell 0 while standing", _cell(), 0)
	# And it still animates when it MOVES: holding the pose is about standing still only.
	var first: int = _cell()
	_advance_for(1.0, WALK_VELOCITY, GameEnums.MoveState.WALK)
	equal("but the same sheet still animates a walk", _cell() != first, true)
	_close_character()


## Feed the visual `seconds` worth of fixed physics frames.
func _advance_for(seconds: float, velocity: Vector3, state: GameEnums.MoveState) -> void:
	var frames: int = int(seconds / STEP)
	for _i: int in frames:
		_visual.update_from_velocity(velocity, STEP, state)


## The animation block being drawn, decoded from `sprite.frame`.
func _block() -> int:
	@warning_ignore("integer_division")
	var row: int = _visual.sprite.frame / FACINGS
	@warning_ignore("integer_division")
	var block: int = row / FRAMES
	return block


## The cell WITHIN the current block.
func _cell() -> int:
	@warning_ignore("integer_division")
	var row: int = _visual.sprite.frame / FACINGS
	return row % FRAMES


## `distinct_idle` chooses between the two sheets that matter: one with a real idle cycle, and
## the single-block sheet every layout authored before T2.1 is.
func _open_character(distinct_idle: bool) -> void:
	var layout := SpriteSheetLayout.new()
	layout.facings = FACINGS
	layout.frames = FRAMES
	layout.animations = BLOCKS
	layout.cell_size = CELL
	layout.idle_row = IDLE_ROW if distinct_idle else WALK_ROW
	layout.walk_row = WALK_ROW
	layout.run_row = RUN_ROW
	layout.climb_row = CLIMB_ROW
	_visual = CharacterVisual.new()
	# Before attach: `_ready` resolves the layout, and an unset one logs a warning and assumes.
	_visual.layout = layout
	attach(_visual)


func _close_character() -> void:
	_visual.queue_free()
	_visual = null
