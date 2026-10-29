class_name JournalScreen
extends UiScreen
## What the player has been asked to do, as a window. The second screen with real content.
##
## THE SCREEN IS DUMB, ON PURPOSE, and it is the same contract `InventoryScreen` signed. It asks
## `QuestTracker` which quests are active, which are complete and what the current objective of
## each is, and draws a row per answer. It holds no rules: not when a quest starts, not what
## finishes a step, not whether an objective is done. Every one of those has an owner already,
## and a screen that begins answering them is how a UI file becomes the second implementation of
## the game.
##
## IT ALSO DOES NOT PAUSE ANYTHING. It declares `pauses_world` and `UiRoot` does the rest — see
## src/ui/screens/ui_screen.gd for why that split exists at all.
##
## THE TRACKER IS FOUND, NOT INJECTED, AND THAT DIFFERS FROM THE INVENTORY DELIBERATELY.
## `InventoryScreen.for_carrier(who)` exists because there are many bags: an NPC's satchel, a
## stash, the player's. There is exactly ONE quest tracker in a session, the same way there is
## exactly one screen stack, so this uses `QuestTracker.find(self)` — the mechanism `UiRoot.find`
## already established — rather than inventing a second way to hand a singleton around. It
## handles a null tracker by drawing the empty state, because a dev tool or a test may run
## without one.
##
## OWNS: the rows it draws and which one has focus.
## MUST NOT: start, advance or complete a quest, read a flag, or reach for a global tracker
## other than through `find`.

const SCREEN_ID: StringName = &"journal"
const TITLE_KEY: String = "ui.journal.title"
const EMPTY_KEY: String = "ui.journal.empty"
const HINT_KEY: String = "ui.journal.hint"
const ACTIVE_KEY: String = "ui.journal.active"
const COMPLETE_KEY: String = "ui.journal.complete"
const OBJECTIVE_KEY: String = "ui.journal.objective"
## The same line with a tally on the end, for a step that counts something. A FORMAT and
## therefore a key, not a "%s / %s" built here - see docs/CONVENTIONS.md.
const PROGRESS_KEY: String = "ui.journal.progress"
const DONE_KEY: String = "ui.journal.done"
const UNKNOWN_KEY: String = "ui.journal.unknown"

## Theme lookups, named once so a typo cannot become a control that silently draws black. Every
## size, colour and inset comes from `gui/theme/custom` — see assets/theme/ui_theme.tres.
const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const TITLE_VARIATION: StringName = &"TitleText"
const HEADING_VARIATION: StringName = &"NoteText"
const ROW_VARIATION: StringName = &"MenuRow"
const HINT_VARIATION: StringName = &"HintText"
const TEXT_COLOUR: StringName = &"text"
const ACCENT_COLOUR: StringName = &"accent"

var _list: VBoxContainer = null


## Identity is set in _init, NOT in _build. _build runs from _ready, i.e. after a caller has had
## its chance to override a flag, so setting `pauses_world` there would silently discard an
## overlay's request to keep the world running. `StubScreen` did exactly that once and made an
## assertion pass vacuously for a whole package.
func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true


func _build() -> void:
	add_child(_dim_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", get_theme_constant(&"separation", METRICS))
	column.add_child(_label(TITLE_KEY, TITLE_VARIATION, TEXT_COLOUR))
	column.add_child(_scroller())
	column.add_child(_label(HINT_KEY, HINT_VARIATION, ACCENT_COLOUR))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, get_theme_constant(&"margin", METRICS))
	margin.add_child(column)
	add_child(margin)


## Bound to the three quest signals only while the screen is open, on the same reasoning as the
## inventory screen's: a closed screen is about to be freed, and a live connection to a bus that
## outlives it is a dead callable waiting to happen. The world keeps running behind no screen
## that pauses it, but a journal opened during a transition can still see a quest move.
func _opened() -> void:
	for fact: Signal in _facts():
		if not fact.is_connected(_on_quest_changed):
			fact.connect(_on_quest_changed)
	refresh()


func _closed() -> void:
	for fact: Signal in _facts():
		if fact.is_connected(_on_quest_changed):
			fact.disconnect(_on_quest_changed)


