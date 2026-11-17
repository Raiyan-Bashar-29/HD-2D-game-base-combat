class_name RefreshRun
extends PowerExecutor
## Runs an M14 refresh (C6.12b) on one fighter. Its settings are a `RefreshMechanism`.
##
## IN PLAIN WORDS: using the power cuts the remaining cooldowns of the user (and its allies in
## reach, for ALLIES), rounded down to whole turns in a battle, fills the user's pool, and puts
## `speed` on each fighter refreshed. `rate` is how fast a fighter's cooldowns count down: 1
## plus its `cooldown_rate` stat, never below 0. `PowerSet` reads it.
##
## OWNS: carrying out one refresh, and what the `cooldown_rate` stat means.
## MUST NOT: hold a cooldown itself (`PowerSet.cut_cooldowns` does), or name a character.

const RATE: StringName = &"cooldown_rate"


func use(user: Combatant, _targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var refresh: RefreshMechanism = mechanism as RefreshMechanism
	var refreshed: Array[Combatant] = [user]
	if refresh.scope == RefreshMechanism.Scope.ALLIES:
		refreshed.append_array(SacrificeRun.side(user, refresh.radius))
	for fighter: Combatant in refreshed:
		var powers: PowerSet = PowerSet.of(fighter.get_parent())
		if powers != null and refresh.fraction > 0.0:
			powers.cut_cooldowns(0.0, refresh.fraction, not fighter.real_time)
		var statuses: StatusSet = StatusSet.of(fighter.get_parent())
		if refresh.speed != null and statuses != null:
			statuses.apply(refresh.speed, rng, user.combatant_id)
	var vitals: Vitals = Vitals.of(user.get_parent())
	if refresh.pool_gain > 0 and vitals != null:
		vitals.change(refresh.pool, refresh.pool_gain)


## How fast `fighter`'s cooldowns count down: 1 is normal, 1.3 is 30% faster.
static func rate(fighter: Combatant) -> float:
	return maxf(0.0, 1.0 + fighter.sheet.value(RATE)) if fighter != null else 1.0
