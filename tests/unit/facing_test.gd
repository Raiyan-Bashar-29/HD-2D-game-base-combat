extends TestCase
## WHICH WAY A CHARACTER FACES WHEN IT TRAVELS, WHICH IS PHASE 1'S LAST OPEN CRITERION.
##
## `art_contract_test.gd` proves the LAYOUT's quantisation - every 45 degrees is the next column
## - but its MUST NOT line forbids asserting what a character looks like, so nothing connected
## that to a direction of travel. This file is that connection: the mapping from an XZ movement
## vector to a `GameEnums.Facing` and to a sheet column, which is where an axis swap or a sign
## error would live. Gotcha 28 is the reason it needs assertions rather than a screenshot: a
## sprite drawn from the wrong column is still a person, upright and lit and facing SOME
## direction, so a capture of it cannot be judged.
##
## EVERY ASSERTION HERE IS CAMERA-YAW INDEPENDENT, on purpose. `_screen_angle` subtracts the
## active camera's yaw so that "towards the camera" is the front pose whatever angle an area
## frames from - which is a feature, and it means an absolute claim like "north-east is column 3"
## is only true for one camera. So the invariants asserted are the ones that hold for every
## camera: the eight directions stay DISTINCT, and one sector of turn advances the facing by
## exactly one. Both are false the moment the sector width or the sign is wrong, and neither
## cares where the camera is.
##
## OWNS: the direction-of-travel to facing and column mapping on `CharacterVisual`.
## MUST NOT: re-assert the layout's own sector maths (art_contract_test), assert what the sprite
##   looks like on screen, or name demo content.

const FACINGS: int = 8
const FRAMES: int = 4
const CELL: Vector2i = Vector2i(32, 48)
## Shorter than `face_direction`'s own guard of 0.0001 on the SQUARED length.
const BELOW_GUARD: float = 0.001

var _visual: CharacterVisual = null


func run() -> void:
	plan(2 * FACINGS + 5)
	_open_a_character()
	_the_eight_directions_are_distinct()
	_one_sector_of_turn_advances_the_facing_by_one()
	_the_enum_and_the_drawn_column_are_set_together()
	_a_direction_below_the_guard_does_not_turn_anything()
	_a_four_facing_sheet_quantises_to_its_own_count()
	_close_the_character()


## Eight directions of travel, eight different poses. An axis swap that collapsed two of them
## would leave a character that looks fine standing still and turns wrongly while walking.
func _the_eight_directions_are_distinct() -> void:
	var seen: Dictionary[int, bool] = {}
	for sector: int in FACINGS:
		seen[int(_visual.facing_from_direction(_direction_for(sector)))] = true
	equal("eight directions of travel give eight distinct facings", seen.size(), FACINGS)


## The relationship that holds for every camera angle: turning by one sector advances the facing
## by exactly one, and the eighth turn wraps back to where it started.
func _one_sector_of_turn_advances_the_facing_by_one() -> void:
	for sector: int in FACINGS:
		var here: int = int(_visual.facing_from_direction(_direction_for(sector)))
		var next: int = int(_visual.facing_from_direction(_direction_for(sector + 1)))
		equal("a sector of turn from %d advances the facing by one" % sector,
			posmod(next - here, FACINGS), 1)


## `_aim` sets the enum and the column together so they cannot drift apart, and on a sheet whose
## facing count matches the enum's they must land on the same number.
func _the_enum_and_the_drawn_column_are_set_together() -> void:
	for sector: int in FACINGS:
		var direction: Vector2 = _direction_for(sector)
		_visual.face_direction(direction)
		equal("facing and drawn column agree at sector %d" % sector,
			int(_visual.facing()), _visual.column_from_direction(direction))


## The guard that stops a character spinning to face a rounding error when it is standing still.
func _a_direction_below_the_guard_does_not_turn_anything() -> void:
	_visual.face_direction(_direction_for(0))
	var settled: int = int(_visual.facing())
	_visual.face_direction(Vector2(BELOW_GUARD, 0.0))
	equal("a direction shorter than the guard does not turn the character",
		int(_visual.facing()), settled)
	equal("and the guard is on the SQUARED length, so this one is genuinely below it",
		BELOW_GUARD * BELOW_GUARD < 0.0001, true)


## THE DELIBERATE DIFFERENCE. The enum always has eight values; a sheet may have four. So the
## facing and the column are NOT the same number on a four-facing sheet, and that is correct:
## a diagonal draws the nearest column the sheet actually has.
func _a_four_facing_sheet_quantises_to_its_own_count() -> void:
	var four := SpriteSheetLayout.new()
	four.facings = 4
	four.frames = FRAMES
	four.cell_size = CELL
	var narrow := CharacterVisual.new()
	narrow.layout = four
	attach(narrow)
	var columns: Dictionary[int, bool] = {}
	for sector: int in FACINGS:
		columns[narrow.column_from_direction(_direction_for(sector))] = true
	equal("a four-facing sheet draws only four columns for eight directions", columns.size(), 4)
	equal("and the eight facings are still eight, because the enum is not the sheet",
		GameEnums.Facing.size(), FACINGS)
	narrow.queue_free()


## Sector 0 is towards the camera. `_screen_angle` is `atan2(x, y)`, so the direction whose
## angle is theta is (sin theta, cos theta) - not (cos, sin), which is the slip this would make.
func _direction_for(sector: int) -> Vector2:
	var angle: float = float(sector) * TAU / float(FACINGS)
	return Vector2(sin(angle), cos(angle))


func _open_a_character() -> void:
	var layout := SpriteSheetLayout.new()
	layout.facings = FACINGS
	layout.frames = FRAMES
	layout.cell_size = CELL
	_visual = CharacterVisual.new()
	# Before attach: `_ready` resolves the layout, and an unset one logs a warning and assumes.
	_visual.layout = layout
	attach(_visual)


func _close_the_character() -> void:
	_visual.queue_free()
	_visual = null
