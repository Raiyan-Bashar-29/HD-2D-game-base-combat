class_name Rewards
extends RefCounted
## What a won battle gives, and the record of it the screen shows: experience to every party
## member still standing, and the encounter's loot into the player's inventory.
##
## GIVEN ONCE, ON WON ONLY. A loss or a flight gives nothing; the battle screen asks once, when
## it first sees the outcome.
##
## A FIELD KILL (C3.8) rewards through `give`, which needs no battle: the real-time formula has
## none, and the rule is the same one.
##
## OWNS: the template's reward rule, and the summary of one grant.
## MUST NOT: choose the encounter, draw anything, or decide what losing means.

## Experience each standing member received.
var experience: int = 0
## Ids of members who gained at least one level.
var levelled: Array[StringName] = []
## Item ids added, and those that did not fit.
var items: Array[StringName] = []
var left_behind: Array[StringName] = []


static func grant(battle: Battle, encounter: Encounter, inventory: Inventory) -> Rewards:
	if battle.outcome() != Battle.Outcome.WON or encounter == null:
		return Rewards.new()
	var standing: Array[CombatantDef] = []
	for fighter: Combatant in battle.party:
		var def: CombatantDef = battle.defs.get(fighter.combatant_id, null)
		if def != null and not Vitals.of(fighter.get_parent()).is_defeated():
			standing.append(def)
	return give(encounter.experience, encounter.loot, standing, inventory)


## The reward itself, with no battle (C3.8): `experience` to each of `members` (the caller
## leaves out the fallen), and each of `loot` into `inventory`. A field kill calls this.
static func give(experience: int, loot: Array[StringName], members: Array[CombatantDef],
		inventory: Inventory) -> Rewards:
	var given := Rewards.new()
	given.experience = experience
	for def: CombatantDef in members:
		if Party.gain(def, experience) > 0:
			given.levelled.append(def.combatant_id)
	for item_id: StringName in loot:
		if inventory != null and inventory.add(item_id, 1):
			given.items.append(item_id)
		else:
			given.left_behind.append(item_id)
	return given
