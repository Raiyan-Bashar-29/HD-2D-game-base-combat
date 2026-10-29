class_name Readable
extends Interactable
## A sign, notice, book or note. The simplest possible interactable, and the reference
## example for how thin a subclass should be.
##
## OWNS: which text this object shows, and whether it has been read before.
## MUST NOT: know how text is displayed. It asks for a notification by key and the UI layer
## decides what that looks like.

## Localization key for the body text. Never raw text.
@export var text_key: String = ""
## How long the text stays up, in seconds.
@export var display_seconds: float = 5.0

## Field name under this object's PersistentState. Exposed so a quest can ask whether the
## player has actually read a particular notice.
const READ_FIELD: StringName = &"read"


func _ready() -> void:
	verb = GameEnums.InteractVerb.READ
	super()
	if text_key == "":
		Log.warn("interact", "%s is readable but has no text_key" % name)


func perform(_who: Node3D) -> void:
	Events.notify_requested.emit(text_key, display_seconds, {})
	var store: PersistentState = state()
	if store != null:
		store.store(READ_FIELD, true)


## True once the player has read this at least once, across saves. NO CALLER: the write side is
## `perform()` above and the read side belongs to a consuming game, which asks it from a quest
## condition or a dialogue gate — "you have already seen the notice". `Gate.is_open()` is the
## same shape one layer over, and both exist so a game adds no method to a template class.
func has_been_read() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(READ_FIELD)
