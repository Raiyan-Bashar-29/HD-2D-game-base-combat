class_name HitFlags
extends RefCounted
## What an attacker's held statuses say about the hits it makes (C6.9c): sure hits, and tags the
## hit carries. Read by `Combatant.hit`, so every hit gets them: a field strike, a skill, a battle
## attack.
##
## IN PLAIN WORDS: a battlefield with `sure_hit` puts a status on its caster that grants sure
## hits. While that status is held, the caster's hits cannot miss. A foe holding the battlefield's
## `cancelled_by` status is the exception: against that foe the hit is a roll again. The tags a
## battlefield lists are added to every hit its caster makes, so a barrier can let them through.
##
## OWNS: reading the flags off an attacker's statuses, and the rule for `cancelled_by`.
## MUST NOT: change a status or a hit. `Combatant.hit` applies what this says.

## True when some held status makes this attacker's hits sure hits.
var sure: bool = false
## The tags granted to every hit this attacker makes, without repeats.
var tags: Array[StringName] = []
## The status id that, held by a target, stops the sure hit against it. Empty for none.
var cancelled_by: StringName = &""


## The flags of `attacker`, from its held statuses. Empty when it has none or no statuses.
static func of(attacker: Combatant) -> HitFlags:
	var out := HitFlags.new()
	if attacker == null:
		return out
	var statuses: StatusSet = StatusSet.of(attacker.get_parent())
	if statuses == null:
		return out
	for effect: StatusEffect in statuses.held():
		if effect.grants_sure_hit:
			out.sure = true
		if effect.cancelled_by != &"":
			out.cancelled_by = effect.cancelled_by
		for tag: StringName in effect.grants_hit_tags:
			if not out.tags.has(tag):
				out.tags.append(tag)
	return out


## True when a hit on `target` is a sure hit: granted, and `target` does not hold the cancelling
## status.
func sure_against(target: Combatant) -> bool:
	if not sure:
		return false
	if cancelled_by == &"" or target == null:
		return true
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	return statuses == null or statuses.stacks(cancelled_by) == 0


## A copy of `base` (a battlefield's status) that also grants what `field` says. The copy keeps
## the same id, so a held copy is found, cured and saved as the original is. `base` itself is
## never changed, because a status is a shared resource.
static func granted(base: StatusEffect, field: BattlefieldMechanism) -> StatusEffect:
	var copy: StatusEffect = base.duplicate() as StatusEffect
	copy.grants_sure_hit = field.sure_hit
	copy.grants_hit_tags = field.hit_tags.duplicate()
	copy.cancelled_by = field.cancelled_by
	return copy
