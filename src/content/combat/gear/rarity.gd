class_name Rarity
extends ContentEntry
## One rarity tier, as authored data (C7.2): Common, Rare, Legendary and so on. See
## `docs/GEAR.md` § Rarity.
##
## IN PLAIN WORDS: a piece of gear names a rarity. The rarity does two things today:
##   - `stat_scale` makes every stat change of the piece bigger or smaller (a Rare sword is the
##     same sword with 1.3 times the numbers);
##   - `drop_weight` makes the piece turn up more or less often when a loot table is rolled.
##     0 means it is never rolled at random (a one-of-a-kind weapon), though a guaranteed drop
##     still gives it.
## A game adds a tier by adding a file at `data/rarities/<name>.tres` with the id
## `rarity/<name>`. No code names any tier.
##
## `sockets` adds sockets to every piece of the tier (C7.4c, `GearDefinition.socket_count`).
##
## READ LATER: `color` (the gear screen, C7.7), `affixes` (C7.2b) and `max_upgrade` (C7.5).
## They are here now so a tier is written once.
##
## OWNS: the data of one tier, and the scaling rule for one stat change.
## MUST NOT: know which pieces have it, or touch an autoload.

@export var name_key: String = ""
## The order of the tiers, 0 upward, for sorting a list.
@export var rank: int = 0
## Shown on the piece's name.
@export var color: Color = Color.WHITE
## Multiplies the piece's stat changes. 1.0 changes nothing.
@export var stat_scale: float = 1.0
## How often a piece of this tier is picked when loot is rolled, as a multiplier on the loot
## entry's own weight. 0 means never.
@export var drop_weight: float = 1.0
## How many random extra stat changes a dropped piece rolls.
@export var affixes: int = 0
## Extra sockets on the piece.
@export var sockets: int = 0
## The highest upgrade level a piece of this tier reaches. 0 means the game's default.
@export var max_upgrade: int = 0


## `modifier` as a piece of this tier gives it. An added amount is multiplied. A multiplier
## keeps its distance from 1 multiplied (x1.2 at scale 1.5 is x1.3). An override is left alone.
## With nothing to change, the same object comes back.
func scaled(modifier: StatModifier) -> StatModifier:
	if modifier == null or is_equal_approx(stat_scale, 1.0) or modifier.op == StatModifier.Op.OVERRIDE:
		return modifier
	var amount: float = modifier.value * stat_scale
	if modifier.op == StatModifier.Op.MULTIPLY:
		amount = 1.0 + (modifier.value - 1.0) * stat_scale
	return StatModifier.of(modifier.stat, modifier.op, amount, modifier.source)


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if name_key == "":
		found.append("%s has no name_key" % where)
	if stat_scale < 0.0:
		found.append("%s has a negative stat_scale" % where)
	if drop_weight < 0.0:
		found.append("%s has a negative drop_weight" % where)
	if affixes < 0 or sockets < 0 or max_upgrade < 0:
		found.append("%s has a negative count" % where)
	return found
