class_name ConstructMechanism
extends PowerMechanism
## A construct (C8.14a): the user raises a wall in front of itself.
##
## IN PLAIN WORDS, IN THE FIELD: a use puts a solid `ArenaThing` of `size` (width, height, depth)
## `distance` metres in front of the user, facing the way it faces. It stops bodies, swings and
## shots, and anyone can break it: it has `hp`. It goes when broken, after `lifetime` seconds (0:
## never by time), when a use goes over `cap` (the oldest goes), when the user falls, the kit
## comes off or the area is left, or when the user cannot pay its upkeep: `upkeep` points a
## second of the user's `upkeep_pool` while any stands (no pool: free). In a battle a use does
## nothing.
##
## OWNS: the shape of a construct.
## MUST NOT: hold running state. `ConstructRun` (gameplay) runs it.

@export var size: Vector3 = Vector3(3.0, 2.0, 0.4)
## Metres in front of the user its middle stands.
@export var distance: float = 1.5
@export var hp: float = 40.0
## Seconds it stands. 0 means until something else takes it down.
@export var lifetime: float = 10.0
## The most standing at once from this power. 0 means no cap.
@export var cap: int = 1
## A pool of the user's that pays `upkeep` points a second while any stands. Empty: free.
@export var upkeep_pool: StringName = &""
@export var upkeep: float = 0.0


func kind() -> StringName:
	return &"construct"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if hp <= 0.0 or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		found.append("%s builds nothing: no hp or no size" % context)
	if lifetime < 0.0 or cap < 0 or upkeep < 0.0:
		found.append("%s has a negative lifetime, cap or upkeep" % context)
	return found
