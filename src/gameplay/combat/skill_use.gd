class_name SkillUse
extends RefCounted
## What using a skill does, in one place, so every formula agrees: the turn-based `Battle`,
## C3's real-time fighter and C4's hybrid all call these three functions.
##
## IN PLAIN WORDS: `affordable` asks "can the user pay for this?", `pay` takes the cost, and
## `apply` does the skill to each target: its power, each of its effects, `hits` times over, then
## rolls its statuses once per target.
##
## WHAT ANSWERS A HIT LIVES HERE TOO (C2.15). A target holding a REFLECT status sends a skill
## with the matching tag back to its user, inside `apply`. `counter` is the other answer: the
## caller asks for it after a plain attack lands, because only the caller knows it WAS a plain
## attack and not a skill.
##
## THE CALLER DECIDES WHO AND WHEN. Checking a target is legal, spending an item and pushing a
## CTB turn back are the caller's, because each formula has its own rules for them.
##
## OWNS: the meaning of `power`, `hits`, `effects` and `statuses` when a skill lands, and the
## COUNTER and REFLECT reactions.
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
	for aimed: Combatant in targets:
		# A reflecting target sends the whole skill, statuses and all, back at the user.
		var target: Combatant = _bounce(user, skill, aimed, rng)
		for i: int in maxi(1, skill.hits):
			_strike(user, skill, target, rng)
		# Statuses roll once per target, not once per hit, so a flurry is not a poison machine.
		var statuses: StatusSet = StatusSet.of(target.get_parent())
		if statuses == null:
			continue
		for status: StatusEffect in skill.statuses:
			if rng.randf() < skill.status_chance:
				statuses.apply(status, rng)


## `defender` strikes back at `attacker` with a plain hit when it holds a COUNTER status, the
## attack `landed` (a miss is not answered), both are standing, and the defender is not asleep
## or stunned. Rolls `reaction_chance` only when it is below 1. True when it struck back.
static func counter(attacker: Combatant, defender: Combatant, landed: DamageResult,
		rng: RandomNumberGenerator) -> bool:
	if landed == null or landed.missed:
		return false
	if _vitals(attacker).is_defeated() or _vitals(defender).is_defeated():
		return false
	var statuses: StatusSet = StatusSet.of(defender.get_parent())
	if statuses == null or statuses.blocker(StatusEffect.Block.SKIP_TURN) != &"":
		return false
	var stance: StatusEffect = statuses.reactor(StatusEffect.Reaction.COUNTER)
	if stance == null or not _fires(stance, rng):
		return false
	defender.hit(attacker, 0.0, &"", rng)
	Events.countered.emit(defender.combatant_id, attacker.combatant_id)
	return true


## Who `skill` really lands on when aimed at `target`: the user, if the target is standing,
## holds a REFLECT status whose tag the skill carries, and the roll succeeds; else the target.
## A skill used on oneself never bounces.
static func _bounce(user: Combatant, skill: Skill, target: Combatant,
		rng: RandomNumberGenerator) -> Combatant:
	if target == user or _vitals(target).is_defeated():
		return target
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	var mirror: StatusEffect = statuses.reactor(StatusEffect.Reaction.REFLECT) if statuses != null else null
	if mirror == null or not skill.tags.has(mirror.reflect_tag) or not _fires(mirror, rng):
		return target
	Events.skill_reflected.emit(target.combatant_id, user.combatant_id, skill.id)
	return user


## A reaction at chance 1 always fires and draws nothing; below 1 it draws once.
static func _fires(status: StatusEffect, rng: RandomNumberGenerator) -> bool:
	return status.reaction_chance >= 1.0 or rng.randf() < status.reaction_chance


## One landing of the skill on one target: the plain power first, then each effect in order.
static func _strike(user: Combatant, skill: Skill, target: Combatant,
		rng: RandomNumberGenerator) -> void:
	if skill.power > 0.0:
		user.hit(target, skill.power, skill.element, rng, skill.sure_hit)
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
			user.hit(target, effect.amount, skill.element, rng, skill.sure_hit)
		SkillEffect.Kind.HEAL:
			vitals.change(target.damage_pool, roundi(effect.amount))
		SkillEffect.Kind.RESTORE:
			vitals.change(effect.pool, roundi(effect.amount))
		SkillEffect.Kind.DRAIN:
			# Measure what the target really lost (a nearly-dead target gives back less), then
			# hand the user its share.
			var before: int = vitals.current(target.damage_pool)
			user.hit(target, effect.amount, skill.element, rng, skill.sure_hit)
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
