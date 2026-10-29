class_name DamageResult
extends RefCounted
## What one resolved hit came to. Stages write it in order; `total()` is what a target loses.
##
## A NEGATIVE AMOUNT IS A HEAL. An element the target absorbs (resistance above 1) turns the hit
## around, and the pipeline does not clamp it away: absorbing is a formula decision, so a game
## that wants a floor of zero lists a stage that clamps.
##
## OWNS: the running amount, whether it was critical, and the stages that ran, in order.
## MUST NOT: apply itself to anybody. That is the caller's, through `Vitals.change`.

var amount: float = 0.0
var critical: bool = false
var element: StringName = &""
## Each stage's class name, in the order it ran, so a test or a combat log can show the working.
var stages_run: Array[StringName] = []


## The whole number a target loses. Rounded, never truncated, so 9.6 is 10 and not 9.
func total() -> int:
	return roundi(amount)
