class_name Affix
extends ContentEntry
## One random extra modifier a dropped piece of gear can roll (C7.2b), such as "of Embers":
## `fire_power` +5 to +10 %. See `docs/GEAR.md` § Affixes.
##
## IN PLAIN WORDS: a game adds an affix by adding `data/affixes/<name>.tres` with the id
## `affix/<name>`. When a unique piece drops, it rolls as many affixes as its rarity's `affixes`,
## drawn by `weight` from those whose `slots` fit the piece (empty fits any piece), each one at
## most once, with a value between `low` and `high`. Stacked items never roll.
##
## OWNS: the shape of one affix.
## MUST NOT: hold which piece rolled it. `GearAffixes` (gameplay) keeps that, in `Flags`.

## Shown beside the piece's name, such as "of Embers".
@export var name_key: String = ""
@export var stat: StringName = &""
@export var op: StatModifier.Op = StatModifier.Op.ADD
## The smallest and largest value it can roll.
@export var low: float = 1.0
@export var high: float = 1.0
## The slots it may appear on; empty means any.
@export var slots: Array[StringName] = []
## How often it is drawn, against the other affixes that fit.
@export var weight: float = 1.0


## True when this affix may roll on a piece that goes in any of `piece_slots`.
func fits(piece_slots: Array[StringName]) -> bool:
	if slots.is_empty():
		return true
	for slot: StringName in piece_slots:
		if slots.has(slot):
			return true
	return false


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if name_key == "" or stat == &"":
		found.append("%s needs a name_key and a stat" % where)
	if high < low or weight <= 0.0:
		found.append("%s has high below low, or no weight" % where)
	return found
