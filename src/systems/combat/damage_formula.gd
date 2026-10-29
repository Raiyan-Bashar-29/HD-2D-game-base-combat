class_name DamageFormula
extends Resource
## A damage formula IS its list of stages, run in order. A game changes the formula in data.
##
## THIS IS THE FORMULA-SWAP POINT C1 PROMISED. Turn-based, action and the hybrid all resolve hits
## through one of these; a game that wants "attack minus defence", no crits, or a stage of its
## own lists different stages in a `.tres`, and never edits `src/`. `standard()` is the template
## default, the four stages shipped beside this file, in the order most games mean.
##
## PURE AND SEEDED. `resolve` reads its request and its stages, draws only from the `rng` it is
## given, and returns a new result, so the same seed gives the same hit.
##
## OWNS: the order the stages run in.
## MUST NOT: apply the result, know who is hitting whom, or use the global random generator.

@export var stages: Array[DamageStage] = []


## The template default: attack against defence, then element, then crit, then variance.
static func standard() -> DamageFormula:
	var formula := DamageFormula.new()
	formula.stages = [AttackDefenceStage.new(), ElementStage.new(), CritStage.new(), VarianceStage.new()]
	return formula


func resolve(request: DamageRequest, rng: RandomNumberGenerator) -> DamageResult:
	var result := DamageResult.new()
	if request == null:
		return result
	result.amount = request.power
	result.element = request.element
	for stage: DamageStage in stages:
		if stage == null:
			continue
		stage.apply(request, result, rng)
		result.stages_run.append((stage.get_script() as Script).get_global_name())
	return result
