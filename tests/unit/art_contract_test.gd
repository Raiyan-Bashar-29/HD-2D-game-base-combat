extends TestCase
## The art contract seams (T2.1): the sprite sheet layout, and the project UI theme.
##
## WHAT THIS CASE CANNOT DO, SAID FIRST SO NOBODY MISREADS A GREEN RUN
## It cannot say what the sprite LOOKS like. A character drawn from the wrong cell still looks
## like a character, which is gotcha 2 in the one form headless cannot answer — `--headless`
## shades nothing. So the swap itself is proved by a WINDOWED CAPTURE that was looked at, with
## the pip tallies on the drawn cell quoted in docs/DEVLOG.md, and this file deliberately claims
## no more than it can see.
##
## WHAT IT CAN DO, AND ALL FOUR ARE LOAD-BEARING
## 1. The sector maths, the frame indexing and the layout's own validation are PURE FUNCTIONS of
##    the facing count. They are exactly what belongs in an assertion, and the compatibility
##    assertion — that an 8x4 layout produces the same index the old `_frame * 8 + facing` did —
##    is the one that says this refactor moved the numbers without moving the picture.
## 2. The two committed layouts agree with the two committed sheets, so a regenerated
##    placeholder whose size moved fails here rather than in a capture nobody takes.
## 3. The theme resolves THROUGH THE PROJECT SETTING on a live Control, not merely as a file
##    that parses. An unwired theme is the same failure shape as an unwired @export.
## 4. No screen file holds a font size or a colour of its own any more. This is the regression
##    gate: the look creeping back into the screens one reasonable line at a time is precisely
##    how it came to live in five files in the first place.
##
## OWNS: assertions about the layout resource and the theme contract.
## MUST NOT: assert what a character or a screen looks like, or name demo content.

const LAYOUT_PATH: String = "res://assets/placeholder/character_layout.tres"
const ALT_LAYOUT_PATH: String = "res://assets/placeholder/character_alt_layout.tres"
const SHEET_PATH: String = "res://assets/placeholder/character_placeholder.png"
const ALT_SHEET_PATH: String = "res://assets/placeholder/character_alt.png"
const THEME_SETTING: String = "gui/theme/custom"
const VISUAL_SCRIPT: String = "res://src/gameplay/character/character_visual.gd"

## The files whose look moved into the theme. A NEW SCREEN BELONGS ON THIS LIST, and WP-11 found
## the journal missing from it — added when the map was, because a screen nobody listed is a
## screen the regression gate cannot see, which is the same failure shape as a case nobody added
## to CASES.
const STYLED_SCREENS: Array[String] = [
	"res://src/ui/screens/menu_screen.gd",
	"res://src/ui/screens/dialogue_screen.gd",
	"res://src/ui/screens/inventory_screen.gd",
	"res://src/ui/screens/journal_screen.gd",
	"res://src/ui/screens/map_screen.gd",
	"res://src/ui/hud/hud_clock.gd",
	"res://src/ui/hud/loading_indicator.gd",
]


func run() -> void:
	plan(106)
	_the_sheet_geometry_is_derived_from_the_facing_count()
	_the_frame_index_matches_the_constants_it_replaced()
	_a_layout_reports_its_own_problems()
	_every_move_state_maps_to_a_block()
	_the_committed_layouts_match_the_committed_sheets()
	_the_theme_is_wired_through_the_project_setting()
	_the_theme_carries_every_value_the_screens_ask_for()
	_a_live_control_resolves_the_theme()
	_no_screen_holds_a_size_or_a_colour_of_its_own()


