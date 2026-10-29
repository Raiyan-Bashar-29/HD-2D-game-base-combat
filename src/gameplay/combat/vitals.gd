class_name Vitals
extends Node
## One combatant's pools (hp, mp, or whatever a game names) and whether it is defeated.
##
## THE CURRENT VALUE LIVES IN `Flags`, THE MAXIMUM IN A `StatSheet`. That is `Attributes`' and
## `Equipment`'s rule, and it buys three things for nothing: the value is saved, a new game
## resets it, and a gate, a quest step or a dialogue line can read `vital/<who>/<pool>` with no
## code. The maximum is a stat because a sword, a level and a curse all change it, and those are
## modifiers on a sheet (C1.2); storing it would be a second copy that could disagree.
##
## AN UNSET POOL IS FULL. A combatant nobody has hurt has no flag at all, so a fresh character
## and a new game both start at their maximum without anybody writing one.
##
## DEFEAT IS AN EDGE, NOT A STATE ANNOUNCEMENT. `combatant_defeated` fires on the step that takes
## the defeat pool from above zero to zero, and never again until a revive. Hitting a defeated
## combatant changes nothing, so a listener counting defeats never counts one twice.
##
## OWNS: the current value of each pool, clamping it to 0..maximum, and the defeat edge.
## MUST NOT: compute damage, know where damage came from, choose what defeat means, or own the
## sheet's modifiers. Damage is C1.4's; what defeat does is a formula's (C2, C3) or a game's.

const PREFIX: String = "vital/"
## The maximum of pool `hp` is the sheet's stat `max_hp`.
const MAX_PREFIX: String = "max_"

## Unique per combatant, and it namespaces every flag this component writes. Equipment's rule:
## a second combatant that keeps the default shares the first one's pools.
@export var owner_id: StringName = &"player"
## The pool whose reaching zero is defeat.
@export var defeat_pool: StringName = &"hp"

## Where maxima come from. A `Combatant` (C1.6) supplies its own; until then each `Vitals` has one.
var sheet: StatSheet = StatSheet.new()

## True only inside `revive()`, the one caller allowed to lift the defeat pool off zero.
var _reviving: bool = false


## Scans by type, as `Inventory.of` and `Equipment.of` do, so a renamed node still resolves.
static func of(who: Node) -> Vitals:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: Vitals = child as Vitals
		if found != null:
			return found
	return null


## The flag an author writes into a gate: `vital/<owner>/<pool>`.
func key(pool: StringName) -> StringName:
	return StringName("%s%s/%s" % [PREFIX, owner_id, pool])


func maximum(pool: StringName) -> int:
	return maxi(0, roundi(sheet.value(StringName(MAX_PREFIX + String(pool)))))


func current(pool: StringName) -> int:
	return clampi(Flags.get_int(key(pool), maximum(pool)), 0, maximum(pool))


## Negative to hurt, positive to heal. Returns the value after.
func change(pool: StringName, delta: int) -> int:
	return set_to(pool, current(pool) + delta)


## Every path into a pool comes through here, so the clamp, the signal and the defeat edge cannot
## be bypassed. Returns the value after, which may differ from the one asked for.
func set_to(pool: StringName, value: int) -> int:
	var before: int = current(pool)
	var ceiling: int = maximum(pool)
	var after: int = clampi(value, 0, ceiling)
	if pool == defeat_pool and before == 0 and after > 0 and not _reviving:
		return before
	if after == before:
		return after
	Flags.set_flag(key(pool), after)
	Events.vitals_changed.emit(owner_id, pool, after, ceiling)
	if pool == defeat_pool and after == 0:
		Events.combatant_defeated.emit(owner_id)
	return after


func is_defeated() -> bool:
	return current(defeat_pool) == 0 and maximum(defeat_pool) > 0


## THE ONLY WAY BACK FROM ZERO. Healing a defeated combatant is refused by `set_to`, so a heal
## spell aimed at a fallen ally does nothing until something decides it may revive them.
func revive(amount: int) -> bool:
	if not is_defeated():
		return false
	_reviving = true
	set_to(defeat_pool, maxi(1, amount))
	_reviving = false
	Events.combatant_revived.emit(owner_id)
	return true

