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
## The party members who walk with this fighter in the field (C4.7), each a loadout of its own.
## When `Party`'s line-up has been set, only the active ones come along. Switching hands the
## player's body to one of them: their moves, gauge and commands come from their own loadout.
## A companion's own `companions` are ignored: only the lead's list counts.
## Typed `Resource`, not `ActionLoadout`: a script whose exported array names its own class
## keeps itself alive and leaks at exit (seen at boot). `problems()` reports a non-loadout.
@export var companions: Array[Resource] = []
## How this member fights while walking as a party follower (C4.9): when it notices a foe, how
## far it strays from its place in the line, and which moves it opens with. A move that is the
## first of `moves.attack_chain` plays the whole chain. Null means it never swings: it keeps its
## place, and only its `BattleBrain` acts (C4.8). Unused while the player controls this member.
@export var field_brain: ActionBrain


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
	if field_brain != null:
		found.append_array(field_brain.problems("%s field_brain" % context))
	for i: int in companions.size():
		var mate: ActionLoadout = companions[i] as ActionLoadout
		if mate == null or mate == self:
			found.append("%s has an empty, self-naming or non-loadout companion %d" % [context, i])
		else:
			found.append_array(mate.problems("%s companion %d" % [context, i]))
	return found
