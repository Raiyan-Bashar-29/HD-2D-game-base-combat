class_name PerfOverlay
extends CanvasLayer
## Frame time, draw calls and node counts, drawn over everything, while the game keeps running.
##
## WHY THIS IS NOT A UiScreen, AND THE CONSOLE IS
## A screen stops the world — that is what `pauses_world` and `UiRoot`'s pause table are for, and
## the debug console wants exactly that. A performance readout wants the opposite: the numbers
## are worthless unless the thing being measured is still happening. So this never enters the
## screen stack, holds no pause, takes no focus and answers no cancel. It is a `CanvasLayer`
## beside the HUD, at a layer above it, so it stays legible over a menu as well as over the world.
##
## PROCESS_MODE_ALWAYS, for the same reason: a frame is still being drawn behind an open menu,
## and an overlay that froze with the world would report the moment before the pause forever.
##
## THE NUMBERS ARE NOT LOCALIZED. They are a developer readout assembled from `Performance`
## monitors, not prose — see `src/systems/debug/dev_commands.gd` for the same line drawn there.
## Every monitor name here was checked against `--headless --doctool`: TIME_PROCESS,
## RENDER_TOTAL_DRAW_CALLS_IN_FRAME, OBJECT_NODE_COUNT and OBJECT_ORPHAN_NODE_COUNT.
##
## ORPHANS ARE ON THE LINE ON PURPOSE. A node removed from the tree and never freed is this
## project's most common leak — it is what `RID allocations were leaked at exit` is usually
## downstream of — and a number that only moves when something is wrong is the cheapest possible
## alarm.
##
## OWNS: sampling the engine's own counters and drawing them, and its own toggle key.
## MUST NOT: enter the screen stack, pause anything, hold a reference to a system, or exist in a
## shipped build. Deleting this node must not break the game.

## Averaged over this many frames. One frame's process time is noise; half a second of them is a
## reading. Small enough that the number still reacts while you watch it.
const WINDOW_FRAMES: int = 30

const PALETTE: StringName = &"UiPalette"
const VARIATION: StringName = &"HintText"

var _label: Label = null
var _accumulated: float = 0.0
var _samples: int = 0
var _last: String = ""


func _ready() -> void:
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard and same reason as
	# dev_capture.gd and dev_stage.gd: this reads past the game to report on the engine, and the
	# boundary gate's exemption for the debug harness rests on none of it being reachable.
	if not OS.is_debug_build():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 101
	_label = _build_label()
	add_child(_label)
	# The colour AFTER add_child, deliberately: `CanvasLayer` is not a `Control` and has no
	# theme lookup at all, and a Control outside the tree cannot resolve `gui/theme/custom`
	# either. The label asks for its own colour once it is somewhere that can answer.
	_label.add_theme_color_override(&"font_color", _label.get_theme_color(&"accent", PALETTE))
	visible = false
	Log.info("ui", "Performance overlay armed on %s" % Actions.DEBUG_PERF)


## `_label == null` IS THE GATE HERE, NOT A SECOND `OS.is_debug_build()`, and the reason is an
## assertion rather than a preference. A release build leaves `_ready` early, so the label is
## never built and this node has nothing to show — asking "was I armed" is therefore the same
## question and a stricter one. Writing the build check twice would ALSO have meant the gate
## assertion in `tests/unit/dev_tools_test.gd` could not tell the two occurrences apart, so
## deleting the real one in `_ready` would have left it green: gotcha 42, caught by trying to
## plant the violation instead of assuming the assertion worked.
func _input(event: InputEvent) -> void:
	if _label == null:
		return
	if event.is_action_pressed(Actions.DEBUG_PERF):
		toggle()


func _process(delta: float) -> void:
	if _label == null or not visible:
		return
	_accumulated += delta
	_samples += 1
	if _samples < WINDOW_FRAMES:
		return
	_last = sample(_accumulated / float(_samples))
	_label.text = _last
	_accumulated = 0.0
	_samples = 0


## Show or hide, and report which. Public so a probe and the suite can drive it without a key —
## `TestCase.run()` is synchronous and cannot press one.
func toggle() -> bool:
	if _label == null:
		return false
	visible = not visible
	if visible:
		# Draw something at once rather than after the first averaging window, or the overlay
		# appears blank for half a second and reads as broken.
		_last = sample(_frame_seconds())
		_label.text = _last
	Log.info("ui", "Performance overlay %s" % ("shown" if visible else "hidden"))
	return visible


## One line of numbers, from the engine's own counters. Takes the averaged frame time rather
## than reading it, so a caller decides over what window the reading was taken.
func sample(frame_seconds: float) -> String:
	return "%.2f ms/frame  %.0f fps  %.2f ms process  %d draw calls  %d nodes  %d orphans" % [
		frame_seconds * 1000.0,
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	]


## The last line drawn, for an assertion and for a probe reading the overlay back.
func last_line() -> String:
	return _last


## A frame time when no averaging window has closed yet. Derived from the engine's own fps
## rather than from a delta this node has not collected.
func _frame_seconds() -> float:
	var fps: float = Engine.get_frames_per_second()
	return 1.0 / fps if fps > 0.0 else 0.0


func _build_label() -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 32.0
	label.offset_top = 24.0
	label.offset_bottom = 64.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = VARIATION
	return label
