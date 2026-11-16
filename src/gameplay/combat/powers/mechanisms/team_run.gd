class_name TeamRun
extends PowerExecutor
## Runs a `TeamMechanism` (C8.2): the user and its partners strike every target in turn.
##
## IN PLAIN WORDS: `PowerUse` has already checked the tech is ready (`TeamAttacks.ready`). Each
## member, the user first, hits each target `hits` times; a landed hit counts against the
## target's weaknesses. Partners are pushed back in a CTB order. Outside a battle it does nothing.
##
## OWNS: the strikes of one team tech.
## MUST NOT: decide whether the tech is ready, or pay for it.


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var team: TeamMechanism = power.mechanism as TeamMechanism
	var battle: Battle = Battle.running
	if team == null or battle == null:
		return
	var members: Array[Combatant] = TeamAttacks.members(user, team)
	var ids: Array[StringName] = []
	for member: Combatant in members:
		ids.append(member.combatant_id)
		var element: StringName = member.strike_element(team.element)
		var keys: Array[StringName] = [element]
		keys.append_array(member.strike_tags())
		for target: Combatant in targets:
			for i: int in team.hits:
				var landed: DamageResult = member.hit(target, team.power, element, rng)
				if landed != null and not landed.missed:
					Weakness.strike(target, keys)
		if member != user and team.partner_delay > 0.0 and battle.scheduler is CtbScheduler:
			(battle.scheduler as CtbScheduler).delay_by(member.combatant_id, team.partner_delay)
	Events.team_attacked.emit(user.combatant_id, ids)
