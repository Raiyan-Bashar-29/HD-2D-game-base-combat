class_name CloneMechanism
extends PowerMechanism
## M10, a clone (C6.13a): a double who repeats the user's moves. See `docs/POWERS.md` § M10.
##
## IN PLAIN WORDS, IN THE FIELD: using the power puts a ghost where the user stands. It walks
## where the user walked `delay` seconds ago and plays each move the user starts (not the dodge)
## `delay` seconds later, with its own hitbox, at `power_fraction` of the move's power. It lasts
## `lifetime` seconds; a second use replaces it. It cannot be hit. It goes when the user falls,
## the kit comes off or the area is left. `tint` colours a copy of the user's sprite.
## IN A BATTLE (C6.13b): for the user's next `actions` turns, every hurt the user deals is dealt
## again to the same fighter at `power_fraction` of it (the double strikes too).
##
## OWNS: the shape of a clone.
## MUST NOT: hold running state. `CloneRun` (gameplay) runs it.

## Seconds the ghost runs behind the user.
@export var delay: float = 0.5
## Seconds the ghost lasts.
@export var lifetime: float = 8.0
## The share of each move's power the ghost's copy has.
@export var power_fraction: float = 1.0
## The colour over the ghost's copy of the user's sprite.
@export var tint: Color = Color(0.6, 0.7, 1.0, 0.5)
## In a battle, how many of the user's turns after the use are doubled.
@export var actions: int = 2


func kind() -> StringName:
	return &"clone"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if delay < 0.0 or lifetime <= 0.0 or power_fraction < 0.0 or actions < 0:
		found.append("%s has a negative delay, power_fraction or actions, or no lifetime" % context)
	return found
