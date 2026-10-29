extends TestCase
## The five states of a pressable row, and the one claim about them a picture cannot carry.
##
## THE HEADLINE ASSERTION IS _the_derivation_is_directional(). Everything else here is worth
## having, but that one is the reason this row is a template concern: the SAME expression has
## to lighten a row on a dark palette and darken it on a light one, because "invisible against
## the shipped dark palette and immediately wrong against a light one" is one defect with two
## halves and a hard-coded lighten fixes only the first. A light palette is a thing this
## repository does not ship, so nothing but an assertion can stand over it.
##
## EVERY CASE WORKS ON ITS OWN COPY of `ui_theme.tres`, loaded with CACHE_MODE_IGNORE. Styling
## the shared project theme and leaving it styled would change every assertion that runs after
## this file, which is the same trap UiAccessibility.apply() is public to get out of.
##
## OWNS: assertions about how a row's five states are derived, and about the two refusals.
## MUST NOT: assert on a rendered pixel — gotcha 2, and the pictures are in docs/DEVLOG.md —
## or on what any particular screen draws, which is screens_test.gd's job.

const THEME_PATH: String = "res://assets/theme/ui_theme.tres"
const ROOT_SCENE: String = "res://scenes/boot/game_root.tscn"
const STYLES_SCRIPT: String = "res://src/ui/root/ui_row_styles.gd"

## A parchment palette: dark ink on a pale ground, and an accent that is not a shade of it.
## Deliberately not a colour this project ships — the point is that the derivation never saw it.
const LIGHT_TEXT: Color = Color(0.13, 0.11, 0.09, 1)
const LIGHT_ACCENT: Color = Color(0.55, 0.28, 0.12, 1)
const LIGHT_SOLID: Color = Color(0.96, 0.94, 0.88, 1)
const LIGHT_SURFACE: Color = Color(0.89, 0.86, 0.78, 1)


func run() -> void:
	plan(62)
	_the_theme_declares_what_the_derivation_needs()
	_apply_writes_every_state()
	_the_derivation_is_directional()
	_pressed_takes_a_hue_and_disabled_takes_an_alpha()
	_focus_composes_instead_of_replacing()
	_font_colours_are_written_too()
	_a_game_that_authored_its_own_rows_is_left_alone()
	_a_palette_without_a_surface_is_left_alone()
	_the_running_game_instances_it()


## A fresh, unshared copy of the authored theme.
func _theme() -> Theme:
	return ResourceLoader.load(THEME_PATH, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme


## The same copy with its palette replaced and nothing else touched — which is exactly what a
## consuming game does to restyle, and the only edit the light captures in DEVLOG.md made.
func _light_theme() -> Theme:
	var theme: Theme = _theme()
	theme.set_color(UiRowStyles.TEXT, UiRowStyles.PALETTE, LIGHT_TEXT)
	theme.set_color(UiRowStyles.ACCENT, UiRowStyles.PALETTE, LIGHT_ACCENT)
	theme.set_color(&"solid", UiRowStyles.PALETTE, LIGHT_SOLID)
	theme.set_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE, LIGHT_SURFACE)
	return theme


## The authored data the derivation reads. A missing entry here is a silent black row rather
## than an error, so the file is asserted rather than trusted.
func _the_theme_declares_what_the_derivation_needs() -> void:
	var theme: Theme = _theme()
	equal("the theme loads", theme != null, true)
	equal("the palette declares a row surface",
			theme.has_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE), true)
	equal("and it is not the panel it sits on",
			theme.get_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE)
			== theme.get_color(&"solid", UiRowStyles.PALETTE), false)
	equal("and it is not `muted`, which already means something else",
			theme.get_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE)
			== theme.get_color(UiRowStyles.MUTED, UiRowStyles.PALETTE), false)
	equal("the metrics declare a row padding",
			theme.has_constant(UiRowStyles.ROW_PADDING, UiRowStyles.METRICS), true)
	equal("and a focus border a keyboard player can see",
			theme.get_constant(UiRowStyles.FOCUS_BORDER, UiRowStyles.METRICS) > 0, true)
	for variation: StringName in UiRowStyles.VARIATIONS:
		equal("'%s' is a Button variation" % variation,
				theme.is_type_variation(variation, &"Button"), true)
		equal("and the authored file styles none of its states",
				theme.has_stylebox(UiRowStyles.NORMAL, variation), false)


