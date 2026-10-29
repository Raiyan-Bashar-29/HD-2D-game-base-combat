class_name BattleBrain
extends Resource
## How a combatant nobody controls chooses its turn: a list of weighted `BrainEntry`s. Authored
## inline on a combatant's definition (C2.6), the same way its commands are.
##
## THE TEMPLATE DEFAULT IS WEIGHTED CHOICE AMONG WHAT IS ALLOWED. Each turn, every entry whose
## conditions pass and which has a legal target competes by weight, drawn from the battle's
## seeded rng. With nothing allowed, the combatant attacks the first legal target, or defends.
## A game wanting a script or a utility AI replaces `BattleAi`, not this data.
##
## OWNS: the list of choices.
## MUST NOT: choose. `BattleAi` does.

@export var entries: Array[BrainEntry] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: BrainEntry in entries:
		if entry == null:
			found.append("%s has an empty entry" % context)
		else:
			found.append_array(entry.problems(context))
	return found
