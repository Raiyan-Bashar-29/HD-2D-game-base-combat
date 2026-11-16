class_name RewindMechanism
extends PowerMechanism
## A rewind (C8.11b): the user is put back as it was a little while ago.
##
## IN PLAIN WORDS: while the kit is on, the user's place and hp are written down as time passes.
## Using the power puts them back to how they were `back` seconds ago in the field (`back` of the
## user's own turns ago in a battle, where only hp is put back). With less recorded than that, the
## oldest record is used. `restore_place` and `restore_hp` choose what comes back. A fallen user
## is not raised.
##
## OWNS: the shape of a rewind.
## MUST NOT: hold running state. `RewindRun` (gameplay) runs it.

## How far back: seconds in the field, the user's turns in a battle.
@export var back: float = 3.0
## The user's place in the field comes back.
@export var restore_place: bool = true
## The user's hp (its defeat pool) comes back.
@export var restore_hp: bool = true


func kind() -> StringName:
	return &"rewind"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if back <= 0.0:
		found.append("%s rewinds no time" % context)
	if not restore_place and not restore_hp:
		found.append("%s puts nothing back" % context)
	return found
