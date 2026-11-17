class_name Foresight
extends RefCounted
## Foresight in the damage path (C6.10): a resolved hit may be rewritten before it lands.
##
## IN PLAIN WORDS: `Combatant.hit` hands each resolved hit here before the target receives it.
## - The attacker's foresight with `force` turns its miss into a sure hit, spending a rewrite.
## - The target's foresight with `observe` makes a skill or move it has already been hit by
##   miss (`striking` names what is hitting now; `SkillUse` and `Hurtbox` set it).
## - The target's foresight with `dodge` turns the landing hit into a miss, spending a rewrite.
## A heal, or a hit between fighters who are not foes, is never touched.
##
## OWNS: the order the rewrites are asked in, and `striking`.
## MUST NOT: count rewrites (`ForesightRun` does) or apply a hit (`Combatant.receive` does).

## What is hitting now: a skill's id, a key for a field move, or empty for anything else.
static var striking: StringName = &""


## `result` was resolved from `request` for `attacker` on `target`: the hit to land instead.
static func rewrite(attacker: Combatant, target: Combatant, request: DamageRequest,
		result: DamageResult, rng: RandomNumberGenerator) -> DamageResult:
	if not attacker.can_target(target, FactionTable.Target.ENEMY):
		return result
	var mine: ForesightRun = run_of(attacker)
	if result.missed and mine != null and mine.spend(false):
		request.sure_hit = true
		result = attacker.resolving_formula().resolve(request, rng)
	var theirs: ForesightRun = run_of(target)
	if result.missed or result.amount <= 0.0 or theirs == null:
		return result
	if theirs.seen(striking) or theirs.spend(true):
		result.missed = true
	else:
		theirs.note(striking)
	return result


## The foresight running in `fighter`'s kits, or null.
static func run_of(fighter: Combatant) -> ForesightRun:
	var powers: PowerSet = PowerSet.of(fighter.get_parent()) if fighter != null else null
	if powers == null:
		return null
	for running: PowerExecutor in powers.running():
		if running is ForesightRun:
			return running as ForesightRun
	return null
