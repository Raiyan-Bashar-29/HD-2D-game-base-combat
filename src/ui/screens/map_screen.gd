class_name MapScreen
extends UiScreen
## The world map, and the only place a player asks to fast travel. The third screen with real
## content.
##
## THE SCREEN IS DUMB, ON PURPOSE, and it signs the contract `InventoryScreen` and
## `JournalScreen` signed before it. It asks `AreaDb` where each area sits, asks `WorldMap`
## which ones have been found, and draws a dot per answer. It holds no rules: not what discovers
## a place, not whether travel is allowed, not where a traveller lands. Every one of those has
## an owner already, and a screen that begins answering them is how a UI file becomes the second
## implementation of the game.
##
## IT NAMES NO AREA AND NO POSITION, AND THAT IS THE PACKAGE. Every dot is drawn at the
## `map_position` its own `.tres` declares, in normalised 0..1 space, so this file works on two
## areas, on thirty, and on none. A map that knew where one particular place goes would be
## engine code naming demo content, which `tools/check_boundary.gd` fails the build over.
##
## THREE STATES, DRAWN DIFFERENTLY, and the difference is the point rather than decoration:
## somewhere you are, somewhere you have found, and somewhere you have not. A capture of a map
## whose dots all look alike proves nothing — gotcha 28 — so the colour, the dot size and the
## text all move together, and only a found place that is not this one is a button at all.
##
## PRESSING A ROW DOES NOT CLOSE THIS SCREEN, and that is not an omission. `WorldMap.travel_to`
## emits `Events.area_change_requested`, and `ScreenKeys` unwinds the whole stack on that signal
## — deferred, because tearing down the stack that owns the button mid-emission is a crash
## rather than a bug report. A `request_close()` here would be a second path to the same place.
##
## OWNS: the plate, the markers it draws on it, and which one has focus.
## MUST NOT: discover an area, load one, place the player, read a flag directly, or reach for a
## global map other than through `find`.

const SCREEN_ID: StringName = &"map"
const TITLE_KEY: String = "ui.map.title"
const HINT_KEY: String = "ui.map.hint"
const EMPTY_KEY: String = "ui.map.empty"
const UNKNOWN_KEY: String = "ui.map.unknown"
const HERE_KEY: String = "ui.map.here"

## Theme lookups, named once so a typo cannot become a control that silently draws black. Every
## size, colour and inset comes from `gui/theme/custom` — see assets/theme/ui_theme.tres.
const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const TITLE_VARIATION: StringName = &"TitleText"
const ROW_VARIATION: StringName = &"MenuRow"
const HINT_VARIATION: StringName = &"HintText"
const TEXT_COLOUR: StringName = &"text"
const ACCENT_COLOUR: StringName = &"accent"
## Added to the palette for this screen. An undiscovered place has to be VISIBLE and clearly
## lesser, and `dim` is a translucent black that vanishes against the plate.
const MUTED_COLOUR: StringName = &"muted"
const PLATE_COLOUR: StringName = &"solid"
const UNIT_CONSTANT: StringName = &"tight_separation"

## The dot for a place, and for the place you are standing in, as multiples of the theme's
## tightest inset. Multiples rather than pixel counts so this file holds no dimension of its own
## — the same rule `character_visual.gd` is gated on.
const DOT_UNITS: int = 3
const HERE_UNITS: int = 5
const LABEL_UNITS: int = 3

var _plate: Control = null


## Identity is set in _init, NOT in _build. _build runs from _ready, i.e. after a caller has had
## its chance to override a flag, so setting `pauses_world` there would silently discard an
## overlay's request to keep the world running.
func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true


func _build() -> void:
	add_child(_dim_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", get_theme_constant(&"separation", METRICS))
	column.add_child(_label(TITLE_KEY, TITLE_VARIATION, TEXT_COLOUR))
	column.add_child(_plate_holder())
	column.add_child(_label(HINT_KEY, HINT_VARIATION, ACCENT_COLOUR))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, get_theme_constant(&"margin", METRICS))
	margin.add_child(column)
	add_child(margin)


## Bound to the two facts while the screen is open, and to no gesture. A press is never the only
## writer — a trigger volume, a conversation effect or a save can all put a place on the map
## while this is up — and a UI that redraws only on its own input is silently wrong the moment
## something else writes. That is gotcha 34, and it cost WP-09 a capture.
func _opened() -> void:
	for fact: Signal in _facts():
		if not fact.is_connected(_on_world_changed):
			fact.connect(_on_world_changed)
	refresh()


func _closed() -> void:
	for fact: Signal in _facts():
		if fact.is_connected(_on_world_changed):
			fact.disconnect(_on_world_changed)


