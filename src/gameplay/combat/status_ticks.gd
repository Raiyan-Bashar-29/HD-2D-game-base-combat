class_name StatusTicks
extends RefCounted
## Status ticks that land like hits (C10.10), moved out of `StatusSet` for its budget.
##
## IN PLAIN WORDS: a status marked `tick_as_hit` whose tick takes from the holder's damage pool
## is turned into a hit by whoever applied it, and handed to `Combatant.receive`. So its
## `damage_taken` grows it, invincibility and barriers stop it, a survival passive keeps the
## holder up, a ledger banks it, it wakes a sleeper, and the log and the numbers hear of it. A
## tick that fills, or names another pool, or a status without the mark, stays a plain change.
##
## OWNS: turning one tick into a hit.
## MUST NOT: decide when a status ticks (`StatusSet` does) or resolve the hit (`Combatant`).

const TAKEN: StringName = &"damage_taken"


## Lands a tick of `amount` (below 0 hurts) of `effect` on `holder` as a hit by `by`. False,
## doing nothing, when the tick is a plain pool change.
static func land(holder: Node, effect: StatusEffect, amount: int, by: StringName) -> bool:
	var fighter: Combatant = Combatant.of(holder)
	if not effect.tick_as_hit or amount >= 0 or fighter == null or effect.tick_pool != fighter.damage_pool:
		return false
	var result := DamageResult.new()
	result.amount = -amount * maxf(0.0, 1.0 + fighter.sheet.value(TAKEN))
	result.tags.assign(effect.tags)
	fighter.receive(result, by)
	return true
