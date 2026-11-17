class_name CopyMechanism
extends PowerMechanism
## A copy (C8.13b): the user borrows a power another fighter used.
##
## IN PLAIN WORDS: while the kit is on, the user remembers the last power anyone else used, or with
## `suffered_only` the last one used on it. Using the copy lends the user that power for `lasts`
## seconds in the field (the user's turns in a battle); it is used like any of the user's own,
## with its own cooldown, and goes when the time is up or the kit comes off. With nothing
## remembered the use does nothing. A passive, or another copy, is never remembered.
##
## OWNS: the shape of a copy.
## MUST NOT: hold running state. `CopyRun` (gameplay) runs it.

## How long the borrowed power stays: seconds in the field, the user's turns in a battle.
@export var lasts: float = 10.0
## True: only a power used on the user is remembered. False: any power used by anyone else.
@export var suffered_only: bool = false


func kind() -> StringName:
	return &"copy"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if lasts <= 0.0:
		found.append("%s lends nothing for no time" % context)
	return found
