class_name GearRules
extends Resource
## The list of slots a fighter has for gear (C7.1a). See `docs/GEAR.md` Part 1.
##
## IN PLAIN WORDS: the slots are data, not code. A game that wants two weapon hands and no
## relic, or a single "outfit" slot, edits this list and nothing else. A worn set with no rules
## of its own uses the defaults below.
##
## OWNS: the slot list, and saying whether a name is one of its slots.
## MUST NOT: know what is worn in a slot. `GearSet` does.

## The default slots, in the order a screen lists them.
const DEFAULT_SLOTS: Array[StringName] = [
	&"weapon", &"offhand", &"head", &"body", &"hands", &"feet",
	&"accessory_1", &"accessory_2", &"relic",
]

@export var slots: Array[StringName] = DEFAULT_SLOTS.duplicate()


func has_slot(slot: StringName) -> bool:
	return slots.has(slot)


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if slots.is_empty():
		found.append("%s gear rules list no slots" % context)
	var seen: Array[StringName] = []
	for slot: StringName in slots:
		if slot == &"":
			found.append("%s gear rules list an unnamed slot" % context)
		elif seen.has(slot):
			found.append("%s gear rules list the slot %s twice" % [context, slot])
		seen.append(slot)
	return found
