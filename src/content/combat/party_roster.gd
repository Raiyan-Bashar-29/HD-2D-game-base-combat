class_name PartyRoster
extends Resource
## Every fighter who could ever join the party, as one file a game names in `project.godot`
## (`[combat] party/roster`). `Party` picks the active line-up from it; `BattleHost` builds from it.
##
## A PROJECT SETTING, NOT A NODE FIELD, so the composition root (`game_root.tscn`) names no
## content, and a stripped template, whose `data/` is gone, has simply no party.
##
## OWNS: the list of possible members.
## MUST NOT: hold who is active or how far anyone has grown. `Party` does, in `Flags`.

@export var members: Array[CombatantDef] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for member: CombatantDef in members:
		if member == null:
			found.append("%s lists an empty member" % context)
		else:
			found.append_array(member.problems(context))
	return found
