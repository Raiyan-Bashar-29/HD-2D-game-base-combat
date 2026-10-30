class_name SkillEffect
extends Resource
## One extra thing a skill does to each of its targets, beyond its plain `power`. A skill lists
## any number of these in `effects`, so a spell can hurt and drain, or cure and heal, at once.
##
## IN PLAIN WORDS, the kinds:
## - DAMAGE: hit for `amount` power through the user's damage formula (attack against defence).
## - HEAL: add `amount` hp straight to the target, not through defence. Cannot lift the fallen.
## - RESTORE: add `amount` to another pool, `pool` (mp by default): an ether, a mana gift.
## - DRAIN: hit for `amount` power, and the user gains `fraction` of the hp actually taken.
## - CURE: end the status `status_id` on the target: an antidote, a wake-up.
## - DISPEL: end every status the target holds that carries `tag`: strip buffs, purge debuffs.
## - REVIVE: stand a fallen target back up with `amount` (0 to 1) of their maximum hp. A skill
##   with a REVIVE aims only at the fallen (`Skill.revives`).
##
## It is authored inline inside a skill's `.tres`, never as a file of its own, the way a
## command is authored inside a combatant definition.
##
## OWNS: the shape of one effect and what is wrong with it.
## MUST NOT: apply itself, or know who uses it. `SkillUse` (gameplay) does that.

enum Kind { DAMAGE, HEAL, RESTORE, DRAIN, CURE, DISPEL, REVIVE }

@export var kind: Kind = Kind.DAMAGE
## Power for DAMAGE and DRAIN, points for HEAL and RESTORE, a fraction of max hp for REVIVE.
@export var amount: float = 0.0
## The pool RESTORE fills.
@export var pool: StringName = &"mp"
## The share of the hp taken that DRAIN gives back to the user.
@export_range(0.0, 1.0, 0.01) var fraction: float = 0.5
## The status CURE ends.
@export var status_id: StringName = &""
## The tag DISPEL clears, matched against `StatusEffect.tags`.
@export var tag: StringName = &""


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	match kind:
		Kind.DAMAGE, Kind.HEAL, Kind.DRAIN:
			if amount <= 0.0:
				found.append("%s has a %s effect with no amount" % [context, Kind.keys()[kind]])
		Kind.RESTORE:
			if amount <= 0.0 or pool == &"":
				found.append("%s has a RESTORE effect with no amount or pool" % context)
		Kind.CURE:
			if status_id == &"":
				found.append("%s has a CURE effect naming no status_id" % context)
		Kind.DISPEL:
			if tag == &"":
				found.append("%s has a DISPEL effect naming no tag" % context)
		Kind.REVIVE:
			if amount <= 0.0 or amount > 1.0:
				found.append("%s has a REVIVE effect whose amount is not a fraction above 0 up to 1" % context)
	return found
