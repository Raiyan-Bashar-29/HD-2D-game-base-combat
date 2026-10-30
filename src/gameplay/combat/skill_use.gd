class_name SkillUse
extends RefCounted
## What using a skill does, in one place, so every formula agrees: the turn-based `Battle`,
## C3's real-time fighter and C4's hybrid all call these three functions.
##
## IN PLAIN WORDS: `affordable` asks "can the user pay for this?", `pay` takes the cost, and
## `apply` does the skill to each target: its power, each of its effects, `hits` times over, then
## rolls its statuses once per target.
##
## THE CALLER DECIDES WHO AND WHEN. Checking a target is legal, spending an item and pushing a
## CTB turn back are the caller's, because each formula has its own rules for them.
##
## OWNS: the meaning of `power`, `hits`, `effects` and `statuses` when a skill lands.
## MUST NOT: choose targets, check timing or turns, or draw anything.


## True when `user` can pay `skill`'s cost from its own pools. A free skill is always affordable.
static func affordable(user: Combatant, skill: Skill) -> bool:
	if skill.cost <= 0:
		return true
	var vitals: Vitals = _vitals(user)
	return vitals != null and vitals.current(skill.cost_pool) >= skill.cost


## Takes the cost. Call `affordable` first: this does not check.
static func pay(user: Combatant, skill: Skill) -> void:
	if skill.cost > 0:
		_vitals(user).change(skill.cost_pool, -skill.cost)


## Does `skill` to every one of `targets`.
static func apply(user: Combatant, skill: Skill, targets: Array[Combatant],
		rng: RandomNumberGenerator) -> void:
	for target: Combatant in targets:
		for i: int in maxi(1, skill.hits):
			_strike(user, skill, target, rng)
		# Statuses roll once per target, not once per hit, so a flurry is not a poison machine.
		var statuses: StatusSet = StatusSet.of(target.get_parent())
		if statuses == null:
			continue
		for status: StatusEffect in skill.statuses:
			if rng.randf() < skill.status_chance:
				statuses.apply(status)


## One landing of the skill on one target: the plain power first, then each effect in order.
static func _strike(user: Combatant, skill: Skill, target: Combatant,
		rng: RandomNumberGenerator) -> void:
	if skill.power > 0.0:
		user.hit(target, skill.power, skill.element, rng)
	elif skill.power < 0.0:
		# Negative power is the original way to write a heal: straight to the pool, no defence.
		_vitals(target).change(target.damage_pool, roundi(-skill.power))
	for effect: SkillEffect in skill.effects:
		if effect != null:
			_effect(user, skill, target, effect, rng)


static func _effect(user: Combatant, skill: Skill, target: Combatant, effect: SkillEffect,
		rng: RandomNumberGenerator) -> void:
	var vitals: Vitals = _vitals(target)
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	match effect.kind:
		SkillEffect.Kind.DAMAGE:
			user.hit(target, effect.amount, skill.element, rng)
		SkillEffect.Kind.HEAL:
			vitals.change(target.damage_pool, roundi(effect.amount))
		SkillEffect.Kind.RESTORE:
			vitals.change(effect.pool, roundi(effect.amount))
		SkillEffect.Kind.DRAIN:
			# Measure what the target really lost (a nearly-dead target gives back less), then
			# hand the user its share.
			var before: int = vitals.current(target.damage_pool)
			user.hit(target, effect.amount, skill.element, rng)
			var taken: int = before - vitals.current(target.damage_pool)
			if taken > 0:
				_vitals(user).change(user.damage_pool, roundi(taken * effect.fraction))
		SkillEffect.Kind.CURE:
			if statuses != null:
				statuses.cure(effect.status_id)
		SkillEffect.Kind.DISPEL:
			if statuses != null:
				statuses.cure_tagged(effect.tag)
		SkillEffect.Kind.REVIVE:
			# Only the fallen are revived; a standing target is left alone (revive refuses).
			var back: int = roundi(vitals.maximum(target.damage_pool) * effect.amount)
			vitals.revive(maxi(1, back))


static func _vitals(fighter: Combatant) -> Vitals:
	return Vitals.of(fighter.get_parent())
