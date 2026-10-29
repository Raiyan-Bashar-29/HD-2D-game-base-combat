extends TestCase
## DOES THE SHEET ACTUALLY DRAW A DIFFERENT FIGURE FOR EACH FACING, and this file exists because
## for five phases the answer was no and nothing could tell.
##
## WHAT WENT WRONG, SAID FIRST. `character_placeholder.png` drew ONE POSE EIGHT TIMES. Measured
## over the figure band, facing 4 - the BACK, 180 degrees from the front - differed from facing 0
## by 0.7% of the cell, which was the two eyes and nothing else, and facings 2 and 3 were
## BYTE-IDENTICAL. The four-facing sheet was worse: three of its columns differed only by the
## column tally. The facing CODE was correct throughout - `_aim` quantises the direction
## (`facing_test`), `column_for_angle` derives the sector from the layout (`art_contract_test`) -
## so a system asserted at both ends had been invisible on screen since Phase 1, and the first
## observer was an owner who played the game and said sideways movement "just slides to the side".
##
## THAT IS GOTCHA 54 ONE LEVEL UP. There, two green assertions surrounded an unwired middle; here
## they surround an ASSET with nothing in it to see. The assertion that catches this class cannot
## be about the angle, the column or the frame index - every one of those was already right. It
## has to be about the PIXELS the column addresses, which is what this file reads.
##
## OWNS: that every facing of every shipped character sheet is visibly distinct from every other,
## and that the mirrored half of a sheet is a real mirror.
## MUST NOT: assert the quantisation from a direction to a column (facing_test), the layout's own
## sector maths (art_contract_test), the gait blocks or the pip tallies (character_swap_test), or
## name demo content.

const LAYOUT_PATH: String = "res://assets/placeholder/character_layout.tres"
const SHEET_PATH: String = "res://assets/placeholder/character_placeholder.png"
const ALT_LAYOUT_PATH: String = "res://assets/placeholder/character_alt_layout.tres"
const ALT_SHEET_PATH: String = "res://assets/placeholder/character_alt.png"

## THE FLOOR, AND IT WAS PICKED BY MEASUREMENT RATHER THAN BY TASTE - the same way T5.5 picked the
## prompt outline width. Fraction of differing pixels in one cell, between two facings of the SAME
## block and frame, so the walk cycle is never the thing being measured. The two sheets T5.8
## replaced and the two it ships bracket it from both sides:
##
##     sheet                     worst facing pair   best facing pair
##     default, before T5.8      0.0000 (identical)  0.0347
##     default, shipped          0.0747              0.4627
##     alt, before T5.8          0.0000 (identical)  0.0125
##     alt, shipped              0.2188              0.4813
##
## 0.05 is above anything EITHER old sheet could reach at its most different, and below the worst
## pair on either new one with a third of the margin to spare. A floor set by eye would have
## landed somewhere in the same region and had nothing to say when the next sheet argued with it.
const FLOOR: float = 0.05
## Columns ignored down each edge. The alt sheet's pip tallies sit at x=1 and x=cell-3 and are
## deliberately NOT mirrored - a column tally that flipped with the figure would be uncountable -
## so measuring the whole cell would both credit a sheet for its labels and break the mirror
## check. This measures the FIGURE, which is the thing a player sees.
const MARGIN: int = 4


func run() -> void:
	plan(8)
	_every_facing_of_the_default_sheet_is_a_different_figure()
	_every_facing_of_the_alt_sheet_is_a_different_figure()


func _every_facing_of_the_default_sheet_is_a_different_figure() -> void:
	_assert_sheet("the default sheet", SHEET_PATH, LAYOUT_PATH)


## The four-facing sheet gets the identical treatment, because the defect was identical. A test
## that guarded only the sheet the demo happens to ship would leave the swap sheet - the one a
## consuming game is invited to copy - free to go back to one pose per gait.
func _every_facing_of_the_alt_sheet_is_a_different_figure() -> void:
	_assert_sheet("the alt sheet", ALT_SHEET_PATH, ALT_LAYOUT_PATH)


## Four claims per sheet, and each fails differently.
##
## THE FIRST IS THE ONE THE ROW EXISTS FOR: the LEAST different pair of facings anywhere on the
## sheet still clears the floor. Taking the minimum rather than an average matters - an average
## over 28 pairs stays healthy while one pair is byte-identical, which is exactly the state this
## sheet was in.
##
## THE SECOND NAMES THE HISTORICAL DEFECT. Front against back was 0.007 and was the CLOSEST pair
## on the old sheet rather than the farthest, so it is worth failing under its own name.
##
## THE THIRD IS STRUCTURAL. Half of each sheet is the other half mirrored, so a real mirror is a
## claim that can be checked exactly rather than approximately - and it is the check that refuses
## the cheap way to pass the first one, which is to scatter per-facing noise.
##
## THE FOURTH REFUSES THE OTHER CHEAP WAY. A sheet could clear every facing test by freezing the
## walk cycle and spending the difference on poses, so the cycle has to still move.
func _assert_sheet(what: String, sheet_path: String, layout_path: String) -> void:
	var layout: SpriteSheetLayout = load(layout_path) as SpriteSheetLayout
	var image: Image = (load(sheet_path) as Texture2D).get_image()
	var worst: float = 1.0
	for block: int in layout.animations:
		for frame: int in layout.frames:
			for a: int in layout.facings:
				for b: int in range(a + 1, layout.facings):
					worst = minf(worst, _difference(image, layout, block, frame, a, b))
	equal("%s draws its least alike pair of facings %.1f%% apart, over the %.1f%% floor"
		% [what, worst * 100.0, FLOOR * 100.0], worst > FLOOR, true)
	var opposite: float = _difference(image, layout, layout.walk_row, 0, 0, layout.facings / 2)
	equal("%s draws a back that is %.1f%% unlike its front" % [what, opposite * 100.0],
		opposite > FLOOR, true)
	equal("%s mirrors its turned facings exactly" % what, _mirror_faults(image, layout), [])
	equal("%s still advances its cycle" % what, _still_cycles(image, layout), true)


