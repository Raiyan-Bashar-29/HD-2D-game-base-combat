class_name DoorsMechanism
extends PowerMechanism
## Linked doors (C8.14c): two doors the user places; stepping into one comes out of the other.
##
## IN PLAIN WORDS, IN THE FIELD: each use places a door `ahead` metres in front of the user; a
## third use takes the oldest away, so at most two stand, linked. A fighter walking into one is
## put at the other, `exit` metres out of it, and that door lets it be for a moment so it does not
## walk straight back. Only the user's side may pass, unless `anyone`. They go after `lifetime`
## seconds (0: never by time), when the user falls, the kit comes off or the area is left. In a
## battle a use does nothing.
##
## OWNS: the shape of linked doors.
## MUST NOT: hold running state. `DoorsRun` (gameplay) runs it.

## Metres in front of the user a door is placed.
@export var ahead: float = 1.0
## Metres out of the far door a fighter comes out.
@export var exit: float = 1.0
## How wide a door is, in metres: the radius a fighter must step within.
@export var radius: float = 0.7
## Seconds the doors stand. 0 means until something else takes them down.
@export var lifetime: float = 30.0
## True: foes may pass too.
@export var anyone: bool = false


func kind() -> StringName:
	return &"doors"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if radius <= 0.0 or ahead < 0.0 or exit < 0.0 or lifetime < 0.0:
		found.append("%s has no width, or a negative distance or lifetime" % context)
	return found
