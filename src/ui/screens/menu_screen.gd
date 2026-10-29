class_name MenuScreen
extends UiScreen
## A titled column of focusable rows. The shape every menu in this game takes, written once.
##
## WHY A BASE AND NOT FIVE SEPARATE SCREENS
## The main menu, the pause menu, the settings screen, the save screen and the rebinding screen
## differ only in what their rows say and what pressing one does. Everything else - the panel,
## the title, the scroller, the hint line, and the fact that the first row takes focus - is
## identical between them, and five copies of it is five places for the gamepad to stop working
## in exactly one of them.
##
## CONTROLLER NAVIGATION IS FREE, AND THAT IS THE WHOLE TRICK. A VBoxContainer of Buttons
## already answers ui_up and ui_down, and ui_accept already presses the focused one. So no
## screen in this package contains a cursor, a selected index, or a key handler for moving
## between rows. InventoryScreen proved that in WP-03 for one screen; this generalises it, and
## it is why "playable on a gamepad" needed no gamepad code.
##
## OWNS: the panel, the title, the row column, and which row has focus.
## MUST NOT: pause the tree, lock the player, know what a row means, or know what else is on
## the stack. It declares pauses_world like any UiScreen and UiRoot does the rest.

## Theme lookups, named once so a typo is a parse-time missing constant rather than a control
## that silently draws black. Every size, colour and inset this screen uses comes from
## `gui/theme/custom` — see assets/theme/ui_theme.tres. Until T2.1 they were constants here, in
## dialogue_screen.gd, in inventory_screen.gd and in two HUD files, several of them twice over.
const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const TITLE_VARIATION: StringName = &"TitleText"
const ROW_VARIATION: StringName = &"MenuRow"
const NOTE_VARIATION: StringName = &"NoteText"
const HINT_VARIATION: StringName = &"HintText"
const TEXT_COLOUR: StringName = &"text"
const ACCENT_COLOUR: StringName = &"accent"

## How long the curtain takes to fall when a row hands control back to the world. Short: it is
## a menu closing, not a journey. Timing, not look, so it stays here and out of the theme.
const DEPART_FADE: float = 0.25

## What the title says. A localization key, never player-facing text.
var title_key: String = ""
## The line under the column, usually how to leave. Empty means no hint line at all.
var hint_key: String = ""
## Which panel colour to use: the theme's `solid` or `dim`. Opaque for a menu with no world
## behind it, translucent for one over a frozen world that should stay visible.
var opaque: bool = false

## The column the rows live in. Exposed rather than hidden so a test can read what is actually
## on screen instead of what the screen believes it drew.
var rows: VBoxContainer = null


