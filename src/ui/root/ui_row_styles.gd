class_name UiRowStyles
extends Node
## The five states of a pressable row, derived from the palette instead of authored beside it.
##
## WHY THIS FILE EXISTS. `ui_theme.tres` has set `font_sizes` on nine type variations since T2.1
## and has never set a single `Button/styles/*`, so every row in every menu fell through to the
## engine's fallback StyleBox: a near-black bar that is invisible on this project's own dark
## panel and a dark bar on a light one. It was declared as a known limitation in three documents
## and deliberately left for six packages, on the reasoning that a stylebox has to be DESIGNED
## and the only palette to design against was the placeholder one. That reasoning is what this
## file answers: nothing here designs a colour. It designs the RELATIONSHIP between the five
## states, and takes every colour from the palette the theme already declares.
##
## THE FOUR STATES ARE THE PACKAGE, AND `focus` IS THE FIFTH THAT MATTERS MOST. A row set that
## ships `normal` alone is worse than none, because an opaque rest surface makes hover and
## pressed INVISIBLE where the fallback at least changed shade. And `focus` is the one a mouse
## user never sees and a keyboard or gamepad player navigates by - MenuScreen's header says
## controller navigation is free because a VBoxContainer of Buttons already answers ui_up and
## ui_down, and that is true only for as long as the player can tell WHICH row answered.
##
## THE DERIVATION IS DIRECTIONAL, WHICH IS WHAT MAKES IT SURVIVE A LIGHT PALETTE. `hover` is not
## "lighter"; it is `surface` moved toward `text`. On this project's palette that lifts a dark
## row toward white, and on a parchment palette - dark text on a pale ground - the same
## expression DARKENS it. A hard-coded lighten would be right here and wrong there, which is
## exactly the half of the defect that made this a template concern rather than a taste one.
## `pressed` moves toward `accent` instead, because a press is an ACT and wants a hue rather
## than a shade; `disabled` keeps the hue and drops the alpha, so a refused row reads as the
## same row faded rather than as a different one; and `focus` draws no centre at all, only an
## `accent` ring, so it composes with whichever of the other four is underneath instead of
## hiding it.
##
## WHAT IT DOES TO A GAME THAT SHIPPED ITS OWN THEME - the question a MINOR bump has to answer.
## Two refusals, both deliberate and both logged: a variation that already declares
## `styles/normal` is left completely alone, because a game that authored its own rows has
## already made this decision; and a palette with no `surface` entry is left alone entirely,
## because there is nothing to derive from and inventing one would be this file picking a colour
## after all. Deleting the node from `game_root.tscn` is the third way out, and restores exactly
## the behaviour of every version before 4.2.0.
##
## OWNS: the project theme's Button styleboxes and font colours, at runtime.
## MUST NOT: know which screens exist, reach into a Control, or read a setting. It is the
## sibling of UiAccessibility, which owns the same theme's font SIZES for the same reason.

const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const SURFACE: StringName = &"surface"
const TEXT: StringName = &"text"
const ACCENT: StringName = &"accent"
const MUTED: StringName = &"muted"
const ROW_PADDING: StringName = &"row_padding"
const FOCUS_BORDER: StringName = &"focus_border"
const ROW_INSET: StringName = &"tight_separation"

## The type variations that draw a Button. Both are declared in `ui_theme.tres`; a variation
## named here that the theme does not declare is skipped rather than created, because creating
## it would put a style on a role no screen asks for.
const VARIATIONS: Array[StringName] = [&"MenuRow", &"ChoiceRow"]

## The five, in the engine's own spelling. These ARE the Button theme item names, which is why
## nothing here needs a mapping table or an enum.
const NORMAL: StringName = &"normal"
const HOVER: StringName = &"hover"
const PRESSED: StringName = &"pressed"
const DISABLED: StringName = &"disabled"
const FOCUS: StringName = &"focus"

