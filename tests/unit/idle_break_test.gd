extends TestCase
## THE SECOND IDLE AND THE THING THAT CHOOSES IT. Phase T5's last exit criterion, and the half
## `gaits_test.gd` said in writing it was not: "a second idle block is a chooser on top of this,
## not a substitute for it."
##
## WHAT WAS MISSING WAS NEVER THE BLOCK. `SpriteSheetLayout` could address 32 animations and
## `frame_index` could draw any of them since T2.1, so a sheet could always CARRY a second idle -
## there was simply nothing that would ever ask for one, because every block in this template is
## chosen by a `GameEnums.MoveState` and standing still is one state. So a character stood in
## exactly one way forever, and the gap was a chooser rather than a row.
##
## THE CHOOSER IS DWELL TIME, AND ITS THRESHOLD IS ON THE SHEET. That split is what these
## assertions are mostly about: `has_idle_break()` and `problems()` prove the SHEET owns the
## decision, and the CharacterVisual half proves the file that draws contributes only arithmetic
## on the delta it is already handed. If the threshold ever migrates into `character_visual.gd`
## as a constant, the layout half of this file goes green while the row's whole point is gone -
## which is why both halves are here rather than in two files.
##
## BOTH DIRECTIONS OF THE HALF-CONFIGURED SHEET, because that is the defect with a sign. A break
## row with no delay and a delay with no row both look configured, are both in range, and both
## draw exactly what the sheet drew before - gotcha 38 twice.
##
## OWNS: whether a sheet HAS a second idle, and whether standing still long enough draws it.
## MUST NOT: re-assert the block mapping for the five gaits (art_contract_test), that a single
##   idle cycle advances at all (gaits_test), the direction-to-column mapping (facing_test), or
##   name demo content.

const FACINGS: int = 8
const FRAMES: int = 4
const CELL: Vector2i = Vector2i(32, 48)
## A sheet with four blocks: idle, walk, a spare, and the break - so "past the end" is a number
## well past it rather than one off.
const BLOCKS: int = 4
const IDLE_ROW: int = 0
const WALK_ROW: int = 1
const BREAK_ROW: int = 3
## Long enough that the "before the threshold" assertions have room to stand in, short enough
## that a case is not seconds of simulated time. Fed as fixed frames, so no wall clock is
## involved and the number is exact.
const DWELL: float = 2.0
## One physics frame at 60Hz.
const STEP: float = 1.0 / 60.0
const WALK_VELOCITY: Vector3 = Vector3(1.0, 0.0, 0.0)
## HOW LONG ONE BREAK TAKES TO PLAY, derived from the two numbers that decide it rather than
## typed: FRAMES cells at CharacterVisual's default `idle_fps` of 3. Derived because the first
## draft of this file typed 2.0 seconds here and the case failed for a reason that was not a
## defect - the break had ended 0.67s into that wait, and those 0.67s were already banked
## against the NEXT threshold, so the following stand crossed it early. The arithmetic has to
## be visible or the case measures the wrong thing while looking right.
const BREAK_SECONDS: float = float(FRAMES) / 3.0

var _visual: CharacterVisual = null


func run() -> void:
	plan(26)
	_a_sheet_says_whether_it_has_a_second_idle()
	_a_half_configured_break_is_a_reported_problem()
	_standing_long_enough_draws_the_second_idle()
	_the_break_plays_once_and_hands_back()
	_moving_cancels_the_break_and_restarts_the_clock()
	_a_sheet_with_no_break_never_leaves_its_idle()


