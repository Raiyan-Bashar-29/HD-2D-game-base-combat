class_name GearType
extends Resource
## The kind of thing a piece of gear is (C7.1a): a sword, a lance, a helm, a ring. See
## `docs/GEAR.md` Part 1.
##
## IN PLAIN WORDS: a type holds what every piece of that kind shares, so a hundred swords do not
## repeat it. It says which family the kind belongs to, which slots it may be worn in, and the
## stat changes all of its pieces carry (heavy plate slows its wearer, whatever the plate).
##
## WHAT A WEAPON LENDS (C7.1c): a type may say what element its wearer's plain attack has and
## what it counts as for a weakness (a lance is `pierce`). It may also list slots its pieces
## take up besides their own, in `blocks`: a two-handed sword blocks the off hand.
##
## A type is a data file, `data/gear_types/<name>.tres`, that pieces point at. Adding a kind of
## gear is adding a file: no code changes.
##
## OWNS: the shape of a gear type, and checking its own fields.
## MUST NOT: know who wears a piece, or name any game's gear.

## The four families. A screen sorts by this; SPECIAL is gear with a mechanism behind it.
enum Family { WEAPON, ARMOUR, ACCESSORY, SPECIAL }

@export var type_id: StringName = &""
@export var name_key: String = ""
@export var family: Family = Family.WEAPON
## The slots a piece of this type may be worn in. A ring lists both accessory slots.
@export var slots: Array[StringName] = []
## Stat changes every piece of this type carries while worn. Leave `source` empty: the worn set
## names the piece as the source, so taking the piece off removes them.
@export var modifiers: Array[StatModifier] = []
## The element the wearer's plain attack gets, such as `fire`. A piece's own element wins.
@export var element: StringName = &""
## What the wearer's plain attack counts as for a weakness, such as `sword` or `pierce`.
@export var attack_tags: Array[StringName] = []
## Slots a piece of this type takes up besides the one it is worn in. Two-handed: the off hand.
@export var blocks: Array[StringName] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s gear type %s" % [context, type_id]
	if type_id == &"":
		found.append("%s has no type_id" % where)
	if name_key == "":
		found.append("%s has no name_key" % where)
	if slots.is_empty():
		found.append("%s lists no slots, so nothing of this type can be worn" % where)
	for modifier: StatModifier in modifiers:
		if modifier == null:
			found.append("%s lists an empty modifier" % where)
		elif modifier.stat == &"":
			found.append("%s has a modifier with no stat" % where)
	if attack_tags.has(&""):
		found.append("%s lists an unnamed attack tag" % where)
	for slot: StringName in blocks:
		if slot == &"":
			found.append("%s blocks an unnamed slot" % where)
		elif slots.has(slot):
			found.append("%s blocks %s, a slot it is worn in" % [where, slot])
	return found
