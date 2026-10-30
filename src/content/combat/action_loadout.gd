class_name ActionLoadout
extends Resource
## What turns the player into a real-time fighter (C3.4): who they are in a fight, and what
## they can do. `[combat] action/loadout` in `project.godot` names the `.tres`; empty means the
## game has no field combat, and the player stays exactly as upstream built them.
##
## IN PLAIN WORDS: `fighter` is the same `CombatantDef` a party member uses in a turn-based
## battle (stats, side, weaknesses), so hp lost in the field is the hp the battle starts with,
## when the ids agree. `moves` is the attack chain, the dodge and the skill slots.
##
## OWNS: the pairing of one fighter definition with one move set.
## MUST NOT: build anything. `ActionHost.equip` does that.

@export var fighter: CombatantDef
@export var moves: MoveSet
## What happens when the player falls (C3.8). Null means `DefeatRule.Kind.RESPAWN_AT_ENTRY`.
@export var defeat_rule: DefeatRule
## How the fighter's ATB gauge fills, for the hybrid formula (C4.2). Null means no gauge: a pure
## action game has none.
@export var atb: AtbRules
## What the hybrid's field menu offers (C4.3): SKILL and ITEM commands, filed into categories as
## in a turn-based battle. Attack is a button and the field has no fleeing, so other kinds are
## reported as problems.
@export var commands: Array[BattleCommand] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if fighter == null:
		found.append("%s has no fighter" % context)
	else:
		found.append_array(fighter.problems("%s fighter" % context))
	if moves == null:
		found.append("%s has no moves" % context)
	else:
		found.append_array(moves.problems("%s moves" % context))
	if atb != null:
		found.append_array(atb.problems("%s atb" % context))
	for i: int in commands.size():
		var command: BattleCommand = commands[i]
		if command == null:
			found.append("%s has an empty command slot %d" % [context, i])
			continue
		found.append_array(command.problems("%s command %d" % [context, i]))
		if command.kind != BattleCommand.Kind.SKILL and command.kind != BattleCommand.Kind.ITEM:
			found.append("%s command %d is not a SKILL or an ITEM, which the field cannot use" % [context, i])
	return found
