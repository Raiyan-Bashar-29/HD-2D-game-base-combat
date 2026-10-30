class_name BattleBrainContext
extends BrainContext
## A brain's questions answered by a turn-based `Battle` (C4.8): the current actor, the battle's
## seeded rng, and `Battle.allows`, `targets_for` and `act`. What `BattleAi.take_turn` used to
## ask `Battle` directly, moved behind `BrainContext` so the field can answer the same way.
##
## OWNS: translating the four questions into `Battle` calls.
## MUST NOT: change the battle except through `Battle.act`.

var battle: Battle


func _init(fight: Battle) -> void:
	super._init(fight.current(), fight.rng)
	battle = fight


## A status must allow it (silence stops SKILL); DEFEND is always open; FLEE only where the
## battle allows fleeing; a skill or item only when its cost can be paid.
func allows(command: BattleCommand) -> bool:
	if command == null or not battle.allows(command):
		return false
	match command.kind:
		BattleCommand.Kind.DEFEND:
			return true
		BattleCommand.Kind.FLEE:
			return battle.can_flee
	return command.skill == null or SkillUse.affordable(actor, command.skill)


func targets_for(command: BattleCommand) -> Array[Combatant]:
	return battle.targets_for(command)


func act(command: BattleCommand, targets: Array[Combatant]) -> bool:
	return battle.act(command, targets)


## With nothing allowed: attack the first foe there is, or defend. DEFEND is always legal, so a
## running battle never stalls on a brain that has nothing to offer.
func fallback() -> bool:
	var attack := BattleCommand.new()
	var legal: Array[Combatant] = battle.targets_for(attack)
	if not legal.is_empty():
		return battle.act(attack, [legal[0]])
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	return battle.act(guard, [])
