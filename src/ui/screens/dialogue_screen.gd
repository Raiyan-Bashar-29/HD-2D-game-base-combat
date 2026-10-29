class_name DialogueScreen
extends UiScreen
## The dialogue box. The first screen in this game that does NOT stop the world.
##
## WHY pauses_world IS FALSE, and why that distinction was built two packages early: a
## conversation happens in the world, in real time. The clock keeps running, the weather keeps
## turning, and an NPC three streets away keeps walking. Only the player's own input yields,
## and it yields through the `&"dialogue"` token its components already take on
## `Events.ui_mode_changed` and `Events.dialogue_started`. Nothing here locks anybody.
##
## closes_on_cancel IS ALSO FALSE. Escape must not dismiss a conversation: a conversation has
## effects, and a player who can escape out of the middle of one can skip the effect of the
## node they were about to reach. A conversation ends when it ends.
##
## CANCEL SKIPS INSTEAD, and that is the same rule rather than an exception to it (T6.7). A skip
## walks the runner node by node through `advance()`, so every node on the way is ARRIVED at and
## its effect fires exactly as if the player had read it; it stops at the first node that offers
## a choice, because a branch is the player's to take, and shows that choice whole. A skip that
## meets no choice runs the conversation to its end. Nothing is jumped over, only not read.
##
## AUTO-ADVANCE is `gameplay/dialogue_auto_advance`, off by default so a slow reader is never
## hurried. On, a plain line moves on by itself once it has been revealed and then held for a
## time that grows with its length. It never answers a choice: a node offering one waits.
##
## TEXT SPEED was the first consumer of `gameplay/text_speed`, one of the settings that had been
## declared with nothing reading them; `accessibility/reduce_motion` is the second, and its
## effect is the reveal not happening at all. Reveal is by `visible_ratio`, so a
## half-revealed line is one property rather than a substring, and a translator's line with
## multibyte characters cannot be cut in the middle of one.
##
## OWNS: the box, the reveal, which choice has focus, and when a skip or auto-advance asks to move.
## MUST NOT: decide what comes next, read or write a flag, pause anything, or lock the player.
## `DialogueRunner` owns all of that; this renders `line_changed` and forwards two inputs.

const SCREEN_ID: StringName = &"dialogue"
## "{key} to continue", with the button filled in for whichever device `Actions` last saw. UNTIL
## T6.2 THE HINT SAID "Space to continue" AND SPACE ADVANCED NOTHING: it was bound to `jump`,
## which T5.5 removed, while this screen has only ever listened for `interact` - E, Enter, or the
## pad's south button. A fixed string naming a key is a string that goes stale on the first
## rebind; the binding is the only thing that knows.
const CONTINUE_KEY: String = "ui.dialogue.continue"
## "{key} to skip", beside it and filled in the same way, from the cancel binding.
const SKIP_KEY: String = "ui.dialogue.skip"
## The two joined, and the same with a marker that auto-advance is on. The joining is a key too,
## because where a marker sits in a line is a translator's decision.
const HINT_KEY: String = "ui.dialogue.hint"
const HINT_AUTO_KEY: String = "ui.dialogue.hint_auto"
## The consumer of the setting, named where it is read.
const AUTO_ADVANCE: String = "gameplay/dialogue_auto_advance"
## The reveal is this template's one piece of animated TEXT, so it is where reduce-motion has to
## be honoured. Named on the consumer, beside `gameplay/text_speed`, which this file already read.
const REDUCE_MOTION: String = "accessibility/reduce_motion"

## Tall enough for a speaker, two wrapped lines and four choices at once. Sized from the
## WORST case rather than the common one: the box is anchored to the bottom, so anything that
## does not fit is clipped off the bottom edge of the screen where nobody can scroll to it. A
## capture caught the third of three choices half cut off at 260.
const BOX_HEIGHT: float = 380.0
## Theme lookups, named once so a typo cannot become a control that silently draws black. Every
## size, colour and inset this screen uses comes from `gui/theme/custom` — see
## assets/theme/ui_theme.tres. Until T2.1 they were constants right here, and the same accent
## colour and the same 24pt were also written out in menu_screen.gd and inventory_screen.gd.
const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const SPEAKER_VARIATION: StringName = &"SpeakerText"
const LINE_VARIATION: StringName = &"DialogueText"
const CHOICE_VARIATION: StringName = &"ChoiceRow"
const HINT_VARIATION: StringName = &"HintText"
const TEXT_COLOUR: StringName = &"text"
const ACCENT_COLOUR: StringName = &"accent"
## Characters revealed per second at a text_speed of 1.0. Fast enough to read along with,
## slow enough that the reveal is visible at all.
const CHARS_PER_SECOND: float = 45.0
## Auto-advance holds a revealed line for this long plus its length at a READING pace, which is
## far slower than the reveal: the reveal shows a line, and the hold is for reading it.
const AUTO_HOLD_SECONDS: float = 1.5
const READ_CHARS_PER_SECOND: float = 15.0
## A skip is a loop over authored data, and authored data can cycle: two plain lines naming each
## other would hang the game on one key press. No conversation meant to be read is this long.
const SKIP_LIMIT: int = 512

