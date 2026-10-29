class_name DebugConsoleScreen
extends UiScreen
## The in-game debug console: a line to type in, and the last few answers above it.
##
## WHY THIS IS UNDER src/ui/ AND NOT IN THE EXEMPT DEBUG DIRECTORY
## `src/systems/debug/` is exempt from the engine/demo boundary gate, and the exemption is
## justified only because those files exist to drive the DEMO — `--give=item/rose_key` stages a
## photograph. This screen names no content at all: a command takes its argument from whoever
## typed it, so `goto courtyard` is INPUT, not a literal. Putting it here is therefore not merely
## allowed, it is better, because `tools/check_boundary.gd` then polices the console the way it
## polices every other screen instead of waving it through. Everything that WOULD want a
## hard-coded id lives on the other side of `DevCommands`, which is in the exempt directory.
##
## IT IS A UiScreen AND IT PAUSES THE WORLD, which is not this file's decision to make twice: it
## declares `pauses_world` and `UiRoot`'s pause table does the rest. A console that stopped the
## tree itself would be the second pause mechanism ADR-0004 exists to prevent, and it needs the
## world stopped anyway — typing `time 18:40` while the clock runs photographs a moving target.
## The performance overlay is the opposite case and deliberately NOT a screen: it has to be
## readable DURING gameplay, so it is a `CanvasLayer` beside the HUD. See src/ui/hud/perf_overlay.gd.
##
## CHROME IS TEXT, OUTPUT IS DATA. The title and the hint are localization keys, like every other
## screen's; the lines this screen prints are echoes of a typed command and the values that came
## back, which no `strings.csv` could hold and no player will ever read. That split is stated in
## `DevCommands`' header too, because it is the reason its reports are plain English.
##
## OWNS: the input line, the transcript above it, and how many lines are kept.
## MUST NOT: implement a command, decide whether the debug surface is reachable, pause the tree,
## or name any content. The verbs live in DevCommands and the gate lives at the binding.

const SCREEN_ID: StringName = &"console"
const TITLE_KEY: String = "ui.debug.console.title"
const HINT_KEY: String = "ui.debug.console.hint"

## How many answers stay on screen. Enough to read the last four commands back, few enough that
## the transcript never grows past the panel — there is no scroll here on purpose, because a
## console that needs scrolling wants history and autocomplete, which WP-14b defers.
const KEPT_LINES: int = 12

const PALETTE: StringName = &"UiPalette"
const METRICS: StringName = &"UiMetrics"
const TITLE_VARIATION: StringName = &"NoteText"
const OUTPUT_VARIATION: StringName = &"HintText"
const TEXT_COLOUR: StringName = &"text"
const ACCENT_COLOUR: StringName = &"accent"

var _output: Label = null
var _entry: LineEdit = null
var _lines: PackedStringArray = []


## Identity in _init, never in _build: _build runs from _ready, which is after a caller's chance
## to override a flag. See journal_screen.gd for the assertion that made this a rule.
func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true


func _build() -> void:
	add_child(_dim_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", get_theme_constant(&"separation", METRICS))
	column.add_child(_label(tr(TITLE_KEY), TITLE_VARIATION, TEXT_COLOUR))
	_output = _label(DevCommands.usage(), OUTPUT_VARIATION, ACCENT_COLOUR)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(_output)
	column.add_child(_entry_line())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, get_theme_constant(&"box_margin", METRICS))
	margin.add_child(column)
	add_child(margin)


## `edit()` as well as `grab_focus()`: since 4.3 a LineEdit distinguishes having focus from being
## in edit mode, and a focused line that is not editing swallows the first keystroke. Verified by
## the windowed probe quoted in DEVLOG.md, which is the only thing that can press a key at all.
func _opened() -> void:
	if _entry == null:
		return
	_entry.grab_focus()
	_entry.edit()


## Run one line and show the answer. Public and synchronous so the suite can drive the console
## without an input event — TestCase.run() cannot press enter, and this is the seam it uses.
func submit(line: String) -> String:
	var typed: String = line.strip_edges()
	if typed == "":
		return ""
	var answer: String = DevCommands.run(typed)
	_lines.append("> %s" % typed)
	_lines.append(answer)
	while _lines.size() > KEPT_LINES:
		_lines.remove_at(0)
	# Joined into a local first, and not because it reads better: `check_strings.gd` anchors on
	# the right-hand side of a `.text =` assignment, where a separator literal is
	# indistinguishable to a text scan from a sentence meant for a player. The tool is right to
	# refuse it, and the transcript is data that belongs in a variable anyway.
	var joined: String = "\n".join(_lines)
	if _output != null:
		_output.text = joined
	return answer


## The transcript, for an assertion and for a probe. Not the Label's own text, which may not
## exist yet if the screen has never been added to a tree.
func transcript() -> PackedStringArray:
	return _lines


func _on_text_submitted(typed: String) -> void:
	submit(typed)
	if _entry == null:
		return
	_entry.clear()
	_entry.edit()


func _entry_line() -> LineEdit:
	_entry = LineEdit.new()
	_entry.placeholder_text = tr(HINT_KEY)
	_entry.add_theme_color_override(&"font_color", get_theme_color(TEXT_COLOUR, PALETTE))
	_entry.text_submitted.connect(_on_text_submitted)
	return _entry


## Translucent, so the stopped world stays visible behind the console — which is how a capture
## shows that opening it stopped the world rather than left it running.
func _dim_panel() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = get_theme_color(&"dim", PALETTE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Takes the STRING, not the key: half of what this screen draws is a typed command and its
## answer, which has no key. The chrome passes tr() in at the call site.
func _label(content: String, variation: StringName, colour: StringName) -> Label:
	var label := Label.new()
	label.text = content
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", get_theme_color(colour, PALETTE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
