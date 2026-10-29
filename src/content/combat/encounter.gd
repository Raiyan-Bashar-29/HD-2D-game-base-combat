class_name Encounter
extends ContentEntry
## One fight the field can start: the enemy group, whether the party may run, and which turn
## order it uses. `data/encounters/<name>.tres`, id `encounter/<name>`, `EncounterDb` finds it.
## The field asks for one by id with `Events.encounter_requested`.
##
## THE TURN ORDER IS AN ENUM, NOT A SCHEDULER. `TurnScheduler` is systems and content may not
## depend on it, so the encounter names one and `BattleSetup` (gameplay) builds it. Adding a
## third scheduler adds a value here and a line there.
##
## OWNS: the shape of one encounter.
## MUST NOT: build anything, or know who the party is.

enum TurnOrder { ROUNDS, CTB }

@export var enemies: Array[CombatantDef] = []
@export var turn_order: TurnOrder = TurnOrder.ROUNDS
@export var can_flee: bool = true
@export_range(0.0, 1.0, 0.01) var flee_chance: float = 1.0
## The music cue for the fight, an `Audio` id. Empty keeps the field's music.
@export var music: StringName = &""


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if id == &"":
		found.append("%s has no id" % resource_path)
	if enemies.is_empty():
		found.append("%s has no enemies" % where)
	for enemy: CombatantDef in enemies:
		if enemy == null:
			found.append("%s lists an empty enemy" % where)
		else:
			found.append_array(enemy.problems(where))
	return found
