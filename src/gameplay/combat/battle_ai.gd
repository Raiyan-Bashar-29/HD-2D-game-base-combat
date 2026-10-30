class_name BattleAi
extends RefCounted
## Plays one choice for a fighter nobody controls, from a `BattleBrain`. The same call serves an
## enemy's turn, a party member on auto-battle (C5) and the hybrid's allies in the field (C4.8).
##
## IN PLAIN WORDS: every entry on the brain whose conditions pass and which the fighter may use
## now competes by weight; one is drawn and aimed by its target rule. WHERE the fight is does not
## matter here: `decide` asks a `BrainContext` what is allowed, whom it could hit and to do it.
## `take_turn` is the turn-based case, a `BattleBrainContext` over a `Battle`; a field ally
## passes a `FieldBrainContext` (C4.8).
##
## IT ONLY EVER CALLS `BrainContext.act`, so the AI can do nothing a player could not: an
## illegal pick is impossible because candidates come from `targets_for`, and a cost the actor
## cannot pay rules its entry out before the draw.
##
## SEEDED. Every draw comes from the context's rng, a battle's own, so a seeded battle replays
## exactly.
##
## OWNS: evaluating entries and picking a target by rule.
## MUST NOT: change the fight except through `BrainContext.act`, or read input.


## The current actor of `battle` chooses and acts. False only when nothing legal could be done,
## which a running battle never leaves: DEFEND is always legal.
static func take_turn(battle: Battle, brain: BattleBrain) -> bool:
	if battle.current() == null:
		return false
	return decide(BattleBrainContext.new(battle), brain)


## The context's actor draws one allowed entry from `brain` and acts on it, or falls back when
## none is allowed. False when it did nothing.
static func decide(context: BrainContext, brain: BattleBrain) -> bool:
	if context == null or context.actor == null:
		return false
	var allowed: Array[BrainEntry] = []
	var total: float = 0.0
	if brain != null:
		for entry: BrainEntry in brain.entries:
			if _allowed(context, entry):
				allowed.append(entry)
				total += entry.weight
	if total > 0.0:
		var roll: float = context.rng.randf() * total
		for entry: BrainEntry in allowed:
			roll -= entry.weight
			if roll < 0.0:
				return context.act(entry.command, _aim(context, entry))
	return context.fallback()


static func _allowed(context: BrainContext, entry: BrainEntry) -> bool:
	if entry == null or entry.command == null or entry.weight <= 0.0:
		return false
	if not FlagQuery.passes(entry.condition_flag, entry.condition_test, entry.condition_value):
		return false
	var actor: Combatant = context.actor
	if entry.below_fraction > 0.0:
		var vitals: Vitals = Vitals.of(actor.get_parent())
		var ceiling: int = vitals.maximum(entry.below_pool)
		if ceiling <= 0 or float(vitals.current(entry.below_pool)) >= entry.below_fraction * ceiling:
			return false
	# Statuses (silence), cost, ATB and whether the formula has this kind at all (C2.14, C4.8).
	if not context.allows(entry.command):
		return false
	var kind: BattleCommand.Kind = entry.command.kind
	# DEFEND and FLEE aim at nobody, so they need no target to be allowed.
	if kind == BattleCommand.Kind.DEFEND or kind == BattleCommand.Kind.FLEE:
		return true
	var legal: Array[Combatant] = context.targets_for(entry.command)
	if entry.target_rule == BrainEntry.TargetRule.SELF:
		return legal.has(actor)
	return not legal.is_empty()


static func _aim(context: BrainContext, entry: BrainEntry) -> Array[Combatant]:
	var legal: Array[Combatant] = context.targets_for(entry.command)
	var aimed: Array[Combatant] = []
	if legal.is_empty():
		return aimed
	# An all-targets skill takes everyone it could land on; the rule picks only one.
	if entry.command.skill != null and entry.command.skill.scope == Skill.Scope.ALL \
			and entry.command.kind != BattleCommand.Kind.ATTACK:
		return legal
	match entry.target_rule:
		BrainEntry.TargetRule.SELF:
			aimed.append(context.actor)
		BrainEntry.TargetRule.RANDOM:
			aimed.append(legal[context.rng.randi_range(0, legal.size() - 1)])
		BrainEntry.TargetRule.LOWEST_HP:
			var weakest: Combatant = legal[0]
			for fighter: Combatant in legal:
				if _hp(fighter) < _hp(weakest):
					weakest = fighter
			aimed.append(weakest)
		_:
			aimed.append(legal[0])
	return aimed


static func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(fighter.damage_pool)
