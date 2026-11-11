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
## WHAT IT LENDS TO THE WEARER'S PLAIN ATTACK (C7.1c):
##   - `element`: the attack becomes a hit of that element (a fire sword burns).
##   - `attack_tags`: what the attack counts as for a weakness (a lance is `pierce`).
## Both add to what the type gives. A skill or a power keeps its own element and tags.
##
## TAKING UP MORE THAN ONE SLOT (C7.1c): `blocks` lists slots the piece fills besides its own.
## A two-handed sword blocks the off hand: putting it on empties the off hand, and putting a
## shield there takes the sword off. Any slot can be blocked, not only the off hand.
##
## RARITY (C7.2): `rarity` names a tier, such as `rarity/rare`. The tier's `stat_scale`
## multiplies every stat change the piece gives, and its `drop_weight` makes the piece rarer in
## rolled loot. Empty means plain: nothing is scaled.
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
## The element the wearer's plain attack gets. Empty means the type's.
@export var element: StringName = &""
## What the wearer's plain attack counts as for a weakness, on top of the type's.
@export var attack_tags: Array[StringName] = []
## Slots this piece takes up besides the one it is worn in, on top of the type's.
@export var blocks: Array[StringName] = []
## The rarity tier, by id (`rarity/<name>`). Empty means none.
@export var rarity: StringName = &""


## The slots this piece may be worn in, in the order to try them.
func slots() -> Array[StringName]:
	if slot != &"":
		return [slot]
	if type == null:
		return []
	return type.slots.duplicate()


## Every stat change wearing this piece gives: the type's, then its own, each at the size its
## rarity makes it.
func all_modifiers() -> Array[StatModifier]:
	var plain: Array[StatModifier] = []
	if type != null:
		plain.append_array(type.modifiers)
	plain.append_array(modifiers)
	var tier: Rarity = RarityDb.of(rarity)
	if tier == null:
		return plain
	var out: Array[StatModifier] = []
	for modifier: StatModifier in plain:
		out.append(tier.scaled(modifier))
	return out


## The element this piece lends: its own, else its type's, else none.
func strike_element() -> StringName:
	if element != &"" or type == null:
		return element
	return type.element


## Every weakness tag this piece lends: the type's, then its own, each once.
func all_attack_tags() -> Array[StringName]:
	return _joined(type.attack_tags if type != null else ([] as Array[StringName]), attack_tags)


## Every slot this piece takes up besides its own: the type's, then its own, each once.
func all_blocks() -> Array[StringName]:
	return _joined(type.blocks if type != null else ([] as Array[StringName]), blocks)


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
	if rarity != &"" and RarityDb.of(rarity) == null:
		found.append("%s names the rarity %s, which does not exist" % [where, rarity])
	if attack_tags.has(&""):
		found.append("%s lists an unnamed attack tag" % where)
	for blocked: StringName in blocks:
		if blocked == &"":
			found.append("%s blocks an unnamed slot" % where)
		elif slots().has(blocked):
			found.append("%s blocks %s, a slot it is worn in" % [where, blocked])
	return found


func _joined(first: Array[StringName], second: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for list: Array[StringName] in [first, second]:
		for entry: StringName in list:
			if not out.has(entry):
				out.append(entry)
	return out
