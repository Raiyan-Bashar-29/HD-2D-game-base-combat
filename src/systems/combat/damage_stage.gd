class_name DamageStage
extends Resource
## One step of a damage formula. Subclass it, override `apply`, and list it in a `DamageFormula`.
##
## A STAGE CHANGES THE RUNNING RESULT AND NOTHING ELSE. It reads the request, writes the result,
## and draws any randomness from the `rng` it is handed and never from the global one, so a
## seeded resolution is the same every time. A stage that needs no randomness draws none.
##
## OWNS: nothing. The base does nothing, so an unconfigured stage in a list is harmless.
## MUST NOT: touch Vitals, Flags or the bus, or keep state between hits.


func apply(_request: DamageRequest, _result: DamageResult, _rng: RandomNumberGenerator) -> void:
	pass
