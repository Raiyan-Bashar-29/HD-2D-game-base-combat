extends Label
## Transient messages: sign text, "the gate grinds open", pickup confirmations.
##
## Anyone may ask for one by emitting `Events.notify_requested` with a localization key. The
## sender does not know this node exists, which is exactly what the bus is for.
##
## OWNS: the queue of pending messages and how long each is shown.
## MUST NOT: know why any message was requested.

## Longest queue before the oldest messages are dropped. A flood of toasts is worse than
## losing some, because the player stops reading them.
const MAX_QUEUE: int = 4

var _queue: Array[Dictionary] = []
var _remaining: float = 0.0


func _ready() -> void:
	# Keeps counting down behind a screen, so a toast raised a moment before a menu opened does
	# not sit frozen half-shown and then reappear later. Pause table: src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offset_top = 40.0
	offset_bottom = 160.0
	offset_left = 160.0
	offset_right = -160.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	visible = false
	Events.notify_requested.connect(_on_notify_requested)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	if _queue.is_empty():
		text = ""
		visible = false
		return
	_show_next()


func _on_notify_requested(key: String, seconds: float, args: Dictionary) -> void:
	if key == "":
		return
	_queue.append({"key": key, "seconds": maxf(0.5, seconds), "args": args})
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()
	if _remaining <= 0.0:
		_show_next()


func _show_next() -> void:
	var entry: Dictionary = _queue.pop_front()
	# format() substitutes {name} placeholders from the args Dictionary. Translators keep the
	# placeholders; the sender supplies the values; this node stays dumb.
	text = tr(DictRead.get_string(entry, "key")).format(DictRead.get_dict(entry, "args"))
	_remaining = DictRead.get_float(entry, "seconds", 3.0)
	visible = true