## Public so a test can drive it without a frame. Rebuilds every row: a journal of a few dozen
## entries redrawn on a change the player caused is not worth a diffing scheme.
func refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var tracker: QuestTracker = QuestTracker.find(self)
	var active: Array[StringName] = []
	var complete: Array[StringName] = []
	if tracker != null:
		active = tracker.ids_in_state(GameEnums.QuestState.ACTIVE)
		complete = tracker.ids_in_state(GameEnums.QuestState.COMPLETE)
	if active.is_empty() and complete.is_empty():
		_list.add_child(_label(EMPTY_KEY, ROW_VARIATION, TEXT_COLOUR))
		return
	_section(ACTIVE_KEY, active, tracker)
	_section(COMPLETE_KEY, complete, null)
	_focus_first()


## A heading and its quests, or nothing at all when that state is empty — an "Active" heading
## over no rows reads as a bug rather than as an empty list.
##
## A null tracker for the completed section is not a shortcut: a finished quest HAS no current
## objective, so passing one would only invite `current_step` to be asked a question it answers
## null to anyway.
func _section(heading_key: String, ids: Array[StringName], tracker: QuestTracker) -> void:
	if ids.is_empty():
		return
	_list.add_child(_label(heading_key, HEADING_VARIATION, ACCENT_COLOUR))
	for quest_id: StringName in ids:
		var found: Quest = QuestDb.quest(quest_id)
		_list.add_child(_row(quest_id, found))
		_list.add_child(_objective(found, tracker))


## A row is a Button so it can take focus — that is the whole of the keyboard and gamepad
## navigation here, because a VBoxContainer of focusable children already answers ui_up and
## ui_down. Pressing one does nothing yet; a detail pane and a map marker are WP-11 and beyond.
func _row(quest_id: StringName, found: Quest) -> Button:
	var button := Button.new()
	button.theme_type_variation = ROW_VARIATION
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if found == null:
		# A tracked quest whose .tres has gone. The tracker already warned by name; the player
		# still gets a row rather than a hole in the list.
		button.text = tr(UNKNOWN_KEY).format({"id": String(quest_id)})
		return button
	button.text = tr(found.name_key)
	button.tooltip_text = tr(found.summary_key)
	return button


## The objective line under a quest, indented by the theme's own inset so the hierarchy is not a
## number invented here.
##
## A COUNTED STEP GETS ITS TALLY, and the screen does not know what is being counted. It asks the
## tracker for (have, need) and draws it; that the number behind it is items in a bag is a fact
## about the flag the step names, which nothing here reads. `need == 0` is the tracker saying
## "this step is not a count", and the ordinary line is drawn instead - so an authored objective
## never acquires a `0 / 0` it did not ask for.
func _objective(found: Quest, tracker: QuestTracker) -> Label:
	var step: QuestStep = tracker.current_step(found.id) if tracker != null and found != null else null
	var key: String = step.summary_key if step != null else DONE_KEY
	var label: Label = _label(key, ROW_VARIATION, ACCENT_COLOUR)
	var tally: Vector2i = tracker.step_progress(step) if tracker != null else Vector2i.ZERO
	if tally.y > 0:
		label.text = tr(PROGRESS_KEY).format({
			"objective": tr(key), "have": tally.x, "need": tally.y,
		})
		return label
	label.text = tr(OBJECTIVE_KEY).format({"objective": tr(key)})
	return label


func _facts() -> Array[Signal]:
	return [Events.quest_started, Events.quest_advanced, Events.quest_completed]


func _focus_first() -> void:
	for child: Node in _list.get_children():
		var button: Button = child as Button
		if button != null:
			button.grab_focus()
			return


## Both quest_started and quest_completed carry one argument and quest_advanced carries two, so
## the handler takes the second optionally rather than existing three times. Nothing is read from
## either: the screen redraws whole.
func _on_quest_changed(_quest_id: StringName, _step: StringName = &"") -> void:
	refresh()


## Translucent, not opaque: the frozen world stays visible behind the screen, which is how a
## capture shows that opening this stopped the world rather than left it.
func _dim_panel() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = get_theme_color(&"dim", PALETTE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _scroller() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", get_theme_constant(&"tight_separation", METRICS))
	scroll.add_child(_list)
	return scroll


## A label in one of the theme's roles. The variation carries the size, the palette the colour —
## see assets/theme/ui_theme.tres for why those are not the same entry.
func _label(key: String, variation: StringName, colour: StringName) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", get_theme_color(colour, PALETTE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
