class_name Lever
extends Interactable
## A switch the player throws to change the world. Toggles a persistent boolean and
## announces it; what that boolean *causes* is somebody else's business.
##
## WHY IT DOES NOT KNOW WHAT IT OPENS
## The tempting design is `@export var door_to_open`. That couples every lever to a specific
## consequence, and the second time a lever needs to do two things, or a different lever needs
## to do the same thing, the coupling has to be undone. Instead the lever owns a flag, and
## anything in the world may watch that flag. One lever can gate five things without knowing
## any of them exist.
##
## OWNS: its on/off state and its persistence.
## MUST NOT: know what its state causes.

const STATE_FIELD: StringName = &"thrown"

## Also mirrored into a world flag under this name, so anything can watch it without holding
## a reference to this node. Leave empty to keep the state purely local to the object.
@export var world_flag: StringName = &""
## Localization keys for the toast shown when thrown either way. Optional.
@export var notify_on_key: String = ""
@export var notify_off_key: String = ""

signal toggled(is_on: bool)

## Used only when the object has no PersistentState child, i.e. a lever whose state is
## deliberately not saved.
var _local: bool = false


func _ready() -> void:
	verb = GameEnums.InteractVerb.USE
	super()
	# Publish the starting value so anything watching the flag is correct before the player
	# touches anything, including immediately after a load.
	if world_flag != &"":
		Flags.set_flag(world_flag, is_on())


func perform(_who: Node3D) -> void:
	var next: bool = not is_on()
	var store: PersistentState = state()
	if store != null:
		store.store(STATE_FIELD, next)
	else:
		_local = next

	if world_flag != &"":
		Flags.set_flag(world_flag, next)

	var key: String = notify_on_key if next else notify_off_key
	if key != "":
		Events.notify_requested.emit(key, 2.5, {})

	toggled.emit(next)
	Log.debug("interact", "%s -> %s" % [name, "on" if next else "off"])


func is_on() -> bool:
	var store: PersistentState = state()
	return store.fetch_bool(STATE_FIELD) if store != null else _local
