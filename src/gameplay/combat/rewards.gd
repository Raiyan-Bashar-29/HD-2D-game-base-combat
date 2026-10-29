class_name Rewards
extends RefCounted
## What a won battle gives, and the record of it the screen shows: experience to every party
## member still standing, and the encounter's loot into the player's inventory.
##
## GIVEN ONCE, ON WON ONLY. A loss or a flight gives nothing; the battle screen asks once, when
## it first sees the outcome.
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
	var given := Rewards.new()
	if battle.outcome() != Battle.Outcome.WON or encounter == null:
		return given
	given.experience = encounter.experience
	for fighter: Combatant in battle.party:
		var def: CombatantDef = battle.defs.get(fighter.combatant_id, null)
		if def == null or Vitals.of(fighter.get_parent()).is_defeated():
			continue
		if Party.gain(def, encounter.experience) > 0:
			given.levelled.append(fighter.combatant_id)
	for item_id: StringName in encounter.loot:
		if inventory != null and inventory.add(item_id, 1):
			given.items.append(item_id)
		else:
			given.left_behind.append(item_id)
	return given
