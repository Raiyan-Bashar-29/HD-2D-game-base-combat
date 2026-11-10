class_name DamageResult
extends RefCounted
## What one resolved hit came to. Stages write it in order; `total()` is what a target loses.
##
## A NEGATIVE AMOUNT IS A HEAL. An element the target absorbs (resistance above 1) turns the hit
## around, and the pipeline does not clamp it away: absorbing is a formula decision, so a game
## that wants a floor of zero lists a stage that clamps.
##
## OWNS: the running amount, whether it was critical, missed or blocked, its tags, and the stages that ran, in order.
## MUST NOT: apply itself to anybody. That is the caller's, through `Vitals.change`.

var amount: float = 0.0
var critical: bool = false
## True when the hit did not land at all (C2.15). The amount is then 0, and nothing is applied.
var missed: bool = false
var element: StringName = &""
## What kind of hit this is, beyond its element: the skill's own tags, and `sure_hit` for a hit
## that cannot miss (C6.6a). A barrier reads them to decide what gets through it.
var tags: Array[StringName] = []
## True when a barrier stopped the hit whole (C6.6a): it was nullified or absorbed, so it took
## nothing, chips no shield and pushes nobody.
var blocked: bool = false
## Each stage's class name, in the order it ran, so a test or a combat log can show the working.
var stages_run: Array[StringName] = []


## The whole number a target loses. Rounded, never truncated, so 9.6 is 10 and not 9.
func total() -> int:
	return roundi(amount)
