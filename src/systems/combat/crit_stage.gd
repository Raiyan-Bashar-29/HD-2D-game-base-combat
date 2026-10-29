class_name CritStage
extends DamageStage
## A chance at a bigger hit: `base_chance` plus the attacker's `crit_chance` stat, out of 1.
##
## It ALWAYS draws once, crit or not, so whether this hit was critical never shifts the random
## numbers every later stage and hit sees. That is what keeps a seeded fight replayable.
##
## OWNS: the crit roll and the crit multiplier.
## MUST NOT: draw from anything but the `rng` it is handed.

@export var base_chance: float = 0.05
@export var chance_stat: StringName = &"crit_chance"
@export var multiplier: float = 1.5


func apply(request: DamageRequest, result: DamageResult, rng: RandomNumberGenerator) -> void:
	var chance: float = base_chance
	if request.attacker != null:
		chance += request.attacker.value(chance_stat)
	if rng.randf() < chance:
		result.critical = true
		result.amount *= multiplier
