class_name AttackDefenceStage
extends DamageStage
## Adds the attacker's attack, then lets the defender's defence take a diminishing share.
##
## amount = (amount + attack) x softness / (softness + defence). Defence equal to `softness`
## halves a hit, twice that leaves a third, and no defence ever makes a hit zero, so the numbers
## never need a "minimum 1" patch. A game that wants plain subtraction lists its own stage.
##
## OWNS: the attack-against-defence step.
## MUST NOT: name a stat itself. The names are exports, so a game calls them what it likes.

@export var attack_stat: StringName = &"attack"
@export var defence_stat: StringName = &"defence"
## The defence that halves a hit. Zero or below switches defence off.
@export var softness: float = 100.0


func apply(request: DamageRequest, result: DamageResult, _rng: RandomNumberGenerator) -> void:
	if request.attacker != null:
		result.amount += request.attacker.value(attack_stat)
	if request.defender == null or softness <= 0.0:
		return
	var defence: float = maxf(0.0, request.defender.value(defence_stat))
	result.amount *= softness / (softness + defence)