var runner: DialogueRunner = null

var _speaker: Label = null
var _line: Label = null
var _choice_box: VBoxContainer = null
var _hint: Label = null
var _revealed: float = 0.0
var _length: int = 0
var _held: float = 0.0


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = false
	closes_on_cancel = false


## Built with its runner already attached, so the screen never has to cope with being open and
## unbound. The caller starts the conversation AFTER opening, because `_build` runs from
## `_ready` and the first line has to have somewhere to land.
static func for_conversation() -> DialogueScreen:
	var screen := DialogueScreen.new()
	screen.runner = DialogueRunner.new()
	screen.runner.name = "DialogueRunner"
	return screen


func _build() -> void:
	add_child(runner)
	add_child(_dim_panel())

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", get_theme_constant(&"separation", METRICS))
	_speaker = _label("", SPEAKER_VARIATION, ACCENT_COLOUR)
	_line = _label("", LINE_VARIATION, TEXT_COLOUR)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override(
		&"separation", get_theme_constant(&"tight_separation", METRICS)
	)
	_hint = _label("", HINT_VARIATION, ACCENT_COLOUR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_write_hint()
	column.add_child(_speaker)
	column.add_child(_line)
	column.add_child(_choice_box)
	column.add_child(_hint)

	var frame := MarginContainer.new()
	# Anchored to the BOTTOM, not full-rect: the world above the box has to stay visible,
	# because the world is still running and the player is still standing in it.
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	frame.offset_top = -BOX_HEIGHT
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		frame.add_theme_constant_override(side, get_theme_constant(&"box_margin", METRICS))
	frame.add_child(column)
	add_child(frame)

	runner.line_changed.connect(_on_line_changed)
	runner.finished.connect(_on_finished)
	Events.input_device_changed.connect(_on_device_changed)
	Events.setting_changed.connect(_on_setting_changed)


## The screen is open while the world runs, so a player can put the keyboard down and pick up a
## pad mid-conversation; the hint follows them rather than waiting for the next line.
func _on_device_changed(_device: GameEnums.DeviceKind) -> void:
	_write_hint()


## And turning auto-advance on mid-conversation shows at once, rather than at the next line.
func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if "%s/%s" % [section, key] == AUTO_ADVANCE:
		_write_hint()


func _write_hint() -> void:
	var pad: bool = Actions.device() == GameEnums.DeviceKind.GAMEPAD
	var go: String = tr(CONTINUE_KEY).format({"key": KeyBindings.text_for(Actions.INTERACT, pad)})
	var skip_text: String = tr(SKIP_KEY).format({"key": KeyBindings.text_for(Actions.CANCEL, pad)})
	var joined: String = HINT_AUTO_KEY if Settings.get_bool(AUTO_ADVANCE) else HINT_KEY
	_hint.text = tr(joined).format({"continue": go, "skip": skip_text})


## The reveal. Runs while the world does, because this screen does not pause it.
## Once a line is whole, the same frame clock drives auto-advance.
func _process(delta: float) -> void:
	if _line == null:
		return
	if _revealed >= float(_length):
		_auto_advance(delta)
		return
	_revealed += delta * CHARS_PER_SECOND * _speed()
	_line.visible_ratio = clampf(_revealed / maxf(1.0, float(_length)), 0.0, 1.0)
	if _revealed >= float(_length):
		_show_choices()


func _speed() -> float:
	return maxf(0.1, Settings.get_float("gameplay/text_speed"))


## Counted from the frame the line became whole and reset by every new line, so a line that
## arrived whole under reduce-motion is held exactly as long as one that was typed out.
func _auto_advance(delta: float) -> void:
	if not Settings.get_bool(AUTO_ADVANCE) or runner == null or _waiting_on_choice():
		return
	_held += delta
	if _held >= hold_seconds():
		runner.advance()


## How long auto-advance leaves a whole line up. Slower text means a slower reader, so the text
## speed scales the hold as well as the reveal. Public so the suite can wait exactly this long.
func hold_seconds() -> float:
	return (AUTO_HOLD_SECONDS + float(_length) / READ_CHARS_PER_SECOND) / _speed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.CANCEL):
		get_viewport().set_input_as_handled()
		skip()
		return
	if not event.is_action_pressed(Actions.INTERACT):
		return
	get_viewport().set_input_as_handled()
	# First press completes the reveal, second advances. Skipping the reveal must never also
	# skip the line: a player pressing twice quickly would otherwise miss one entirely.
	if _revealed < float(_length):
		_finish_reveal()
		return
	if runner != null and not _waiting_on_choice():
		runner.advance()


