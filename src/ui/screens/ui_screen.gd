class_name UiScreen
extends Control
## The contract every screen in this game satisfies. Inventory, journal, map, pause menu and
## the dialogue box are all one of these, and none of them gets to invent its own way of
## stopping the world.
##
## WHAT A SCREEN DECLARES, AND WHAT IT IS NOT ALLOWED TO DO
## A screen states whether it stops the world (`pauses_world`) and whether cancel dismisses it
## (`closes_on_cancel`), and then it renders. It never touches `get_tree().paused`, never locks
## the player, never asks whether another screen is open. UiRoot reads these two flags and does
## all of that once, for every screen, the same way. That is the whole reason this class exists
## and not a pile of Controls: the alternative is a boolean and an ad-hoc pause per screen,
## which is exactly what WP-02 was scheduled to prevent.
##
## OWNS: its own contents, and the two declarations above.
## MUST NOT: pause the tree, lock input, free itself, or know what else is on the stack.
## Ask to be closed by emitting `close_requested`; the stack owns the lifetime.

## Ask the stack to close this screen. A screen never frees itself: it may not be the top of
## the stack, and the stack owns unwinding in order.
signal close_requested()

## Identity, for logs and for a caller asking "is the map already open?". Not player-facing.
@export var screen_id: StringName = &""
## Does opening this stop the world? True for a menu you take your time over; false for a
## conversation, which must keep the weather moving and the clock running.
@export var pauses_world: bool = true
## Does CANCEL dismiss it? A confirmation prompt sets this false so escape cannot dodge the
## question.
@export var closes_on_cancel: bool = true


func _ready() -> void:
	# _and_offsets_ matters. set_anchors_preset alone leaves every offset at zero, which gives
	# a full-anchored Control of zero size whose children lay out off the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A screen eats mouse input, so a click meant for a menu button cannot fall through to
	# whatever is behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Override to construct contents. Called once, from _ready, before the screen is shown.
func _build() -> void:
	pass


## Override for work that must happen each time the screen reaches the top of the stack.
func _opened() -> void:
	pass


## Override for work that must happen when the screen leaves the stack. It is about to be
## freed, so this is the last chance to write anything back.
func _closed() -> void:
	pass


## Called by UiRoot only. Kept separate from _opened so a subclass overriding the hook cannot
## accidentally skip the bookkeeping by forgetting to call super.
func notify_opened() -> void:
	visible = true
	_opened()


func notify_closed() -> void:
	_closed()


## The polite way for a screen's own close button to ask. Everything else goes through UiRoot.
func request_close() -> void:
	close_requested.emit()
