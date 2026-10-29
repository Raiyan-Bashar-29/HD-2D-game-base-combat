class_name VarianceStage
extends DamageStage
## Spreads a hit evenly within `spread` either side, so two identical swings rarely match.
##
## Like the crit stage it always draws once, so the number of draws per hit is fixed.
##
## OWNS: the variance step.
## MUST NOT: draw from anything but the `rng` it is handed.

## 0.1 means 90% to 110%. Zero switches variance off but still draws.
@export var spread: float = 0.1


func apply(_request: DamageRequest, result: DamageResult, rng: RandomNumberGenerator) -> void:
	result.amount *= rng.randf_range(1.0 - spread, 1.0 + spread)
