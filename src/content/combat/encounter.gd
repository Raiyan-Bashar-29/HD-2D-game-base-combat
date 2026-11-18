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

enum TurnOrder { ROUNDS, CTB, ATB }

@export var enemies: Array[CombatantDef] = []
@export var turn_order: TurnOrder = TurnOrder.ROUNDS
## For ATB (C10.30): the CTB ticks a second of real time is worth. A fighter of speed 1 waits
## 100 ticks, so 50 gives it a turn every two seconds.
@export var atb_ticks_per_second: float = 50.0
## Above 0, hitting a foe's weakness earns one more turn, up to this many in a row (C8.1).
@export var weakness_extra_turns: int = 0
## True makes a SWAP free: the one coming in takes the swapping fighter's turn at once, once a
## turn (C8.22c). False spends the turn, and the one coming in waits for its own.
@export var free_swaps: bool = false
## Foes held back (C8.22a): when every foe on the field is down, the next `wave` of these join,
## until none are left. The battle is won only when the last of them falls.
@export var reinforcements: Array[CombatantDef] = []
@export var wave: int = 1
@export var can_flee: bool = true
@export_range(0.0, 1.0, 0.01) var flee_chance: float = 1.0
## The music for the fight, played when it opens; the area's own music comes back when it
## closes. Empty keeps the field's music playing throughout (C2.12).
@export var music: AudioStream = null

@export_group("On win")
## Given to every party member standing at the end of a won battle.
@export var experience: int = 0
## Added to `experience` for each foe that arrived as a reinforcement (C8.23).
@export var reinforcement_experience: int = 0
## Item ids added to the player's inventory on a win, one each. An item that does not fit is
## left behind and reported, `Inventory.add`'s all-or-nothing rule.
@export var loot: Array[StringName] = []
## Loot that is rolled on a win, on top of `loot` (C7.2). Each enemy's own `loot_table` is
## rolled too. Null means none.
@export var loot_table: LootTable
## What losing this battle does (C10.2): the members get up with the rule's `revive_fraction` and
## the rule's `kind` is carried out once the screen closes (the area entered again, the latest save
## loaded, or play going on). Null keeps the template's default: everyone stands up at 1 hp.
@export var defeat_rule: DefeatRule


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if id == &"":
		found.append("%s has no id" % resource_path)
	if experience < 0:
		found.append("%s gives negative experience" % where)
	if enemies.is_empty():
		found.append("%s has no enemies" % where)
	for enemy: CombatantDef in enemies:
		if enemy == null:
			found.append("%s lists an empty enemy" % where)
		else:
			found.append_array(enemy.problems(where))
	if loot_table != null:
		found.append_array(loot_table.problems(where))
	return found
