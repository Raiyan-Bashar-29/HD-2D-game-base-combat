extends TestCase
## THE WHOLESALE CHARACTER SWAP, asserted where it can be: on the swap sheet itself.
##
## WHAT THIS CASE IS FOR. Phase T5 claims a future game inherits working characters and changes
## only assets. The template ships two sheets so that claim can be PERFORMED rather than
## described, and until T5.6 the second one had a different grid and no gaits - so the swap
## demonstrated that the cell size moves and said nothing about whether the movement styles do.
## This file guards the sheet that makes the demonstration whole.
##
## WHAT IT CANNOT DO, SAID FIRST. It cannot say the swap WORKED. `--headless` shades nothing
## (gotcha 2) and a sprite drawn from the wrong cell is still a person (gotcha 28), so the swap
## itself is a windowed capture with the decoded block quoted beside it in docs/DEVLOG.md. What
## this file guards is that the capture remains READABLE and that the sheet keeps its promises.
##
## OWNS: the alt sheet's gait set, its tints, its silhouettes and its three pip tallies.
## MUST NOT: assert the layout's own block mapping (art_contract_test), whether a MoveState
## reaches the sprite (gaits_test), or name demo content.

const LAYOUT_PATH: String = "res://assets/placeholder/character_layout.tres"
const ALT_LAYOUT_PATH: String = "res://assets/placeholder/character_alt_layout.tres"
const ALT_SHEET_PATH: String = "res://assets/placeholder/character_alt.png"
## Which block is which on the alt sheet, for the two assertions that compare one against
## another. Named rather than numbered at the call site, because "3 > 1" is not an argument.
const WALK_BLOCK: int = 1
const SNEAK_BLOCK: int = 3


func run() -> void:
	plan(14)
	_the_alt_sheet_carries_a_full_gait_set()


## THE GAIT SET ON THE SWAP SHEET, READ OFF THE PNG rather than off the .tres. The layout is
## what the game BELIEVES; the pixels are what a player sees, and nothing made the two agree:
## `problems()` checks the sheet's SIZE and nothing checks its CONTENT, so a layout naming five
## blocks over a sheet drawing two would have passed every rung. That is the shape of gotcha 54
## again - both ends declared, the middle unasserted - and it is worth a gate here because the
## alt sheet exists for no reason except to be swapped in and photographed.
##
## AND IT ASSERTS THAT THE CAPTURE IS READABLE, which is the other half. A gait capture is only
## evidence if the block can be COUNTED off the image (gotcha 28), so the pip tallies are part
## of the contract rather than decoration: if the right-edge tally stops matching the block, the
## photographs in DEVLOG.md quietly stop meaning anything.
func _the_alt_sheet_carries_a_full_gait_set() -> void:
	var alt: SpriteSheetLayout = load(ALT_LAYOUT_PATH) as SpriteSheetLayout
	var main: SpriteSheetLayout = load(LAYOUT_PATH) as SpriteSheetLayout
	equal("the alt layout names a row for every gait",
		[alt.run_row, alt.sneak_row, alt.climb_row], [2, 3, 4])
	equal("so no alt gait falls back to the walk block", alt.distinct_gaits(), 5)
	equal("and the two layouts disagree on the block count too",
		main.animations != alt.animations, true)
	var image: Image = (load(ALT_SHEET_PATH) as Texture2D).get_image()
	var tints: Array[Color] = []
	for block: int in alt.animations:
		var tint: Color = image.get_pixelv(_alt_at(alt, block, 0, Vector2i(12, 20)))
		if not _seen(tints, tint):
			tints.append(tint)
		equal("block %d wears %d pips down its right edge" % [block, block + 1],
			_alt_tally(image, alt, block, 0, true), block + 1)
	equal("every block on the alt sheet is drawn in a tint of its own", tints.size(), 5)
	# Silhouette, not only colour: a sneak that merely wore a different shirt would photograph
	# as a walk, and a tint is judged where a height is measured.
	equal("the sneak block draws a lower figure than the walk block",
		_alt_top(image, alt, SNEAK_BLOCK) > _alt_top(image, alt, WALK_BLOCK), true)
	for frame: int in alt.frames:
		equal("frame %d wears %d pips along its foot" % [frame, frame + 1],
			_alt_tally(image, alt, 0, frame, false), frame + 1)
	equal("and no cell bleeds into the one below it", _alt_bleeds(image, alt), [])


## A point inside one alt cell, in sheet pixels. Column 0 throughout: the column tally is
## `facing_test`'s subject and this case is about blocks.
func _alt_at(layout: SpriteSheetLayout, block: int, frame: int, offset: Vector2i) -> Vector2i:
	return Vector2i(0, (block * layout.frames + frame) * layout.cell_size.y) + offset


## How many pips are lit on one edge of a cell. A pip is the only thing on this sheet that is
## bright in both red and green, so this counts pips without knowing either tally's colour -
## which is what lets the same helper read the white block tally and the yellow frame one.
func _alt_tally(image: Image, layout: SpriteSheetLayout, block: int, frame: int,
		right: bool) -> int:
	var lit: int = 0
	for pip: int in 8:
		var offset: Vector2i = Vector2i(layout.cell_size.x - 3, 2 + pip * 4) if right \
			else Vector2i(2 + pip * 4, layout.cell_size.y - 7)
		if offset.x >= layout.cell_size.x or offset.y >= layout.cell_size.y:
			break
		var found: Color = image.get_pixelv(_alt_at(layout, block, frame, offset))
		if found.a > 0.5 and found.r > 0.9 and found.g > 0.9:
			lit += 1
	return lit


## The topmost drawn row of the FIGURE, ignoring the tally columns down either edge.
func _alt_top(image: Image, layout: SpriteSheetLayout, block: int) -> int:
	for y: int in layout.cell_size.y:
		for x: int in range(6, layout.cell_size.x - 5):
			if image.get_pixelv(_alt_at(layout, block, 0, Vector2i(x, y))).a > 0.5:
				return y
	return layout.cell_size.y


func _seen(colours: Array[Color], candidate: Color) -> bool:
	for known: Color in colours:
		if absf(known.r - candidate.r) + absf(known.g - candidate.g) \
				+ absf(known.b - candidate.b) < 0.02:
			return true
	return false


## EVERY CELL THAT SPILLS INTO ITS NEIGHBOUR, and this one was written because it caught a live
## defect on its first run. `_plot` in the generator clips to the IMAGE, so a stride that
## overreaches its cell simply draws into the cell below - and a sheet with a stray boot
## floating above every character's head is still a picture of a person, which is precisely the
## judgement gotcha 28 says a capture cannot be trusted to make. The top row of a cell is the
## only row nothing legitimately occupies: the tallies start at y=2 and the hair at y=3.
func _alt_bleeds(image: Image, layout: SpriteSheetLayout) -> Array[int]:
	var rows: Array[int] = []
	for row: int in layout.sheet_rows():
		for x: int in range(3, layout.cell_size.x - 3):
			if image.get_pixel(x, row * layout.cell_size.y).a > 0.5:
				rows.append(row)
				break
	return rows
