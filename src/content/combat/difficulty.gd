class_name Difficulty
extends ContentEntry
## How hard the fights are (C5.4a): how much harder the player's side hits, and how much more it
## takes. Authored at `data/difficulty/<name>.tres` with the id `difficulty/<name>`; `DifficultyDb`
## finds it, and `CombatDifficulty` says which one is on.
##
## IN PLAIN WORDS: `dealt` and `taken` are shares of a hit. `dealt` 0.5 makes every hit the `side`
## lands on a foe half as hard again; `taken` -0.5 halves every hit a foe lands on the `side`. A
## hit between two fighters of the same side, or of neither, is left alone, and so is a miss or a
## heal. Nothing here touches hp, accuracy or the turn order.
##
## OWNS: the shape of one difficulty.
## MUST NOT: decide which one is on, or change a hit itself (`CombatDifficulty` does both).

@export var name_key: String = ""
@export var desc_key: String = ""
## Where a settings screen lists it: lowest first.
@export var order: int = 0
## The faction the difficulty is about: the player's party.
@export var side: StringName = &"player"
## Extra share of the damage the side deals. -1 is the least: no damage at all.
@export var dealt: float = 0.0
## Extra share of the damage the side takes. -1 is the least: no damage at all.
@export var taken: float = 0.0


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if name_key == "":
		found.append("%s has no name_key" % where)
	if side == &"":
		found.append("%s names no side" % where)
	if dealt < -1.0 or taken < -1.0:
		found.append("%s has a dealt or taken share below -1" % where)
	return found
