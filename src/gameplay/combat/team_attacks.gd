class_name TeamAttacks
extends RefCounted
## Team attacks in a turn-based battle (C8.2): allies who follow up, and team techs.
##
## IN PLAIN WORDS:
## - FOLLOW-UPS. When a fighter's plain ATTACK lands, or its one-target skill hurts a foe (C8.21), each other standing fighter on its side who
##   holds a FOLLOW_UP status (and is not asleep or stunned, and rolls its `reaction_chance`)
##   strikes the same foe at once: its status's `counter_move`, or one plain hit. A follow-up
##   never sets off another one. `Battle` calls `after_attack` where it used to call only
##   `SkillUse.counter`, so the counter still comes first.
## - TEAM TECHS. A power whose mechanism is a `TeamMechanism` is ready only while every partner it
##   names stands on the user's side, awake, and (for an all-out) every standing foe is broken.
##   `PowerUse` refuses it with `Reason.TEAM` otherwise; `TeamRun` does the striking.
##
## OWNS: who follows up, and whether a team tech is ready.
## MUST NOT: run outside a battle, or decide what a hit does (that is `Combatant.hit`'s).


## A plain ATTACK by `actor` on `target` landed as `landed` (null or missed when it did not):
## the target's counter first, then the follow-ups. Returns how many allies followed up.
static func after_attack(actor: Combatant, target: Combatant, landed: DamageResult,
		rng: RandomNumberGenerator) -> int:
	SkillUse.counter(actor, target, landed, rng)
	if landed == null or landed.missed:
		return 0
	return follow_ups(actor, target, rng)


## `actor` uses `skill` on `targets` in a battle (C8.21): `SkillUse.apply`, then, when it was a
## one-target skill at a foe that really hurt it, the follow-ups. `Battle` calls this in place of
## `SkillUse.apply`.
static func use_skill(actor: Combatant, skill: Skill, targets: Array[Combatant],
		rng: RandomNumberGenerator, boost: int) -> void:
	var target: Combatant = targets[0] if skill.scope == Skill.Scope.ONE and targets.size() == 1 else null
	var before: int = _hp(target)
	SkillUse.apply(actor, skill, targets, rng, boost)
	if target != null and target != actor and actor.can_target(target, FactionTable.Target.ENEMY) \
			and _hp(target) < before:
		follow_ups(actor, target, rng)


## Each other standing, awake fighter on `actor`'s side holding a FOLLOW_UP status that rolls true
## strikes `target`, once. A follow-up never sets off another. Returns how many did.
static func follow_ups(actor: Combatant, target: Combatant, rng: RandomNumberGenerator) -> int:
	var battle: Battle = Battle.running
	if battle == null:
		return 0
	var count: int = 0
	for ally: Combatant in side_of(battle, actor):
		if ally == actor or not _awake(ally) or _down(target) or not ally.can_target(target, FactionTable.Target.ENEMY):
			continue
		var stance: StatusEffect = StatusSet.of(ally.get_parent()).reactor(StatusEffect.Reaction.FOLLOW_UP)
		if stance == null or not (stance.reaction_chance >= 1.0 or rng.randf() < stance.reaction_chance):
			continue
		SkillUse.answer(ally, target, stance.counter_move, rng)
		Events.followed_up.emit(ally.combatant_id, target.combatant_id)
		count += 1
	return count


## True when `user` may use the team tech `team` now: in a battle, every named partner stands
## on its side and is awake, and with `needs_broken` every standing foe is broken.
static func ready(user: Combatant, team: TeamMechanism) -> bool:
	var battle: Battle = Battle.running
	if battle == null or team == null:
		return false
	var mine: Array[Combatant] = side_of(battle, user)
	for partner_id: StringName in team.partners:
		var partner: Combatant = _find(mine, partner_id)
		if partner == null or partner == user or not _awake(partner):
			return false
	if team.needs_broken:
		var broken: StringName = Weakness.broken_status().id
		for foe: Combatant in (battle.enemies if battle.party.has(user) else battle.party):
			if not _down(foe) and StatusSet.of(foe.get_parent()).stacks(broken) == 0:
				return false
	return true


## Who strikes in `user`'s team tech `team`: the user first, then each named partner; with none
## named, every standing, awake ally on its side.
static func members(user: Combatant, team: TeamMechanism) -> Array[Combatant]:
	var found: Array[Combatant] = [user]
	var battle: Battle = Battle.running
	if battle == null:
		return found
	var mine: Array[Combatant] = side_of(battle, user)
	if team.partners.is_empty():
		for ally: Combatant in mine:
			if ally != user and _awake(ally):
				found.append(ally)
		return found
	for partner_id: StringName in team.partners:
		var partner: Combatant = _find(mine, partner_id)
		if partner != null and partner != user and _awake(partner):
			found.append(partner)
	return found


## The fighters on `fighter`'s side of `battle`: its party or its enemies; empty when in neither.
static func side_of(battle: Battle, fighter: Combatant) -> Array[Combatant]:
	if battle.party.has(fighter):
		return battle.party
	if battle.enemies.has(fighter):
		return battle.enemies
	return []


static func _find(side: Array[Combatant], id: StringName) -> Combatant:
	for one: Combatant in side:
		if one.combatant_id == id:
			return one
	return null


# Standing and not losing its turns (asleep, stunned, broken).
static func _awake(fighter: Combatant) -> bool:
	if _down(fighter):
		return false
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	return statuses == null or statuses.blocker(StatusEffect.Block.SKIP_TURN) == &""


static func _hp(fighter: Combatant) -> int:
	var vitals: Vitals = Vitals.of(fighter.get_parent()) if fighter != null else null
	return vitals.current(fighter.damage_pool) if vitals != null else 0


static func _down(fighter: Combatant) -> bool:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	return vitals == null or vitals.is_defeated()