## Skip to the end of the conversation or to the next choice, whichever comes first. Every node
## passed is arrived at through the runner, so its effect fires; see the header. At a choice the
## skip stops and shows it whole, so a second skip there does nothing until it is answered.
func skip() -> void:
	var steps: int = 0
	while runner != null and runner.is_running() and not _waiting_on_choice():
		if steps >= SKIP_LIMIT:
			Log.warn("dialogue", "Skip stopped after %d lines: the conversation cycles" % steps)
			break
		runner.advance()
		steps += 1
	if runner != null and runner.is_running():
		_finish_reveal()


## True while the player owes an answer. Read from the runner rather than from a flag here,
## so there is one truth about whether a branch is open.
func _waiting_on_choice() -> bool:
	return runner != null and not runner.available_choices().is_empty()


func _on_line_changed(node: DialogueNode, choices: Array[DialogueChoice]) -> void:
	_speaker.text = tr(node.speaker_key) if node.speaker_key != "" else ""
	_line.text = tr(node.text_key)
	_length = _line.text.length()
	_revealed = 0.0
	_held = 0.0
	_line.visible_ratio = 0.0
	_clear_choices()
	# Choices are built but hidden until the line finishes revealing, so the answer cannot be
	# picked before the question has been read.
	for choice: DialogueChoice in choices:
		_choice_box.add_child(_choice_button(choice))
	_choice_box.visible = false
	_hint.visible = choices.is_empty()
	# AND THE CONSUMER OF `accessibility/reduce_motion`. A typewriter reveal is animated text,
	# which is precisely what a reduce-motion preference asks to be spared, so the line arrives
	# whole. Done here rather than by zeroing the rate in `_process`, because a rate of zero
	# would leave the choices hidden forever: `_show_choices` fires when the reveal COMPLETES,
	# and a reveal that never advances never completes.
	if Settings.get_bool(REDUCE_MOTION):
		_finish_reveal()


func _show_choices() -> void:
	if _choice_box.get_child_count() == 0:
		return
	_choice_box.visible = true
	var first: Button = _choice_box.get_child(0) as Button
	if first != null:
		first.grab_focus()


func _choice_button(choice: DialogueChoice) -> Button:
	var button := Button.new()
	button.text = tr(choice.text_key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = CHOICE_VARIATION
	# Bound to the CHOICE, not to its index. The world keeps running behind this box, so a flag
	# written between building the button and pressing it can change which options are available
	# and shift every index by one - and the player would take a branch they did not pick.
	button.pressed.connect(_on_choice_pressed.bind(choice))
	return button


func _on_choice_pressed(choice: DialogueChoice) -> void:
	if runner != null:
		runner.take(choice)


func _finish_reveal() -> void:
	_revealed = float(_length)
	_line.visible_ratio = 1.0
	_show_choices()


func _clear_choices() -> void:
	for child: Node in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()


## The runner decides the conversation is over; the screen then asks to be closed. It does NOT
## free itself - the stack owns the lifetime, and this screen may not be the top of it.
func _on_finished(_talk_id: StringName) -> void:
	request_close()


## Belt and braces. A screen closed from outside - an area unloading, a load - must not leave
## the runner believing a conversation is still in progress, because the player's `&"dialogue"`
## token is released by `dialogue_finished` and nothing else would emit it.
func _closed() -> void:
	if runner != null and runner.is_running():
		runner.stop()


func _dim_panel() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rect.offset_top = -BOX_HEIGHT
	rect.color = get_theme_color(&"dim", PALETTE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A label in one of the theme's roles. The variation carries the size, the palette the colour —
## see assets/theme/ui_theme.tres for why those are not the same entry.
func _label(text_value: String, variation: StringName, colour: StringName) -> Label:
	var label := Label.new()
	label.text = text_value
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", get_theme_color(colour, PALETTE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Has the current line finished revealing? Public so a capture can wait for it rather than
## photographing half a sentence, which reads as a truncation bug rather than a feature.
func reveal_complete() -> bool:
	return _revealed >= float(_length)