## ONE NUMBER, ONE PLACE. The sector width, the row count and the sheet size all fall out of
## `facings` and `frames`; nothing here may be satisfied by a literal that happens to agree.
func _the_sheet_geometry_is_derived_from_the_facing_count() -> void:
	var eight: SpriteSheetLayout = _layout(8, 4, 1, Vector2i(32, 48))
	var four: SpriteSheetLayout = _layout(4, 3, 2, Vector2i(24, 40))
	equal("8x4x1 is 4 rows", eight.sheet_rows(), 4)
	equal("4x3x2 is 6 rows", four.sheet_rows(), 6)
	equal("8x4x1 is a 256x192 sheet", eight.sheet_size(), Vector2i(256, 192))
	equal("4x3x2 is a 96x240 sheet", four.sheet_size(), Vector2i(96, 240))
	equal("8 facings is a 45 degree sector",
		is_equal_approx(eight.sector_radians(), TAU / 8.0), true)
	equal("4 facings is a 90 degree sector",
		is_equal_approx(four.sector_radians(), TAU / 4.0), true)
	# Eight sectors: every 45 degrees is the next column, and the wrap goes both ways.
	for column: int in 8:
		equal("8 facings: sector %d" % column, eight.column_for_angle(column * TAU / 8.0), column)
	equal("8 facings: a full turn wraps to 0", eight.column_for_angle(TAU), 0)
	equal("8 facings: a backwards sector wraps to 7", eight.column_for_angle(-TAU / 8.0), 7)
	# Four sectors on the SAME angles: the quantisation follows the count and nothing else.
	equal("4 facings: 0 degrees is column 0", four.column_for_angle(0.0), 0)
	equal("4 facings: 90 degrees is column 1", four.column_for_angle(TAU / 4.0), 1)
	equal("4 facings: 180 degrees is column 2", four.column_for_angle(TAU / 2.0), 2)
	equal("4 facings: -90 degrees is column 3", four.column_for_angle(-TAU / 4.0), 3)


## THE COMPATIBILITY ASSERTION. CharacterVisual used to compute `_frame * FACING_COUNT + facing`
## with FACING_COUNT hard-coded to 8. An 8x4x1 layout must produce that exact index, or this
## refactor moved the picture as well as the numbers.
func _the_frame_index_matches_the_constants_it_replaced() -> void:
	var eight: SpriteSheetLayout = _layout(8, 4, 1, Vector2i(32, 48))
	for frame: int in 4:
		var same: bool = true
		for column: int in 8:
			same = same and eight.frame_index(column, frame, 0) == frame * 8 + column
		equal("8x4: row %d indexes as _frame * 8 + facing did" % frame, same, true)
	var four: SpriteSheetLayout = _layout(4, 3, 2, Vector2i(24, 40))
	four.walk_row = 1
	# Block 1 frame 1 is row 4; column 2 in a four-wide sheet makes that index 4*4 + 2.
	equal("4x3x2: walk frame 1, column 2", four.frame_index(2, 1, 1), 18)
	equal("4x3x2: idle frame 0, column 0", four.frame_index(0, 0, 0), 0)
	equal("a frame past the cycle wraps", four.frame_index(0, 3, 0), four.frame_index(0, 0, 0))
	equal("a column past the count wraps", four.frame_index(4, 0, 0), four.frame_index(0, 0, 0))
	equal("standing still plays the idle block",
		four.animation_for(GameEnums.MoveState.IDLE), 0)
	equal("walking plays the walk block",
		four.animation_for(GameEnums.MoveState.WALK), 1)
	four.walk_row = 9
	equal("a block past the end clamps to the last",
		four.animation_for(GameEnums.MoveState.WALK), 1)


func _a_layout_reports_its_own_problems() -> void:
	var good: SpriteSheetLayout = _layout(4, 3, 2, Vector2i(24, 40))
	equal("a valid layout has no problems", good.problems().size(), 0)
	var flat: SpriteSheetLayout = _layout(4, 3, 1, Vector2i(24, 0))
	equal("a cell with no area is a problem", flat.problems().size(), 1)
	var past: SpriteSheetLayout = _layout(4, 3, 1, Vector2i(24, 40))
	past.walk_row = 2
	equal("a row past the animations is a problem", past.problems().size(), 1)
	var sheet: Texture2D = load(SHEET_PATH) as Texture2D
	equal("the 8x4 sheet loads", sheet != null, true)
	equal("a mismatched texture is a problem", good.problems(sheet).size(), 1)