func _build() -> void:
	add_child(_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", get_theme_constant(&"separation", METRICS))
	column.add_child(_line(tr(title_key), TITLE_VARIATION, TEXT_COLOUR))
	column.add_child(_scroller())
	if hint_key != "":
		column.add_child(_line(tr(hint_key), HINT_VARIATION, ACCENT_COLOUR))

	var frame := MarginContainer.new()
	# _and_offsets_ matters: set_anchors_preset alone leaves every offset at zero, giving a
	# full-anchored Control of zero size whose children lay out off the top-left corner.
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		frame.add_theme_constant_override(side, get_theme_constant(&"margin", METRICS))
	for side: StringName in [&"margin_left", &"margin_right"]:
		frame.add_theme_constant_override(side, get_theme_constant(&"side_margin", METRICS))
	frame.add_child(column)
	add_child(frame)
	refresh()


## Rebuild every row, then put focus back on the first one. Public so a test can drive it
## without reaching a frame boundary, and so a screen whose rows depend on state - a slot list,
## a settings value - can redraw itself after changing that state.
func refresh() -> void:
	if rows == null:
		return
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	_fill()
	focus_first()


## Every time this menu reaches the top of the stack, including when a sub-screen over it
## closes. Focus went to that sub-screen's rows and does not come back on its own, so without
## this a player who backs out of Settings is looking at a pause menu with nothing selected and
## a gamepad that does nothing.
func _opened() -> void:
	focus_first()


## Override to add the rows. Called once from _build and again from every refresh().
func _fill() -> void:
	pass


## A pressable row. The Button IS the navigation - see the header - so nothing else in this
## package handles a direction key.
func add_row(text_value: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = ROW_VARIATION
	if on_press.is_valid():
		button.pressed.connect(on_press)
	rows.add_child(button)
	return button


## An unpressable line among the rows: a section heading, or the explanation an empty list
## needs so a player reads it as "nothing here" rather than as a broken screen.
func add_note(text_value: String) -> Label:
	var label: Label = _line(text_value, NOTE_VARIATION, ACCENT_COLOUR)
	rows.add_child(label)
	return label


## The first row that can take it. A menu of nothing but notes leaves focus where it was, which
## is correct: there is nothing on this screen to press.
func focus_first() -> void:
	if rows == null:
		return
	for child: Node in rows.get_children():
		var button: Button = child as Button
		# A row freed by the last refresh is still a child until the frame ends, and a test
		# never reaches a frame boundary.
		if button != null and not button.is_queued_for_deletion():
			button.grab_focus()
			return


## Every row's text, in draw order. For tests and for nothing else.
func row_texts() -> Array[String]:
	var out: Array[String] = []
	if rows == null:
		return out
	for child: Node in rows.get_children():
		if child.is_queued_for_deletion():
			continue
		var button: Button = child as Button
		var label: Label = child as Label
		if button != null:
			out.append(button.text)
		elif label != null:
			out.append(label.text)
	return out


## Drop the curtain, then hand control to the world. Every row that starts, restores or leaves
## a game goes through here, because the alternative - closing the menu and letting the
## transition fade in afterwards - shows a frame or more of an empty, cameraless world between
## the two.
##
## THE STACK UNWINDS ITSELF and no screen ever calls close_all() on the stack it is standing
## on: ScreenKeys closes every screen on area_change_requested. A screen that unwound its own
## stack would be a screen deciding what else is open, which is the one thing UiScreen forbids.
func depart(action: Callable) -> void:
	Events.screen_fade_requested.emit(true, DEPART_FADE)
	# process_always defaults to true, so this timer still fires with the world paused - which
	# it always is here, because every menu that departs is a pausing one.
	await get_tree().create_timer(DEPART_FADE).timeout
	if action.is_valid():
		action.call()


## Open a sub-screen over this one. The stack is found by group, never by path: UiRoot.find is
## the sanctioned way and a hard-coded path breaks the first time the UI tree is rearranged.
## This is not the screen deciding what else is open - it is asking the stack to push one, the
## same call ScreenKeys makes.
func push(screen: UiScreen) -> void:
	var stack: UiRoot = UiRoot.find(self)
	if stack == null:
		Log.error("ui", "No UiRoot in the tree; '%s' cannot be opened" % screen.screen_id)
		screen.free()
		return
	stack.open(screen)


## Hours and minutes, zero-padded. It lives on the base because the pause menu's status line and
## the save screen's slot headers both print it, and a cross-reference between two screens would
## be a CYCLE between two class_name scripts - which is a "could not resolve class" parse error
## that cascades into every subclass, in the same family as `class_name Container`.
static func played_as_text(seconds: float) -> String:
	var whole: int = maxi(0, roundi(seconds))
	return "%02d:%02d" % [whole / 3600, (whole / 60) % 60]


func _panel() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = get_theme_color(&"solid" if opaque else &"dim", PALETTE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _scroller() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A menu never scrolls SIDEWAYS. A row too wide for the column is a row to shorten, not one
	# to make the player drag a bar to read - and the bar itself steals a row's height at the
	# bottom of the list. A capture of the controls screen found both at once.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", get_theme_constant(&"row_separation", METRICS))
	scroll.add_child(rows)
	return scroll


## A label in one of the theme's roles. The VARIATION carries the size and the palette carries
## the colour, because a theme resource has no variables: a colour copied into nine variations
## would be nine places to change, and "one Theme edit restyles every screen" would be false.
func _line(text_value: String, variation: StringName, colour: StringName) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", get_theme_color(colour, PALETTE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
