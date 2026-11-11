class_name LootTable
extends Resource
## Loot that is rolled, not guaranteed (C7.2): a list of lines and how many times to pick.
##
## IN PLAIN WORDS: each roll picks one line, by weight, and gives that line's item. An encounter
## and a fighter can each carry a table (`Encounter.loot_table`, `CombatantDef.loot_table`).
## The guaranteed list (`Encounter.loot`, a field enemy's `loot`) is still given every time;
## the table adds to it.
##
## OWNS: the data of one table, and checking it.
## MUST NOT: roll anything. `LootRoll` does, with the fight's own random numbers, so a seeded
## fight drops the same things.

@export var entries: Array[LootEntry] = []
## How many times a line is picked. The same line can be picked twice.
@export var rolls: int = 1


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if rolls < 1:
		found.append("%s has a loot table that never rolls" % context)
	if entries.is_empty():
		found.append("%s has a loot table with no lines" % context)
	for entry: LootEntry in entries:
		if entry == null:
			found.append("%s has an empty loot line" % context)
		else:
			found.append_array(entry.problems(context))
	return found