## The layouts and the sheets are committed together, so a regenerated placeholder whose size
## moved fails HERE rather than in a capture nobody thought to take.
func _the_committed_layouts_match_the_committed_sheets() -> void:
	var main: SpriteSheetLayout = load(LAYOUT_PATH) as SpriteSheetLayout
	var alt: SpriteSheetLayout = load(ALT_LAYOUT_PATH) as SpriteSheetLayout
	equal("the default layout loads", main != null, true)
	equal("the alt layout loads", alt != null, true)
	equal("the default layout is 8 facings", main.facings, 8)
	equal("the default layout is 4 frames", main.frames, 4)
	equal("the alt layout is 4 facings", alt.facings, 4)
	equal("the alt layout is 3 frames in 5 blocks", [alt.frames, alt.animations], [3, 5])
	equal("the alt layout has a separate walk block", alt.walk_row != alt.idle_row, true)
	# The swap has to BE a swap: two layouts agreeing on the numbers would prove nothing.
	equal("the two layouts disagree on the cell", main.cell_size != alt.cell_size, true)
	equal("the two layouts disagree on the frame count", main.frames != alt.frames, true)
	equal("the default layout fits its sheet",
		main.problems(load(SHEET_PATH) as Texture2D).size(), 0)
	equal("the alt layout fits its sheet",
		alt.problems(load(ALT_SHEET_PATH) as Texture2D).size(), 0)


## Wired, not merely present. An unwired theme is the same failure shape as an unwired @export:
## the screens fall back to Godot's default look and every rung stays green.
func _the_theme_is_wired_through_the_project_setting() -> void:
	var path: String = str(ProjectSettings.get_setting(THEME_SETTING, ""))
	equal("the project names a custom theme", path.begins_with("res://"), true)
	equal("the project theme loads", load(path) is Theme, true)


func _the_theme_carries_every_value_the_screens_ask_for() -> void:
	var theme: Theme = _project_theme()
	for pair: Array in [
		["TitleText", "Label"], ["NoteText", "Label"], ["HintText", "Label"],
		["SpeakerText", "Label"], ["DialogueText", "Label"], ["HudText", "Label"],
		["LoadingText", "Label"], ["MenuRow", "Button"], ["ChoiceRow", "Button"],
	]:
		var variation := StringName(str(pair[0]))
		equal("%s is a variation carrying a size" % variation,
			[theme.get_type_variation_base(variation),
				theme.has_font_size(&"font_size", variation)],
			[StringName(str(pair[1])), true])
	for colour: StringName in [&"text", &"accent", &"dim", &"solid"]:
		equal("the palette has %s" % colour, theme.has_color(colour, &"UiPalette"), true)
	for metric: StringName in [
		&"margin", &"side_margin", &"box_margin", &"separation", &"row_separation",
		&"tight_separation",
	]:
		equal("the metrics have %s" % metric, theme.has_constant(metric, &"UiMetrics"), true)


## The lookup path a screen actually uses, on a Control that is actually in the tree. A theme
## item that exists in the file and does not resolve from a node is not wired.
func _a_live_control_resolves_the_theme() -> void:
	var theme: Theme = _project_theme()
	var probe := Label.new()
	attach(probe)
	equal("a metric resolves from a live Control",
		probe.get_theme_constant(&"margin", &"UiMetrics"),
		theme.get_constant(&"margin", &"UiMetrics"))
	equal("a palette colour resolves from a live Control",
		probe.get_theme_color(&"accent", &"UiPalette"),
		theme.get_color(&"accent", &"UiPalette"))
	probe.theme_type_variation = &"TitleText"
	equal("a variation resolves the theme's size, not Godot's default",
		probe.get_theme_font_size(&"font_size"),
		theme.get_font_size(&"font_size", &"TitleText"))
	probe.queue_free()


## THE REGRESSION GATE. The look got into five files one reasonable line at a time, and nothing
## but a check stops it going back. A screen may still use a size it is HANDED; what it may not
## do is write a literal one down.
func _no_screen_holds_a_size_or_a_colour_of_its_own() -> void:
	for path: String in STYLED_SCREENS:
		equal("%s writes down no colour" % path.get_file(), _code_matches(path, "Color("), 0)
		equal("%s writes down no font size" % path.get_file(),
			_code_matches(path, "add_theme_font_size_override("), 0)
	# `TAU / float(count)` is fine and is the point; `TAU / 8` beside a separate `8` is the bug.
	equal("character_visual.gd holds no literal sector width",
		_code_matches(VISUAL_SCRIPT, "TAU / 8"), 0)
	equal("character_visual.gd holds no sheet dimension of its own",
		_code_matches(VISUAL_SCRIPT, "FACING_COUNT"), 0)


