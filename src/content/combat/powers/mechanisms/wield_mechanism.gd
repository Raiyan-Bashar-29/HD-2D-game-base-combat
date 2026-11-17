class_name WieldMechanism
extends PowerMechanism
## A made weapon (C8.14b): the user forms a weapon and fights with it for a while.
##
## IN PLAIN WORDS: a use lends the user `moves` (its field chain and dodge, laid over its own as a
## worn weapon's are), gives its plain attack `element`, and adds `bonuses` to its sheet, for
## `lasts` seconds in the field (the user's turns in a battle, where the bonuses and the element
## count). Then, or when the kit comes off, all of it goes and what the user had before is back.
## A second use starts the time again.
##
## OWNS: the shape of a made weapon.
## MUST NOT: hold running state. `WieldRun` (gameplay) runs it.

## The chain played while it is held. Null keeps the user's own.
@export var moves: MoveSet
## The plain attack's element while it is held. Empty keeps the user's.
@export var element: StringName = &""
## Stat modifiers while it is held.
@export var bonuses: Array[StatModifier] = []
## How long it is held: seconds in the field, the user's turns in a battle.
@export var lasts: float = 15.0


func kind() -> StringName:
	return &"wield"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if lasts <= 0.0:
		found.append("%s holds its weapon for no time" % context)
	if moves == null and element == &"" and bonuses.is_empty():
		found.append("%s makes a weapon that changes nothing" % context)
	return found
