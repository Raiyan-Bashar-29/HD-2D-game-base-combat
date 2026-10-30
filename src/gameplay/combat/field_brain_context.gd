class_name FieldBrainContext
extends BrainContext
## A brain's questions answered in the field, in real time (C4.8): an ally that nobody controls
## uses its `BattleBrain` to spend its ATB on skills and items through `FieldCommands`, the same
## rules the player's command menu follows.
##
## IN PLAIN WORDS: only skills and items exist here. Attacking is a button in the field, and
## there is no defending or fleeing, so those kinds are never allowed and there is no fallback.
## A command is allowed when `FieldCommands.refusal` has no reason (a full enough gauge, the
## mp or the item, no status forbidding it, someone to aim at). Its targets are everyone in
## reach, so a brain entry's LOWEST_HP rule can pick the most hurt ally to heal.
##
## OWNS: translating the four questions into `FieldCommands` calls, and `fighting`.
## MUST NOT: move the body. `PartyFollower` walks; this only chooses commands.


func allows(command: BattleCommand) -> bool:
	if command == null or actor == null:
		return false
	if command.kind != BattleCommand.Kind.SKILL and command.kind != BattleCommand.Kind.ITEM:
		return false
	return FieldCommands.refusal(actor, command) == FieldCommands.Reason.NONE


func targets_for(command: BattleCommand) -> Array[Combatant]:
	return FieldCommands.candidates(actor, command)


func act(command: BattleCommand, targets: Array[Combatant]) -> bool:
	return FieldCommands.use(actor, command, rng, targets)


## True while a standing foe of `actor` is within `FieldCommands.REACH`. An ally thinks only
## then, so it does not cast its heals on a quiet walk through town.
func fighting() -> bool:
	if actor == null or not actor.is_inside_tree():
		return false
	var probe := BattleCommand.new()
	probe.kind = BattleCommand.Kind.SKILL
	probe.skill = Skill.new()
	probe.skill.target = FactionTable.Target.ENEMY
	return not FieldCommands.candidates(actor, probe).is_empty()
