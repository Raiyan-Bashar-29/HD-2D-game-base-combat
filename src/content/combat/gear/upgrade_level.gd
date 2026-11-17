class_name UpgradeLevel
extends Resource
## One step of a piece's upgrade track (C7.5). See `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS: to reach this level, the player pays `items` from the bag. Once reached, and
## for every level after it, the piece gives more while worn:
##   - `stat_bonus`: a share of the piece's own added amounts, given again (0.1 is +10%). It adds
##     up over the levels, so three levels of 0.1 give +30%. Multipliers and overrides are left
##     alone.
##   - `modifiers`: stat changes the piece gains at this level.
##   - `sockets`: more sockets for gems.
## A power in the piece's kit can wait for a level (`Power.requires_upgrade`).
##
## A LEVEL IS BOUGHT OR WON, NEVER BOTH. A bought level has `items`. A won level (C9.5d) has
## `fights`: the piece goes up after that many won fights while it is worn, and cannot be
## bought. A level with neither, or with both, is a problem.
##
## OWNS: the data of one step, and checking it.
## MUST NOT: know which piece it belongs to or its level, or touch an autoload.

## What reaching this level uses up: item id -> how many.
@export var items: Dictionary[StringName, int] = {}
## Won fights, with the piece worn, that reach this level (C9.5d). 0 means the level is bought.
@export var fights: int = 0
## A share of the piece's added amounts given again from this level on (0.1 is +10%).
@export var stat_bonus: float = 0.0
## Stat changes the piece gains from this level on. Leave `source` empty.
@export var modifiers: Array[StatModifier] = []
## Sockets the piece gains from this level on.
@export var sockets: int = 0
## Passives (C9.3) the wearer holds from this level on.
@export var passives: Array[PassiveSkill] = []


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if items.is_empty() and fights <= 0:
		found.append("%s has no cost and no number of fights" % where)
	if fights < 0 or (fights > 0 and not items.is_empty()):
		found.append("%s must be bought or won by fights, not both" % where)
	found.append_array(cost_problems(where, items))
	if stat_bonus < -1.0:
		found.append("%s takes away more than the whole piece" % where)
	if sockets < 0:
		found.append("%s has fewer than zero sockets" % where)
	for modifier: StatModifier in modifiers:
		if modifier == null or modifier.stat == &"":
			found.append("%s has an empty modifier or one with no stat" % where)
	return found


## The problems of a cost list: an unnamed item, or a count below one.
static func cost_problems(where: String, cost: Dictionary[StringName, int]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for item_id: StringName in cost:
		if item_id == &"" or cost[item_id] < 1:
			found.append("%s costs an unnamed item or fewer than one" % where)
	return found
