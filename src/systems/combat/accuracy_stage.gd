class_name AccuracyStage
extends DamageStage
## Whether the hit lands at all: `base_accuracy` plus the attacker's `accuracy` stat, minus the
## defender's `evasion` stat, is the chance out of 1 (C2.15). A miss sets `missed`, zeroes the
## amount, and `DamageFormula.resolve` runs no stage after it.
##
## IN PLAIN WORDS: with the defaults (accuracy 1, nobody evasive) every hit lands, exactly as
## before this stage existed. Give a fighter `evasion` 0.25 and about one hit in four misses it.
##
## A CERTAIN HIT DRAWS NOTHING. When the chance is 1 or more, or the request is `sure_hit`, no
## random number is drawn, so a game with no evasion replays every seeded fight it had before
## this stage was added. Below 1 it always draws once, hit or miss, the crit stage's rule.
##
## OWNS: the hit-or-miss roll.
## MUST NOT: draw from anything but the `rng` it is handed, or draw when the hit is certain.

@export var base_accuracy: float = 1.0
@export var accuracy_stat: StringName = &"accuracy"
@export var evasion_stat: StringName = &"evasion"


func apply(request: DamageRequest, result: DamageResult, rng: RandomNumberGenerator) -> void:
	if request.sure_hit:
		return
	var chance: float = base_accuracy
	if request.attacker != null:
		chance += request.attacker.value(accuracy_stat)
	if request.defender != null:
		chance -= request.defender.value(evasion_stat)
	if chance >= 1.0:
		return
	if rng.randf() >= chance:
		result.missed = true
		result.amount = 0.0