## THE SHEET OWNS THE DECISION, and `has_idle_break()` is that ownership as one bool. Both
## halves are required on purpose: the consumer compares a dwell against `idle_break_after`, so
## a row with a threshold of zero would break on the first frame the character stood still.
func _a_sheet_says_whether_it_has_a_second_idle() -> void:
	equal("a sheet naming no break row has no second idle", _sheet(-1, 0.0).has_idle_break(),
		false)
	equal("a row with no delay is not a second idle",
		_sheet(BREAK_ROW, 0.0).has_idle_break(), false)
	equal("a delay with no row is not a second idle", _sheet(-1, DWELL).has_idle_break(), false)
	equal("both named is a second idle", _sheet(BREAK_ROW, DWELL).has_idle_break(), true)
	equal("and it draws the row it names", _sheet(BREAK_ROW, DWELL).idle_break_animation(),
		BREAK_ROW)
	# Falls back to the IDLE animation and not to 0, on `_row_for`'s reasoning: 0 is a real row,
	# so a sheet whose idle lives elsewhere would otherwise draw somebody else's cycle.
	var high: SpriteSheetLayout = _sheet(-1, 0.0)
	high.idle_row = 2
	equal("a sheet with no break falls back to its own idle block",
		high.idle_break_animation(), 2)
	equal("a break row past the sheet draws its last block",
		_sheet(BLOCKS + 4, DWELL).idle_break_animation(), BLOCKS - 1)


## THE THREE WAYS IT IS CONFIGURED AND STILL DRAWS NOTHING NEW. Each is gotcha 38's shape: in
## range, kept by the loader, plausible on screen, and the authored block never once shown.
func _a_half_configured_break_is_a_reported_problem() -> void:
	equal("a fully named break is no problem", _sheet(BREAK_ROW, DWELL).problems().size(), 0)
	equal("a break row with no delay is a problem",
		_names(_sheet(BREAK_ROW, 0.0).problems(), "never lets it start"), true)
	equal("a delay with no break row is a problem",
		_names(_sheet(-1, DWELL).problems(), "names no row for"), true)
	equal("a break onto the idle block is a problem",
		_names(_sheet(IDLE_ROW, DWELL).problems(), "which is its idle block"), true)
	equal("a break row past the animations is a problem",
		_names(_sheet(BLOCKS + 4, DWELL).problems(), "idle_break_row"), true)


## THE HEADLINE. A character that has stood still for the authored number of seconds draws a
## DIFFERENT block, and the block it draws is the one the sheet named.
func _standing_long_enough_draws_the_second_idle() -> void:
	_open(BREAK_ROW, DWELL)
	equal("a standing character starts on the idle block", _block(), IDLE_ROW)
	# Just short of the threshold, which is the assertion that makes the next one mean anything:
	# without it a break that fired on frame one would pass just as well.
	_stand_for(DWELL - 0.5)
	equal("and is still on it before the dwell threshold", _block(), IDLE_ROW)
	_stand_for(0.6)
	equal("standing past the threshold draws the second idle", _block(), BREAK_ROW)
	var cell: int = _cell()
	_stand_for(0.4)
	equal("and the second idle's own cycle advances", _cell() != cell, true)
	_close()


## IT PLAYS ONCE. A break that looped would be a second idle the character never leaves, which
## is the same defect as having one, with a different row number.
func _the_break_plays_once_and_hands_back() -> void:
	_open(BREAK_ROW, DWELL)
	_stand_for(DWELL + 0.1)
	equal("the break has started", _block(), BREAK_ROW)
	_stand_for(BREAK_SECONDS + 0.2)
	equal("one cycle later it is back on the idle block", _block(), IDLE_ROW)
	# AND THE CLOCK RESTARTS FROM THE END OF THE BREAK, not from its start - so the gap a player
	# sees between two fidgets is the authored number rather than that number minus the block.
	# Standing DWELL - 0.5 more is therefore still short of the next one, and this is the
	# assertion that would catch a reset placed at the break's START instead of its end.
	_stand_for(DWELL - 0.5)
	equal("and the dwell that follows it is a full one", _block(), IDLE_ROW)
	_stand_for(0.6)
	equal("standing on draws it a second time", _block(), BREAK_ROW)
	_close()


