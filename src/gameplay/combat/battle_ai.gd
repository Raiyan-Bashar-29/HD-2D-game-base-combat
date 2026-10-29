class_name BattleAi
extends RefCounted
## Plays one turn of a `Battle` for its current actor from a `BattleBrain`. The same call serves
## an enemy, a party member on auto-battle (C5) and the hybrid's uncontrolled allies (C4).
##
## IT ONLY EVER CALLS `Battle.act`, so the AI can do nothing a player could not: an illegal pick
## is impossible because candidates come from `Battle.targets_for`, and a cost the actor cannot
## pay rules its entry out before the draw.
##
## SEEDED. Every draw comes from the battle's own rng, so a seeded battle replays exactly.
##
## OWNS: evaluating entries and picking a target by rule.
## MUST NOT: change the battle except through `act`, or read input.


## Chooses and acts. False only when nothing legal could be done, which a running battle never
## leaves: DEFEND is always legal.
static func take_turn(battle: Battle, brain: BattleBrain) -> bool:
	var actor: Combatant = battle.current()
	if actor == null:
		return false
	var allowed: Array[BrainEntry] = []
	var total: float = 0.0
	if brain != null:
		for entry: BrainEntry in brain.entries:
			if _allowed(battle, actor, entry):
				allowed.append(entry)
				total += entry.weight
	if total > 0.0:
		var roll: float = battle.rng.randf() * total
		for entry: BrainEntry in allowed:
			roll -= entry.weight
			if roll < 0.0:
				return battle.act(entry.command, _aim(battle, actor, entry))
	return _fallback(battle)


static func _allowed(battle: Battle, actor: Combatant, entry: BrainEntry) -> bool:
	if entry == null or entry.command == null or entry.weight <= 0.0:
		return false
	if not FlagQuery.passes(entry.condition_flag, entry.condition_test, entry.condition_value):
		return false
	var vitals: Vitals = Vitals.of(actor.get_parent())
	if entry.below_fraction > 0.0:
		var ceiling: int = vitals.maximum(entry.below_pool)
		if ceiling <= 0 or float(vitals.current(entry.below_pool)) >= entry.below_fraction * ceiling:
			return false
	var command: BattleCommand = entry.command
	match command.kind:
		BattleCommand.Kind.DEFEND:
			return true
		BattleCommand.Kind.FLEE:
			return battle.can_flee
	if command.skill != null and command.skill.cost > 0 \
			and vitals.current(command.skill.cost_pool) < command.skill.cost:
		return false
	var legal: Array[Combatant] = battle.targets_for(command)
	if entry.target_rule == BrainEntry.TargetRule.SELF:
		return legal.has(actor)
	return not legal.is_empty()


static func _aim(battle: Battle, actor: Combatant, entry: BrainEntry) -> Array[Combatant]:
	var legal: Array[Combatant] = battle.targets_for(entry.command)
	var aimed: Array[Combatant] = []
	if legal.is_empty():
		return aimed
	match entry.target_rule:
		BrainEntry.TargetRule.SELF:
			aimed.append(actor)
		BrainEntry.TargetRule.RANDOM:
			aimed.append(legal[battle.rng.randi_range(0, legal.size() - 1)])
		BrainEntry.TargetRule.LOWEST_HP:
			var weakest: Combatant = legal[0]
			for fighter: Combatant in legal:
				if _hp(fighter) < _hp(weakest):
					weakest = fighter
			aimed.append(weakest)
		_:
			aimed.append(legal[0])
	return aimed


static func _fallback(battle: Battle) -> bool:
	var attack := BattleCommand.new()
	var legal: Array[Combatant] = battle.targets_for(attack)
	if not legal.is_empty():
		return battle.act(attack, [legal[0]])
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	return battle.act(guard, [])


static func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(fighter.damage_pool)
