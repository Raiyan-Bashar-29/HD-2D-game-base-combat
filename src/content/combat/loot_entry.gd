class_name LootEntry
extends Resource
## One line of a `LootTable` (C7.2): an item, how likely it is, and how many.
##
## IN PLAIN WORDS: "a healing herb, weight 3, one or two of them". The weight is a share, not a
## percentage: an entry of weight 3 beside one of weight 1 is picked three times in four.
## Leave `item_id` empty for a line that means "nothing this time", so a table can say "70 %
## nothing, 30 % a ring".
##
## OWNS: the data of one line, and checking it.
## MUST NOT: roll anything or read a flag. `LootRoll` does.

## The item given. Empty means this line gives nothing.
@export var item_id: StringName = &""
## This line's share of the picks. A piece of gear's rarity multiplies it (`Rarity.drop_weight`).
@export var weight: float = 1.0
## How many are given when picked: a whole number from `min_count` to `max_count`.
@export var min_count: int = 1
@export var max_count: int = 1
## A flag that must be true for this line to be in the table at all. Empty means always.
@export var needs_flag: StringName = &""


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if weight < 0.0:
		found.append("%s has a loot line with a negative weight" % context)
	if min_count < 0 or max_count < min_count:
		found.append("%s has a loot line whose count range is not low to high" % context)
	return found
