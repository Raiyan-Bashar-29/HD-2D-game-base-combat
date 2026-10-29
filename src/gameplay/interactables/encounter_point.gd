class_name EncounterPoint
extends Interactable
## Something in the field that starts a fight when the player interacts with it: a monster you
## can see before you fight it, a challenger, a guard. It asks for the encounter by id and does
## nothing else; whoever hosts battles (C2.7) answers `Events.encounter_requested`.
##
## ONE-SHOT BY DEFAULT IS A GAME'S CALL. Set `one_shot` for a boss, and a `PersistentState` with
## an `object_id` to keep it gone across saves; leave both off for a fight that can be repeated.
##
## OWNS: which encounter it asks for.
## MUST NOT: build the battle, change areas, or know what winning gives.

## The encounter's id, `encounter/<name>`.
@export var encounter_id: StringName = &""


func _ready() -> void:
	verb = GameEnums.InteractVerb.USE
	super()
	if encounter_id == &"":
		Log.warn("interact", "%s is an encounter point with no encounter_id" % name)


func is_offerable() -> bool:
	return super() and encounter_id != &""


func perform(_who: Node3D) -> void:
	Events.encounter_requested.emit(encounter_id)
