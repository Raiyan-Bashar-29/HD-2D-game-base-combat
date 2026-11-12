class_name BattlefieldEffect
extends Resource
## One rule of a battlefield (M4, C6.9a) for one group of fighters. See `docs/GEAR.md` § Part 3.
##
## IN PLAIN WORDS: while the battlefield stands, every fighter in `who` who is inside it gets
## `modifiers` on its sheet and holds `statuses`. When it leaves (walks out of reach, or the
## battlefield ends) both come off again. A battlefield is a list of these, so "the caster's side
## hits harder and the other side is slowed" is two effects.
##
## THE GROUPS:
## - CASTER: the one who raised it.
## - CASTER_SIDE: the caster and its allies.
## - OTHER_SIDE: everyone hostile to the caster.
## - EVERYONE: all fighters inside, the caster too.
## - EVERYONE_BUT_CASTER: all fighters inside except the caster.
##
## Damage on enter, on exit and on a clock, pull and push and immunity come with C6.9b.
##
## OWNS: the shape of one battlefield rule.
## MUST NOT: hold running state. `BattlefieldRun` (gameplay) applies it.

enum Who { CASTER, CASTER_SIDE, OTHER_SIDE, EVERYONE, EVERYONE_BUT_CASTER }

@export var who: Who = Who.OTHER_SIDE
## Put on the sheet of each fighter in `who` while it is inside: `attack`, `defence`,
## `damage_dealt`, `damage_taken`, `speed`, `regen_<pool>`, `cost_mult_<pool>`, `resist_<tag>`.
@export var modifiers: Array[StatModifier] = []
## Held by each fighter in `who` while it is inside, and taken off when it leaves: a buff, a
## debuff, or a SKIP_TURN status that holds the other side still.
@export var statuses: Array[StatusEffect] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if modifiers.is_empty() and statuses.is_empty():
		found.append("%s changes nothing" % context)
	for i: int in modifiers.size():
		if modifiers[i] == null:
			found.append("%s has an empty modifier %d" % [context, i])
		elif modifiers[i].stat == &"":
			found.append("%s modifier %d names no stat" % [context, i])
	for i: int in statuses.size():
		if statuses[i] == null:
			found.append("%s has an empty status %d" % [context, i])
		else:
			found.append_array(statuses[i].problems())
	return found