## MOVING OUTRANKS IT, IN BOTH DIRECTIONS. A fidget is what a character does INSTEAD of standing
## there, so walking off mid-stretch has to show the walk block on that frame; and standing
## still is only cumulative while it is UNBROKEN, or a character who paces would fidget on a
## schedule nobody authored.
func _moving_cancels_the_break_and_restarts_the_clock() -> void:
	_open(BREAK_ROW, DWELL)
	_stand_for(DWELL + 0.1)
	equal("the break is running", _block(), BREAK_ROW)
	_visual.update_from_velocity(WALK_VELOCITY, STEP, GameEnums.MoveState.WALK)
	equal("one moving frame ends it", _block(), WALK_ROW)
	_stand_for(DWELL - 0.5)
	equal("and the dwell it restarts is the full one", _block(), IDLE_ROW)
	# INTERRUPTED STANDING DOES NOT ACCUMULATE: two stands that are each short of the threshold
	# but sum past it, with one walking frame between them, is never a break.
	#
	# THE SECOND STAND'S LENGTH IS LOAD-BEARING AND THE FIRST DRAFT GOT IT WRONG. It was
	# DWELL - 0.3 as well, which summed to 3.4s: under a visual that does not reset the dwell the
	# break duly started 0.3s in, and then FINISHED 1.33s later - still inside the stand - so the
	# case asserted the idle block and passed over the defect it was written for. Gotcha 70's
	# shape. Short enough that a wrongly-started break is still on screen when it is measured.
	_open(BREAK_ROW, DWELL)
	_stand_for(DWELL - 0.3)
	_visual.update_from_velocity(WALK_VELOCITY, STEP, GameEnums.MoveState.WALK)
	_stand_for(DWELL - 1.0)
	equal("interrupted standing does not accumulate into a break", _block(), IDLE_ROW)
	_close()


## THE COMPATIBILITY HALF, and the reason -1 is the default rather than 0. Every sheet authored
## before this row names no break, and must stand exactly as it did however long it stands.
func _a_sheet_with_no_break_never_leaves_its_idle() -> void:
	_open(-1, 0.0)
	_stand_for(6.0)
	equal("a sheet naming no break holds its idle block for six seconds", _block(), IDLE_ROW)
	# And the idle it holds is still the ANIMATED one gaits_test proved - not frozen by the new
	# branch on the way past.
	var cell: int = _cell()
	_stand_for(0.4)
	equal("and that idle still animates", _cell() != cell, true)
	_close()


## Does any problem line contain `phrase`? The lines are prose for a person, so matching a
## fragment is what keeps these assertions about the CONDITION rather than about the wording.
func _names(problems: PackedStringArray, phrase: String) -> bool:
	for line: String in problems:
		if line.contains(phrase):
			return true
	return false


## A sheet whose idle block genuinely differs from its walk block, so the idle animates and a
## break is an interruption of something rather than of a held pose.
func _sheet(break_row: int, after: float) -> SpriteSheetLayout:
	var made := SpriteSheetLayout.new()
	made.facings = FACINGS
	made.frames = FRAMES
	made.animations = BLOCKS
	made.cell_size = CELL
	made.idle_row = IDLE_ROW
	made.walk_row = WALK_ROW
	made.idle_break_row = break_row
	made.idle_break_after = after
	return made


func _open(break_row: int, after: float) -> void:
	if _visual != null:
		_close()
	_visual = CharacterVisual.new()
	# Before attach: `_ready` resolves the layout, and an unset one logs a warning and assumes.
	_visual.layout = _sheet(break_row, after)
	attach(_visual)


func _close() -> void:
	_visual.queue_free()
	_visual = null


## Feed the visual `seconds` worth of fixed physics frames of standing perfectly still.
func _stand_for(seconds: float) -> void:
	for _i: int in int(seconds / STEP):
		_visual.update_from_velocity(Vector3.ZERO, STEP, GameEnums.MoveState.IDLE)


## The animation block being drawn, decoded from `sprite.frame` rather than asked of the visual -
## the same decode `gaits_test.gd` uses, and for its reason: the one number Sprite3D exposes is
## the only evidence that anything reached the sprite.
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
