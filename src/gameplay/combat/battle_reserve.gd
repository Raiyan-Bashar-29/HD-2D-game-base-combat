class_name BattleReserve
extends RefCounted
## The reserve line in a turn-based battle (C8.3): party members waiting off the field.
##
## IN PLAIN WORDS: a party member may spend its turn on SWAP, aimed at a standing member of
## `Battle.reserve`. The one coming in takes its place in the line-up and in the turn order; the
## one going out waits in the reserve, keeping its hp and statuses, and can be swapped back
## later. A guest (a helper or a summon) never swaps, and a fallen reserve member cannot come in.
## STEPPING IN (C8.22a): when a party member falls, the first standing reserve member takes its
## slot at once (`refill`, after every action), so a fight is lost only when nobody is left.
## `refill` then lets the encounter's held-back foes arrive (`BattleSetup.reinforce`).
##
## FREE SWAP (C8.22c): with the encounter's `free_swaps`, `Battle` hands the swapping fighter's
## turn to the one coming in, once a turn. That once-a-turn free swap may instead trade a party
## member WAITING for its turn (C8.26, `free_swap`, offered by `waiting_pairs`): nobody's turn is
## spent, and the one whose turn it is acts on. `all_out` says whether a side has anyone left.
##
## OWNS: who may come in, the exchange itself, and whether a side has anyone left standing.
## MUST NOT: decide whose turn it is, or end the battle. `Battle` does both.


## A SWAP or a ROW by `actor` (C8.22b): the swap below, or a step between the rows.
static func move(battle: Battle, actor: Combatant, kind: BattleCommand.Kind, targets: Array[Combatant]) -> bool:
	if kind == BattleCommand.Kind.ROW:
		return Rows.step(actor)
	return swap(battle, actor, targets)


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


## After an action: each fallen party member of its own gives its slot to the first standing
## reserve member, then the encounter's next wave of foes may arrive.
static func refill(battle: Battle) -> void:
	for slot: int in battle.party.size():
		var fallen: Combatant = battle.party[slot]
		var vitals: Vitals = Vitals.of(fallen.get_parent())
		if battle.guests.has(fallen.combatant_id) or vitals == null or not vitals.is_defeated():
			continue
		var standing: Array[Combatant] = ready(battle)
		if standing.is_empty():
			break
		battle.reserve.erase(standing[0])
		battle.reserve.append(fallen)
		battle.party[slot] = standing[0]
		battle.admit(standing[0])
		Events.party_swapped.emit(fallen.combatant_id, standing[0].combatant_id)
	BattleSetup.reinforce(battle)


## True when everyone on `side` is out of the fight, those named in `skip` aside: fallen,
## petrified (C8.7a), or obeying the other side (C6.11). `Battle` asks it to decide a winner.
static func all_out(side: Array[Combatant], skip: Array[StringName] = []) -> bool:
	for fighter: Combatant in side:
		if skip.has(fighter.combatant_id):
			continue
		var statuses: StatusSet = StatusSet.of(fighter.get_parent())
		var vitals: Vitals = Vitals.of(fighter.get_parent())
		if vitals != null and not vitals.is_defeated() and not (statuses != null \
				and (statuses.fallen() or statuses.obeyed() != &"")):
			return false
	return true


## A free swap for a waiting party member (C8.26): `out`, not the one whose turn it is, steps back
## for `coming` and no turn is spent. False, changing nothing, unless the encounter's free swaps
## are on, this turn's is unspent, and it is a party member's turn.
static func free_swap(battle: Battle, out: Combatant, coming: Combatant) -> bool:
	if not waiting_pairs(battle).has([out, coming]) or not swap(battle, out, [coming]):
		return false
	battle.free_swap_used = true
	return true


## Every [waiting member, reserve member] pair a free swap could trade now.
static func waiting_pairs(battle: Battle) -> Array[Array]:
	var pairs: Array[Array] = []
	var now: Combatant = battle.current()
	if not battle.free_swaps or battle.free_swap_used or now == null or not battle.party.has(now):
		return pairs
	for member: Combatant in battle.party:
		if member == now or battle.guests.has(member.combatant_id):
			continue
		for coming: Combatant in ready(battle):
			pairs.append([member, coming])
	return pairs
