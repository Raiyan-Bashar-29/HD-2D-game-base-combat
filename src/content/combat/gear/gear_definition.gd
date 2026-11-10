class_name GearDefinition
extends ContentEntry
## One piece of gear, as authored data (C7.1a). See `docs/GEAR.md` Part 1.
##
## IN PLAIN WORDS: a piece of gear is an ordinary item (so the bag, saves and pickups already
## work for it) plus this file, which says what wearing it does. An item with no file like this
## is not gear. The file lives at `data/gear/<name>.tres`, and its `id` is `gear/<name>`.
##
## WHERE IT IS WORN: a piece with `slot` set goes in that one slot. A piece with `slot` left
## empty may go in any slot its type lists, so one ring fits either accessory slot.
##
## OWNS: the data of one piece, and checking its own fields.
## MUST NOT: know who wears it or whether it is worn. `GearSet` does. It also must not touch an
## autoload, as `ItemDefinition`'s header explains.

## The item this piece is, such as `item/<name>`. The bag holds the item; this file adds the stats.
@export var item_id: StringName = &""
## What kind of thing it is. It gives the slots and the stat changes the whole kind shares.
@export var type: GearType
## The one slot it is worn in. Empty means any of its type's slots.
@export var slot: StringName = &""
## Stat changes while worn, on top of the type's. Leave `source` empty: the worn set fills it in.
@export var modifiers: Array[StatModifier] = []
## The fighters who may wear it, by combatant id. Empty means anyone.
@export var wearers: Array[StringName] = []


## The slots this piece may be worn in, in the order to try them.
func slots() -> Array[StringName]:
	if slot != &"":
		return [slot]
	if type == null:
		return []
	return type.slots.duplicate()


## Every stat change wearing this piece gives: the type's, then its own.
func all_modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	if type != null:
		out.append_array(type.modifiers)
	out.append_array(modifiers)
	return out


func may_wear(who: StringName) -> bool:
	return wearers.is_empty() or wearers.has(who)


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if item_id == &"":
		found.append("%s names no item_id" % where)
	if type == null:
		found.append("%s has no type" % where)
	else:
		found.append_array(type.problems(where))
		if slot != &"" and not type.slots.has(slot):
			found.append("%s is worn in %s, which its type does not allow" % [where, slot])
	for modifier: StatModifier in modifiers:
		if modifier == null:
			found.append("%s lists an empty modifier" % where)
		elif modifier.stat == &"":
			found.append("%s has a modifier with no stat" % where)
	return found