## All five, plus the two spellings that only ever show up somewhere nobody photographs: the
## `_mirrored` boxes an RTL locale reaches for, and `hover_pressed`.
func _apply_writes_every_state() -> void:
	var theme: Theme = _theme()
	equal("apply styles both variations", UiRowStyles.apply(theme), 2)
	for variation: StringName in UiRowStyles.VARIATIONS:
		for state: StringName in [UiRowStyles.NORMAL, UiRowStyles.HOVER, UiRowStyles.PRESSED,
				UiRowStyles.DISABLED, UiRowStyles.FOCUS]:
			equal("'%s' has a '%s' box" % [variation, state],
					theme.has_stylebox(state, variation), true)
		equal("and a mirrored one for a right-to-left layout",
				theme.has_stylebox(&"normal_mirrored", variation), true)
		equal("and one for the mouse held down on a row it is already over",
				theme.has_stylebox(&"hover_pressed", variation), true)
	equal("a second run finds them authored and leaves them", UiRowStyles.apply(theme), 0)


## THE HEADLINE. `hover` is `surface` moved toward `text`, so which way it moves is the
## palette's decision and not this file's. A hard-coded lighten passes the first pair and fails
## the second, which is the plant recorded in DEVLOG.md.
func _the_derivation_is_directional() -> void:
	var dark: Theme = _theme()
	var dark_surface: Color = dark.get_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE)
	var dark_hover: Color = UiRowStyles.fill(UiRowStyles.HOVER, dark_surface,
			dark.get_color(UiRowStyles.TEXT, UiRowStyles.PALETTE),
			dark.get_color(UiRowStyles.ACCENT, UiRowStyles.PALETTE))
	equal("on this project's dark palette, hover LIGHTENS the row",
			dark_hover.get_luminance() > dark_surface.get_luminance(), true)

	var light_hover: Color = UiRowStyles.fill(UiRowStyles.HOVER, LIGHT_SURFACE,
			LIGHT_TEXT, LIGHT_ACCENT)
	equal("on a parchment palette, the same expression DARKENS it",
			light_hover.get_luminance() < LIGHT_SURFACE.get_luminance(), true)
	equal("and it moves about as far either way",
			absf(absf(dark_hover.get_luminance() - dark_surface.get_luminance())
			- absf(light_hover.get_luminance() - LIGHT_SURFACE.get_luminance())) < 0.1, true)

	# And the same claim through the whole path, off the box a Button would actually draw.
	var light: Theme = _light_theme()
	UiRowStyles.apply(light)
	var normal: StyleBoxFlat = light.get_stylebox(UiRowStyles.NORMAL, &"MenuRow") as StyleBoxFlat
	var hover: StyleBoxFlat = light.get_stylebox(UiRowStyles.HOVER, &"MenuRow") as StyleBoxFlat
	equal("the box a light-palette menu draws is darker on hover than at rest",
			hover.bg_color.get_luminance() < normal.bg_color.get_luminance(), true)
	equal("and both are lighter than the ink they carry",
			normal.bg_color.get_luminance() > LIGHT_TEXT.get_luminance(), true)
	equal("and both are darker than the panel behind them",
			normal.bg_color.get_luminance() < LIGHT_SOLID.get_luminance(), true)


## A press is an ACT, so it takes a hue rather than another shade; a refusal is the same row
## faded, so it keeps the hue and drops the alpha.
func _pressed_takes_a_hue_and_disabled_takes_an_alpha() -> void:
	var theme: Theme = _theme()
	var surface: Color = theme.get_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE)
	var text: Color = theme.get_color(UiRowStyles.TEXT, UiRowStyles.PALETTE)
	var accent: Color = theme.get_color(UiRowStyles.ACCENT, UiRowStyles.PALETTE)

	equal("at rest the row is the surface it was given",
			UiRowStyles.fill(UiRowStyles.NORMAL, surface, text, accent), surface)
	var pressed: Color = UiRowStyles.fill(UiRowStyles.PRESSED, surface, text, accent)
	equal("pressed moves toward the accent", pressed.h != surface.h, true)
	equal("and lands nearer the accent's hue than the surface did",
			absf(pressed.h - accent.h) < absf(surface.h - accent.h), true)
	equal("and stays opaque", is_equal_approx(pressed.a, 1.0), true)

	var off: Color = UiRowStyles.fill(UiRowStyles.DISABLED, surface, text, accent)
	equal("disabled keeps the red it had", is_equal_approx(off.r, surface.r), true)
	equal("and the green", is_equal_approx(off.g, surface.g), true)
	equal("and the blue", is_equal_approx(off.b, surface.b), true)
	equal("and gives up only the alpha", off.a < surface.a, true)
	equal("without disappearing altogether", off.a > 0.0, true)