## Facing `i` and facing `facings - i` are the same pose flipped, which is how the sheet is
## generated and the reason east differs from west by a whole asymmetric figure. Facing 0 and the
## facing opposite it are square on and are their own mirrors, so neither has a partner here.
func _mirror_faults(image: Image, layout: SpriteSheetLayout) -> Array[int]:
	var faults: Array[int] = []
	for i: int in range(1, layout.facings / 2):
		var cell: Vector2i = layout.cell_size
		var mirrored: bool = true
		for y: int in cell.y:
			for x: int in range(MARGIN, cell.x - MARGIN):
				if not _same(_at(image, layout, layout.walk_row, 0, i, Vector2i(x, y)),
						_at(image, layout, layout.walk_row, 0, layout.facings - i,
							Vector2i(cell.x - 1 - x, y))):
					mirrored = false
		if not mirrored:
			faults.append(i)
	return faults


## Every block advances between consecutive frames, on every facing. A single-frame block is not
## a cycle and is legal on some sheet somewhere, but neither of the two here has one.
func _still_cycles(image: Image, layout: SpriteSheetLayout) -> bool:
	for block: int in layout.animations:
		for frame: int in layout.frames:
			for column: int in layout.facings:
				var next: int = (frame + 1) % layout.frames
				if _frame_difference(image, layout, block, frame, next, column) <= 0.0:
					return false
	return true


## Fraction of the figure band that differs between two facings of the same block and frame.
func _difference(image: Image, layout: SpriteSheetLayout, block: int, frame: int,
		a: int, b: int) -> float:
	var differing: int = 0
	for y: int in layout.cell_size.y:
		for x: int in range(MARGIN, layout.cell_size.x - MARGIN):
			if not _same(_at(image, layout, block, frame, a, Vector2i(x, y)),
					_at(image, layout, block, frame, b, Vector2i(x, y))):
				differing += 1
	return float(differing) / float(_band(layout))


## And the same measure taken along the other axis: one facing, two frames of one block.
func _frame_difference(image: Image, layout: SpriteSheetLayout, block: int, frame: int,
		other: int, column: int) -> float:
	var differing: int = 0
	for y: int in layout.cell_size.y:
		for x: int in range(MARGIN, layout.cell_size.x - MARGIN):
			if not _same(_at(image, layout, block, frame, column, Vector2i(x, y)),
					_at(image, layout, block, other, column, Vector2i(x, y))):
				differing += 1
	return float(differing) / float(_band(layout))


func _band(layout: SpriteSheetLayout) -> int:
	return (layout.cell_size.x - MARGIN * 2) * layout.cell_size.y


## One pixel of one cell, addressed the way the sheet is: a column of facing by a row of
## block-then-frame. Deliberately built from `layout` rather than from a literal grid, so a sheet
## of another shape is measured correctly instead of measured off the end.
func _at(image: Image, layout: SpriteSheetLayout, block: int, frame: int, column: int,
		offset: Vector2i) -> Color:
	var row: int = block * layout.frames + frame
	return image.get_pixel(column * layout.cell_size.x + offset.x,
		row * layout.cell_size.y + offset.y)


## DO TWO PIXELS LOOK THE SAME ON SCREEN, which is not the same question as whether their four
## channels agree - and the difference cost this file its first green run.
##
## THE IMPORTED TEXTURE IS NOT THE PNG. `process/fix_alpha_border` is on for every texture in this
## project, and it rewrites the RGB of TRANSPARENT pixels so that filtering never pulls a halo out
## of them. It works on the whole image rather than per cell, so the pip tallies bleed their
## colour into the transparent margin of the cell NEXT DOOR - and a mirror check that compared all
## four channels duly reported the alt sheet's two profiles as not mirrored, over pixels the
## sprite discards before it draws them (`alpha_cut = ALPHA_CUT_DISCARD`). Two transparent pixels
## are the same pixel whatever their RGB says.
func _same(a: Color, b: Color) -> bool:
	if a.a < 0.5 and b.a < 0.5:
		return true
	return a.is_equal_approx(b)