## Every font colour a Button can draw with, less the disabled one, which comes from elsewhere.
const FONT_COLOURS: Array[StringName] = [&"font_color", &"font_hover_color",
		&"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]

## How far each state travels from `surface`, and toward what. Small numbers on purpose: these
## are menu rows in a column, not buttons on a toolbar, and a hover that jumps two shades reads
## as the row having changed rather than as the pointer being over it.
const HOVER_LIFT: float = 0.18
const PRESSED_TINT: float = 0.38
const DISABLED_FADE: float = 0.35


func _ready() -> void:
	apply(ThemeDB.get_project_theme())


## Write the five states of every variation into `theme`. Returns how many variations it wrote,
## so a caller - and the suite - can tell "did nothing because the game authored its own" from
## "did nothing because it never ran", which are the same picture and different bugs.
##
## Static and taking the theme rather than reaching for the project one, because a test that
## styled the shared project theme and left it styled would change every assertion after it.
static func apply(theme: Theme) -> int:
	if theme == null:
		Log.warn("ui", "No project theme - button rows keep the engine's fallback styleboxes")
		return 0
	if not theme.has_color(SURFACE, PALETTE):
		Log.warn("ui", "Palette declares no '%s' - button rows are left unstyled" % SURFACE)
		return 0
	var written: int = 0
	for variation: StringName in VARIATIONS:
		if not theme.is_type_variation(variation, &"Button"):
			continue
		if theme.has_stylebox(NORMAL, variation):
			Log.debug("ui", "'%s' authors its own rows; leaving them alone" % variation)
			continue
		_write(theme, variation)
		written += 1
	Log.debug("ui", "Row styles -> %d variation(s)" % written)
	return written


## The fill for one state, given the three palette colours it is derived from. Public so the
## suite asserts the arithmetic a screen actually gets rather than re-deriving it, and so the
## directional claim - hover moves toward the TEXT colour, whichever way that is - is assertable
## against a palette this repository does not ship.
static func fill(state: StringName, surface: Color, text: Color, accent: Color) -> Color:
	match state:
		HOVER:
			return surface.lerp(text, HOVER_LIFT)
		PRESSED:
			return surface.lerp(accent, PRESSED_TINT)
		DISABLED:
			return Color(surface, surface.a * DISABLED_FADE)
		_:
			return surface


## One state's box. `focus` is the exception, and the reason this returns a whole StyleBoxFlat
## rather than a colour: it draws no centre, so the ring sits over whichever of the other four
## states is beneath it instead of replacing it.
static func box(state: StringName, theme: Theme) -> StyleBoxFlat:
	var surface: Color = theme.get_color(SURFACE, PALETTE)
	var accent: Color = theme.get_color(ACCENT, PALETTE)
	var style := StyleBoxFlat.new()
	style.bg_color = fill(state, surface, theme.get_color(TEXT, PALETTE), accent)
	style.content_margin_left = theme.get_constant(ROW_PADDING, METRICS)
	style.content_margin_right = style.content_margin_left
	style.content_margin_top = theme.get_constant(ROW_INSET, METRICS)
	style.content_margin_bottom = style.content_margin_top
	if state == FOCUS:
		style.draw_center = false
		style.border_color = accent
		style.set_border_width_all(theme.get_constant(FOCUS_BORDER, METRICS))
	return style


## Every state, including the `_mirrored` spellings the engine reaches for under a right-to-left
## locale. They are set to the SAME box rather than a flipped one because these boxes are
## symmetric - but they have to be set, or an RTL game falls straight back to the fallback
## stylebox and inherits the whole defect in the one layout nobody photographs.
static func _write(theme: Theme, variation: StringName) -> void:
	for state: StringName in [NORMAL, HOVER, PRESSED, DISABLED, FOCUS]:
		var style: StyleBoxFlat = box(state, theme)
		theme.set_stylebox(state, variation, style)
		if state != FOCUS:
			theme.set_stylebox(StringName("%s_mirrored" % state), variation, style)
	# hover_pressed is a real sixth state - the mouse held down on a row it is already over -
	# and left unset it is the one way back to the fallback bar from inside a styled menu.
	var held: StyleBoxFlat = box(PRESSED, theme)
	theme.set_stylebox(&"hover_pressed", variation, held)
	theme.set_stylebox(&"hover_pressed_mirrored", variation, held)
	_write_font_colours(theme, variation)


## The font colours, which are half the light-palette defect on their own. Unset, a Button takes
## the fallback theme's near-white `font_color` - legible here, and invisible on a pale ground
## whatever the styleboxes do. `disabled` is the palette's `muted`, which is what that entry was
## added to mean: present, and not yet yours.
static func _write_font_colours(theme: Theme, variation: StringName) -> void:
	var text: Color = theme.get_color(TEXT, PALETTE)
	for name_of: StringName in FONT_COLOURS:
		if not theme.has_color(name_of, variation):
			theme.set_color(name_of, variation, text)
	if not theme.has_color(&"font_disabled_color", variation):
		theme.set_color(&"font_disabled_color", variation, theme.get_color(MUTED, PALETTE))