## `focus` is the state a mouse user never sees and a gamepad player navigates by. It draws no
## centre, so it sits OVER whichever of the other four is underneath instead of hiding it — a
## focused row that is also hovered has to look like both.
func _focus_composes_instead_of_replacing() -> void:
	var theme: Theme = _theme()
	UiRowStyles.apply(theme)
	var focus: StyleBoxFlat = theme.get_stylebox(UiRowStyles.FOCUS, &"MenuRow") as StyleBoxFlat
	equal("the focus box draws no centre", focus.draw_center, false)
	equal("it rings the row in the palette's accent",
			focus.border_color, theme.get_color(UiRowStyles.ACCENT, UiRowStyles.PALETTE))
	var width: int = theme.get_constant(UiRowStyles.FOCUS_BORDER, UiRowStyles.METRICS)
	equal("at the width the theme asks for", focus.get_border_width(SIDE_TOP), width)
	equal("on every side, so the ring is closed", focus.get_border_width_min(), width)
	var normal: StyleBoxFlat = theme.get_stylebox(UiRowStyles.NORMAL, &"MenuRow") as StyleBoxFlat
	equal("and the rest state has no border to be confused with it",
			normal.get_border_width_min(), 0)
	equal("both inset their text by the metric", normal.content_margin_left,
			float(theme.get_constant(UiRowStyles.ROW_PADDING, UiRowStyles.METRICS)))
	equal("on the right as well", normal.content_margin_right, normal.content_margin_left)


## Half the light-palette defect on its own: an unset `font_color` takes the fallback theme's
## near-white, which is legible here and invisible on a pale ground whatever the boxes do.
func _font_colours_are_written_too() -> void:
	var theme: Theme = _light_theme()
	UiRowStyles.apply(theme)
	equal("a row's text is the palette's text colour",
			theme.get_color(&"font_color", &"MenuRow"), LIGHT_TEXT)
	equal("and stays it while hovered",
			theme.get_color(&"font_hover_color", &"MenuRow"), LIGHT_TEXT)
	equal("and while pressed",
			theme.get_color(&"font_pressed_color", &"MenuRow"), LIGHT_TEXT)
	equal("a refused row's text is `muted`, which is what that entry means",
			theme.get_color(&"font_disabled_color", &"MenuRow"),
			theme.get_color(UiRowStyles.MUTED, UiRowStyles.PALETTE))
	equal("and a conversation's replies are treated the same",
			theme.get_color(&"font_color", &"ChoiceRow"), LIGHT_TEXT)


## The first refusal. A game that authored its own rows has already made this decision, and a
## MINOR bump that silently replaced it would be a MAJOR one.
func _a_game_that_authored_its_own_rows_is_left_alone() -> void:
	var theme: Theme = _theme()
	var mine := StyleBoxFlat.new()
	mine.bg_color = Color(0.9, 0.1, 0.4, 1)
	theme.set_stylebox(UiRowStyles.NORMAL, &"MenuRow", mine)
	equal("only the variation that authored nothing is styled", UiRowStyles.apply(theme), 1)
	equal("and the game's own box is still the one there",
			theme.get_stylebox(UiRowStyles.NORMAL, &"MenuRow") == mine, true)
	equal("with nothing added around it",
			theme.has_stylebox(UiRowStyles.HOVER, &"MenuRow"), false)
	equal("while the variation that authored nothing did get its states",
			theme.has_stylebox(UiRowStyles.FOCUS, &"ChoiceRow"), true)


## The second refusal, and the one a game upgrading from before 4.2.0 hits. There is nothing to
## derive from, and inventing a surface would be this file picking a colour after all.
func _a_palette_without_a_surface_is_left_alone() -> void:
	var theme: Theme = _theme()
	theme.clear_color(UiRowStyles.SURFACE, UiRowStyles.PALETTE)
	equal("a palette with no row surface is refused", UiRowStyles.apply(theme), 0)
	equal("and nothing is written into it",
			theme.has_stylebox(UiRowStyles.NORMAL, &"MenuRow"), false)
	equal("not even a font colour",
			theme.has_color(&"font_color", &"MenuRow"), false)
	equal("and a theme that is not there at all is refused too",
			UiRowStyles.apply(null), 0)


## Gotcha 56: an `[ext_resource]` line outlives every node that used it, so the wire is read
## through PackedScene.get_state(), where a script is a PROPERTY of a node that either exists
## or does not. Without this the whole file above is true of a class nothing ever runs.
func _the_running_game_instances_it() -> void:
	equal("the running game has a row styler, under UILayer",
			parent_of_script(ROOT_SCENE, STYLES_SCRIPT), "./UILayer")