## Public so a test can drive it without a frame. Redraws every marker: a map of a few dozen
## places redrawn on a change the player caused is not worth a diffing scheme.
func refresh() -> void:
	if _plate == null:
		return
	for child: Node in _plate.get_children():
		_plate.remove_child(child)
		child.queue_free()
	var ids: Array[StringName] = AreaDb.ids()
	if ids.is_empty():
		_plate.add_child(_empty_notice())
		return
	var known: WorldMap = WorldMap.find(self)
	for area_id: StringName in ids:
		_draw_marker(area_id, AreaDb.area(area_id), known)
	_focus_first()


## A dot and the text beside it. A null `WorldMap` draws everything undiscovered rather than
## failing, because a dev tool or a test may run without one — the same handling the journal
## gives a missing tracker.
func _draw_marker(area_id: StringName, def: AreaDef, known: WorldMap) -> void:
	var found: bool = known != null and known.is_discovered(area_id)
	var here: bool = area_id == Director.current_area_id
	var colour: StringName = MUTED_COLOUR
	if here:
		colour = TEXT_COLOUR
	elif found:
		colour = ACCENT_COLOUR
	var unit: int = get_theme_constant(UNIT_CONSTANT, METRICS)
	_plate.add_child(_dot(def.map_position, unit * (HERE_UNITS if here else DOT_UNITS), colour))
	var text: Control = _marker_text(area_id, def, found, here, colour)
	_pin(text, def.map_position)
	text.offset_left = unit * LABEL_UNITS
	text.offset_top = -unit
	_plate.add_child(text)
	# AFTER add_child, never before: reset_size() asks for the minimum size, which for a Label
	# means measuring text against a font, and a font only resolves once the node is in a tree
	# that can reach `gui/theme/custom`. Called at all because a control pinned between equal
	# anchors has a size of zero, so its text would draw into a rect one pixel wide.
	text.reset_size()


## A found place that is not this one is the only marker that can be pressed. Somewhere you are
## standing is not a destination, and somewhere you have never been is not a secret you can
## select your way into — so both are Labels, and neither takes focus.
func _marker_text(area_id: StringName, def: AreaDef, found: bool, here: bool,
		colour: StringName) -> Control:
	if found and not here:
		var button := Button.new()
		button.theme_type_variation = ROW_VARIATION
		button.text = tr(def.name_key)
		button.pressed.connect(_on_travel_pressed.bind(area_id))
		return button
	var label: Label = _label(UNKNOWN_KEY, ROW_VARIATION, colour)
	if here:
		label.text = tr(HERE_KEY).format({"area": tr(def.name_key)})
	return label


## The marker itself: a square of the plate's own colour scheme, centred exactly on the authored
## point. A ColorRect rather than a texture because art is deferred indefinitely, and a map
## drawn from primitives is a map that never waits for an artist.
func _dot(at: Vector2, extent: int, colour: StringName) -> ColorRect:
	var dot := ColorRect.new()
	dot.color = get_theme_color(colour, PALETTE)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(dot, at)
	var half: float = float(extent) / 2.0
	dot.offset_left = -half
	dot.offset_top = -half
	dot.offset_right = half
	dot.offset_bottom = half
	return dot


## Anchor a control to a normalised point on the plate. All four anchors on the point, so the
## marker keeps its place at every window size and every UI scale and the offsets are a pure
## pixel nudge away from it.
func _pin(control: Control, at: Vector2) -> void:
	control.anchor_left = at.x
	control.anchor_right = at.x
	control.anchor_top = at.y
	control.anchor_bottom = at.y


func _on_travel_pressed(area_id: StringName) -> void:
	var known: WorldMap = WorldMap.find(self)
	if known == null:
		return
	# Nothing else. The stack unwinds itself on `area_change_requested` — see the header.
	known.travel_to(area_id)


func _facts() -> Array[Signal]:
	return [Events.area_discovered, Events.area_entered]


func _on_world_changed(_area_id: StringName) -> void:
	refresh()


func _focus_first() -> void:
	for child: Node in _plate.get_children():
		var button: Button = child as Button
		if button != null:
			button.grab_focus()
			return


## A game with no areas on its map at all, which is the legal starting state of this template
## and not an error. Said rather than left blank, for the same reason the journal says it.
func _empty_notice() -> Label:
	var label: Label = _label(EMPTY_KEY, ROW_VARIATION, TEXT_COLOUR)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## The plate the map is drawn on: an opaque ground, and a transparent layer above it that
## `refresh` owns. Two nodes rather than one so redrawing the markers cannot delete the ground.
func _plate_holder() -> Control:
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ground := ColorRect.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.color = get_theme_color(PLATE_COLOUR, PALETTE)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ground)
	_plate = Control.new()
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_plate)
	return holder


## Translucent, not opaque: the frozen world stays visible around the plate, which is how a
## capture shows that opening this stopped the world rather than left it.
func _dim_panel() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = get_theme_color(&"dim", PALETTE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A label in one of the theme's roles. The variation carries the size, the palette the colour —
## see assets/theme/ui_theme.tres for why those are not the same entry.
func _label(key: String, variation: StringName, colour: StringName) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", get_theme_color(colour, PALETTE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
