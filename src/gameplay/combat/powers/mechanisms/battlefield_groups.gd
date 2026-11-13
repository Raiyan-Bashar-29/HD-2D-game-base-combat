class_name BattlefieldGroups
extends RefCounted
## Which of a battlefield's effects reach a fighter (C6.9a, C6.9b), moved here from
## `BattlefieldRun` in C6.9g to keep that file in its budget.
##
## IN PLAIN WORDS: each `BattlefieldEffect` names a group (the caster, the caster's side, the other
## side, everyone, everyone but the caster). `effects_for` lists the effects whose group a fighter
## is in. With `immunity`, an effect is left out when the fighter holds a status tagged with one of
## that effect's `immune_tags`.
##
## OWNS: matching a fighter to the effects' groups, and the immune-tag test.
## MUST NOT: change statuses, modifiers or bodies, or decide who is inside the field.

## The effects of `field`, cast by `me`, whose group `other` is in; with `immunity`, those it is
## immune to by tag are left out.
static func effects_for(me: Combatant, field: BattlefieldMechanism, other: Combatant,
		immunity: bool = true) -> Array[BattlefieldEffect]:
	var out: Array[BattlefieldEffect] = []
	if me == null or field == null:
		return out
	for effect: BattlefieldEffect in field.effects:
		var mine: bool = other == me
		var match_found: bool = false
		match effect.who:
			BattlefieldEffect.Who.CASTER:
				match_found = mine
			BattlefieldEffect.Who.CASTER_SIDE:
				match_found = mine or me.can_target(other, FactionTable.Target.ALLY)
			BattlefieldEffect.Who.OTHER_SIDE:
				match_found = not mine and me.can_target(other, FactionTable.Target.ENEMY)
			BattlefieldEffect.Who.EVERYONE:
				match_found = true
			BattlefieldEffect.Who.EVERYONE_BUT_CASTER:
				match_found = not mine
		if match_found and not (immunity and _holds_any(other, effect.immune_tags)):
			out.append(effect)
	return out


# True when `other` holds a status tagged with one of `tags`.
static func _holds_any(other: Combatant, tags: Array[StringName]) -> bool:
	var statuses: StatusSet = StatusSet.of(other.get_parent()) if not tags.is_empty() else null
	if statuses == null:
		return false
	for held: StatusEffect in statuses.held():
		for tag: StringName in tags:
			if held.tags.has(tag):
				return true
	return false
