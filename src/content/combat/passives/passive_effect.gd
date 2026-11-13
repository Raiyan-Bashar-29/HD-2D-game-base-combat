class_name PassiveEffect
extends Resource
## One thing a passive does when it wakes (C9.1): change a pool, give a status, or cure. See
## `docs/PASSIVES.md` § The passive.
##
## IN PLAIN WORDS: `kind` picks the action, `target` picks who it lands on, and the other fields
## are its numbers. A heal is a positive `amount`; a cost or a drain is a negative one.
## - POOL_FLAT: `pool` changes by `amount` points.
## - POOL_SHARE: `pool` changes by `amount` of its maximum (0.1 is a tenth).
## - POOL_FROM_DAMAGE: `pool` changes by `amount` of the damage in the event (0.2 is life steal
##   of a fifth). Only a hit or a kill carries damage; elsewhere it does nothing.
## - GIVE_STATUS: gives `status`, `stacks` times.
## - CURE: takes off every status tagged `tag`.
## - SCALE_HIT (C9.2b): multiplies the hit in the event by `amount`, BEFORE it lands (1.5 is a
##   killer bonus, 0.5 a guard). Only in HIT_DEALT, CRIT_DEALT and HIT_TAKEN.
## - SURVIVE (C9.2b): in LETHAL_HIT only. The hit is cut so the holder is left at `leave` HP.
## - EXTRA_HIT (C9.2b): the holder lands `skill` on each target, at `amount` of its power (a
##   pursuit hit, a counter). It wakes none of the holder's own hit passives.
##
## OWNS: the data of one effect, and checking it.
## MUST NOT: apply itself. `PassiveEffects` (gameplay) does.

enum Kind { POOL_FLAT, POOL_SHARE, POOL_FROM_DAMAGE, GIVE_STATUS, CURE, SCALE_HIT, SURVIVE,
	EXTRA_HIT }
## SELF is the holder; OTHER is the other fighter in the event (the one hit, the one who hit,
## the one felled); ALLIES and FOES are everyone standing on that side, the holder included
## among its allies.
enum Target { SELF, OTHER, ALLIES, FOES }

@export var kind: Kind = Kind.POOL_FLAT
@export var target: Target = Target.SELF
## The pool the three POOL kinds change: `hp`, `mp`, or any pool the fighter has.
@export var pool: StringName = &"hp"
## Points for POOL_FLAT; a share for POOL_SHARE and POOL_FROM_DAMAGE; what SCALE_HIT multiplies
## the hit by; the share of the skill's power EXTRA_HIT lands.
@export var amount: float = 0.0
## What GIVE_STATUS gives, and how many times (for a status that stacks).
@export var status: StatusEffect
@export var stacks: int = 1
## What CURE takes off.
@export var tag: StringName = &""
## The HP SURVIVE leaves the holder with.
@export var leave: int = 1
## The skill EXTRA_HIT lands: its power, element, tags and sure-hit are read.
@export var skill: Skill


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	match kind:
		Kind.POOL_FLAT, Kind.POOL_SHARE, Kind.POOL_FROM_DAMAGE:
			if pool == &"":
				found.append("%s changes a pool but names none" % where)
			if amount == 0.0:
				found.append("%s changes a pool by nothing" % where)
		Kind.GIVE_STATUS:
			if status == null:
				found.append("%s gives a status but has none" % where)
			elif not status.problems().is_empty():
				found.append("%s gives a broken status (%s)" % [where, status.id])
			if stacks < 1:
				found.append("%s gives a status fewer than once" % where)
		Kind.CURE:
			if tag == &"":
				found.append("%s cures but names no tag" % where)
		Kind.SCALE_HIT:
			if amount < 0.0 or amount == 1.0:
				found.append("%s scales a hit by a negative number, or by 1" % where)
		Kind.SURVIVE:
			if leave < 1:
				found.append("%s survives a hit with less than 1 HP" % where)
		Kind.EXTRA_HIT:
			if skill == null or amount <= 0.0:
				found.append("%s lands an extra hit with no skill, or no power" % where)
	return found
