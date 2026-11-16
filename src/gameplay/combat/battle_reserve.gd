class_name BattleReserve
extends RefCounted
## The reserve line in a turn-based battle (C8.3): party members waiting off the field.
##
## IN PLAIN WORDS: a party member may spend its turn on SWAP, aimed at a standing member of
## `Battle.reserve`. The one coming in takes its place in the line-up and in the turn order; the
## one going out waits in the reserve, keeping its hp and statuses, and can be swapped back
## later. A guest (a helper or a summon) never swaps, and a fallen reserve member cannot come in.
##
## OWNS: who may come in, and the exchange itself.
## MUST NOT: decide whose turn it is, or end the battle. `Battle` does both.


## The reserve members who could come in now: those still standing.
static func ready(battle: Battle) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for one: Combatant in battle.reserve:
		var vitals: Vitals = Vitals.of(one.get_parent())
		if vitals != null and not vitals.is_defeated():
			out.append(one)
	return out


## `out` steps back for `targets[0]`, a standing reserve member. False, changing nothing, when
## `out` is not a party member of its own, or there is not exactly one such target.
static func swap(battle: Battle, out: Combatant, targets: Array[Combatant]) -> bool:
	var slot: int = battle.party.find(out)
	if slot < 0 or battle.guests.has(out.combatant_id) or targets.size() != 1:
		return false
	var coming: Combatant = targets[0]
	if not ready(battle).has(coming):
		return false
	battle.reserve.erase(coming)
	battle.reserve.append(out)
	battle.party[slot] = coming
	battle.scheduler.leave(out.combatant_id)
	battle.admit(coming)
	Events.party_swapped.emit(out.combatant_id, coming.combatant_id)
	return true