## Lines of CODE containing `needle`. Comments are exempt, on the same reasoning as
## tools/check_boundary.gd: a `##` line naming what the theme replaced teaches by example and
## changes nothing, while a literal in code changes what is drawn.
func _code_matches(path: String, needle: String) -> int:
	var hits: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = line.strip_edges()
		if not code.begins_with("#") and code.contains(needle):
			hits += 1
	return hits


func _project_theme() -> Theme:
	return load(str(ProjectSettings.get_setting(THEME_SETTING, ""))) as Theme




## EVERY MOVE STATE MAPS TO A BLOCK, AND AN UNSET GAIT INHERITS THE WALK ONE. This is the whole
## of T5.2's seam: `animation_for` took a BOOLEAN until then, so a sheet could hold an idle cycle
## and a walk cycle and nothing else, and run and sneak replayed the walk block faster.
##
## THE FALLBACK IS ASSERTED BEFORE THE FEATURE, deliberately. A sheet authored before this existed
## sets none of the three new rows, and the thing that must not break is that it keeps drawing
## exactly what it drew - so the first assertions here are that a two-block sheet answers WALK for
## run, sneak and climb, and only then that naming a row overrides it.
func _every_move_state_maps_to_a_block() -> void:
	var sheet: SpriteSheetLayout = _layout(8, 4, 4, Vector2i(32, 48))
	sheet.idle_row = 0
	sheet.walk_row = 1

	equal("idle draws the idle block", sheet.animation_for(GameEnums.MoveState.IDLE), 0)
	equal("walk draws the walk block", sheet.animation_for(GameEnums.MoveState.WALK), 1)
	# The compatibility half: three gaits, no rows named, all of them the walk block.
	for gait: GameEnums.MoveState in [
		GameEnums.MoveState.RUN, GameEnums.MoveState.SNEAK, GameEnums.MoveState.CLIMB,
	]:
		equal("gait %d with no row of its own inherits the walk block" % int(gait),
			sheet.animation_for(gait), 1)
	# A state this template has no gait for at all falls to idle rather than to the walk block: a
	# character held by a dialogue box is standing there, not walking on the spot.
	for held: GameEnums.MoveState in [
		GameEnums.MoveState.JUMP, GameEnums.MoveState.FALL, GameEnums.MoveState.SWIM,
		GameEnums.MoveState.BUSY, GameEnums.MoveState.LOCKED,
	]:
		equal("state %d with no gait falls to idle" % int(held),
			sheet.animation_for(held), 0)
	equal("a two-block sheet draws two distinct gaits", sheet.distinct_gaits(), 2)

	# And the feature half: naming a row overrides the inheritance, one gait at a time.
	sheet.run_row = 2
	equal("naming a run row draws it", sheet.animation_for(GameEnums.MoveState.RUN), 2)
	equal("and does not disturb the walk block",
		sheet.animation_for(GameEnums.MoveState.WALK), 1)
	sheet.sneak_row = 3
	equal("naming a sneak row draws it", sheet.animation_for(GameEnums.MoveState.SNEAK), 3)
	equal("climb still inherits, because it was not named",
		sheet.animation_for(GameEnums.MoveState.CLIMB), 1)
	equal("four named blocks are four distinct gaits", sheet.distinct_gaits(), 4)

	# A row past the end clamps rather than indexing off the sheet, and says so.
	sheet.run_row = 9
	equal("a gait row past the end clamps to the last block",
		sheet.animation_for(GameEnums.MoveState.RUN), 3)
	equal("and it is a reported problem, not a silent clamp",
		_problem_names(sheet.problems(), "run_row"), true)
	sheet.run_row = -1
	equal("and -1 is not a problem, because it MEANS inherit",
		sheet.problems().size(), 0)


## Whether any problem line names a given field. The message is prose, so this asks the question
## the assertion actually cares about rather than comparing a whole sentence.
func _problem_names(problems: PackedStringArray, field: String) -> bool:
	for line: String in problems:
		if line.contains(field):
			return true
	return false

func _layout(facings: int, frames: int, animations: int, cell: Vector2i) -> SpriteSheetLayout:
	var made := SpriteSheetLayout.new()
	made.facings = facings
	made.frames = frames
	made.animations = animations
	made.cell_size = cell
	return made


