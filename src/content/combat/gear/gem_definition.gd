class_name GemDefinition
extends ContentEntry
## One gem, as authored data (C7.4c). See `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS: a gem is an ordinary item (so the bag, saves and pickups already work for it)
## plus this file, which says what it does once socketed into a piece of gear. While that piece
## is worn, the gem's stat changes are on the wearer, and a gem with an `element` gives the
## piece's plain attack that element. The file lives at `data/gems/<name>.tres`, and its `id` is
## `gem/<name>`. Socketing it uses the item up; `GearSockets` does that, and gives it back.
##
## OWNS: the data of one gem, and checking its own fields.
## MUST NOT: know which piece holds it. It also must not touch an autoload, as
## `ItemDefinition`'s header explains.

## The item this gem is, such as `item/<name>`.
@export var item_id: StringName = &""
## Stat changes while the piece holding it is worn.
@export var modifiers: Array[StatModifier] = []
## The element the piece's plain attack takes while the gem is in it. Empty means none.
@export var element: StringName = &""
## Passives (C9.3) the wearer of the piece holding the gem has.
@export var passives: Array[PassiveSkill] = []


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if item_id == &"":
		found.append("%s names no item_id" % where)
	for modifier: StatModifier in modifiers:
		if modifier == null:
			found.append("%s lists an empty modifier" % where)
		elif modifier.stat == &"":
			found.append("%s has a modifier with no stat" % where)
	if modifiers.is_empty() and element == &"" and passives.is_empty():
		found.append("%s gives nothing: no modifiers, no element and no passive" % where)
	return found
