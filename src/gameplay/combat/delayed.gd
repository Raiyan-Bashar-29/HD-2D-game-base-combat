class_name Delayed
extends RefCounted
## Late outcomes (C8.15a): a hit that lands when a status runs out, and a ledger status that
## holds what happens to its holder and settles it once.
##
## IN PLAIN WORDS:
## - A status with `late_power` is a delayed hit. Nothing happens while it counts down (in
##   turns or seconds). When it runs out, whoever put it there hits the holder with that
##   power, through the usual damage formula. Curing it first stops the hit. If the caster is
##   gone by then, nothing lands.
## - A status marked `ledger` holds every hit and heal on its holder's damage pool: none of
##   them changes the pool while it is held. When the status ends, by time or by a cure, the
##   sum is applied in one go.
##
## OWNS: what `late_power` and `ledger` do, and the sum a ledger holds.
## MUST NOT: count a status down. `StatusSet` does, and tells `ended` when one is gone.

const SUM: StringName = &"ledger_sum"


## The `StatusSet` `statuses` has just taken `effect` off. `by` is who applied it; `ran_out`
## is false for a cure.
static func ended(statuses: StatusSet, effect: StatusEffect, by: StringName, ran_out: bool) -> void:
	var holder: Combatant = Combatant.of(statuses.get_parent())
	if holder == null:
		return
	if effect.ledger and not _ledger(statuses):
		var sum: int = statuses.get_meta(SUM, 0)
		statuses.remove_meta(SUM)
		Vitals.of(statuses.get_parent()).change(holder.damage_pool, sum)
		# The held hits land now, so they are announced now: a log or a number shows them (C8.17).
		if sum < 0:
			Events.combatant_damaged.emit(holder.combatant_id, by, -sum, false)
	if ran_out:
		Contagion.passed(statuses, effect, by)
	if ran_out and effect.late_power > 0.0 and statuses.is_inside_tree():
		var caster: Combatant = Combatant.find(statuses.get_tree(), by)
		if caster != null:
			var rng := RandomNumberGenerator.new()
			caster.hit(holder, effect.late_power, effect.late_element, rng, true)


## Notes `change` to `fighter`'s damage pool on its ledger. True when a ledger took it, so
## the caller must not change the pool.
static func bank(fighter: Combatant, change: int) -> bool:
	var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if fighter != null else null
	if statuses == null or not _ledger(statuses):
		return false
	var sum: int = statuses.get_meta(SUM, 0)
	statuses.set_meta(SUM, sum + change)
	return true


## Heals `fighter` by `amount`, or notes it on its ledger.
static func heal(fighter: Combatant, amount: int) -> void:
	if not bank(fighter, amount):
		Vitals.of(fighter.get_parent()).change(fighter.damage_pool, amount)


static func _ledger(statuses: StatusSet) -> bool:
	for effect: StatusEffect in statuses.held():
		if effect.ledger:
			return true
	return false
