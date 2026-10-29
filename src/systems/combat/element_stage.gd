class_name ElementStage
extends DamageStage
## Scales a hit by the defender's resistance to its element: amount x (1 - resist_<element>).
##
## One number covers every affinity: 0 is neutral, 0.5 resists, 1 is immune, -0.5 is weak, and
## above 1 absorbs (the result goes negative, which is a heal; see `DamageResult`). Resistance is
## a stat, so a status or a ring changes it as a modifier and nothing here needs to know.
##
## OWNS: the element step.
## MUST NOT: know which elements exist. An element is a free StringName.

@export var resist_prefix: String = "resist_"


func apply(request: DamageRequest, result: DamageResult, _rng: RandomNumberGenerator) -> void:
	if request.element.is_empty() or request.defender == null:
		return
	result.amount *= 1.0 - request.defender.value(StringName(resist_prefix + request.element))
