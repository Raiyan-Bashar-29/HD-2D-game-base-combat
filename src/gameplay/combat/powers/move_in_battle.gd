class_name MoveInBattle
extends RefCounted
## A power's move in a turn-based battle (C10.25).
##
## IN PLAIN WORDS: a battle never plays moves, so a power whose damage lives in its `move` (a
## converted special: its skill only pays, or puts a status on the user) would do nothing there.
## `land` makes the move's hits land instead: `hits` times its `power`, with its element (or the
## worn weapon's), on each foe the power was aimed at, else on the first standing foe. Each goes
## through `Combatant.hit`, so defence, passives and weakness all apply. A power whose skill
## already deals damage keeps to its skill, so nothing lands twice.
##
## OWNS: turning a move's numbers into battle hits.
## MUST NOT: play the move, or pay for the power (`PowerUse` does).


## True when `power` has a move that strikes and no skill that already deals damage.
static func needed(power: Power) -> bool:
	if power == null or power.move == null or power.move.power <= 0.0:
		return false
	if power.skill == null:
		return true
	if power.skill.power > 0.0:
		return false
	return not power.skill.effects.any(func(effect: SkillEffect) -> bool:
		return effect != null and (effect.kind == SkillEffect.Kind.DAMAGE or effect.kind == SkillEffect.Kind.DRAIN))


## Lands `power`'s move on the foes among `aimed`, else on the first standing foe of `user`.
static func land(user: Combatant, power: Power, aimed: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var foes: Array[Combatant] = aimed.filter(func(f: Combatant) -> bool: return _foe(user, f))
	if foes.is_empty() and Battle.running != null:
		for fighter: Combatant in Battle.running.party + Battle.running.enemies:
			if _foe(user, fighter):
				foes.append(fighter)
				break
	var move: ActionMove = power.move
	var element: StringName = user.strike_element(move.element)
	for foe: Combatant in foes:
		for i: int in maxi(1, move.hits):
			var result: DamageResult = user.hit(foe, move.power, element, rng)
			if result != null and not result.missed and not result.blocked:
				Weakness.strike(foe, [element])


static func _foe(user: Combatant, other: Combatant) -> bool:
	if other == null or not is_instance_valid(other) or other == user or not user.can_target(other, FactionTable.Target.ENEMY):
		return false
	var vitals: Vitals = Vitals.of(other.get_parent())
	return vitals != null and not vitals.is_defeated()
