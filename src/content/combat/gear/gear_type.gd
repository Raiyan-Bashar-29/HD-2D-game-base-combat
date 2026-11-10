class_name GearType
extends Resource
## The kind of thing a piece of gear is (C7.1a): a sword, a lance, a helm, a ring. See
## `docs/GEAR.md` Part 1.
##
## IN PLAIN WORDS: a type holds what every piece of that kind shares, so a hundred swords do not
## repeat it. It says which family the kind belongs to, which slots it may be worn in, and the
## stat changes all of its pieces carry (heavy plate slows its wearer, whatever the plate).
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
	return found
