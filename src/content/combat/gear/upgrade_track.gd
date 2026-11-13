class_name UpgradeTrack
extends Resource
## A piece's upgrade track (C7.5): its levels, and what it awakens into at the top. See
## `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS: `levels[0]` is the step from level 0 to level 1, and so on. A piece is capped
## at the number of levels, or lower when the piece's `max_upgrade` or its rarity's says so
## (`GearDefinition.upgrade_cap`).
##
## AWAKENING: at the cap, a piece with `awaken_into` may be turned into that other piece, paying
## `awaken_items` (an unfinished blade becomes the finished one). The new piece starts at level
## 0. Crafting's AWAKEN recipes (C7.6) are a second way in.
##
## OWNS: the data of one track, and checking it.
## MUST NOT: know which piece it belongs to or its level, or touch an autoload.

## The steps, lowest first.
@export var levels: Array[UpgradeLevel] = []
## The item the piece turns into at the cap. Empty means it does not awaken.
@export var awaken_into: StringName = &""
## What awakening uses up, besides the piece itself: item id -> how many.
@export var awaken_items: Dictionary[StringName, int] = {}


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if levels.is_empty():
		found.append("%s has an upgrade track with no levels" % where)
	for i: int in levels.size():
		if levels[i] == null:
			found.append("%s lists an empty upgrade level" % where)
		else:
			found.append_array(levels[i].problems("%s upgrade level %d" % [where, i + 1]))
	if awaken_into == &"" and not awaken_items.is_empty():
		found.append("%s has an awakening cost and nothing to awaken into" % where)
	found.append_array(UpgradeLevel.cost_problems(where + " awakening", awaken_items))
	return found
