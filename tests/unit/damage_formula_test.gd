extends TestCase
## The damage pipeline: each shipped stage, that the listed order is the order run, and that a
## seeded resolution is the same every time.
##
## OWNS: assertions about `DamageFormula`, `DamageRequest`, `DamageResult` and the four stages.
## MUST NOT: name a game's stats or elements. Every name here is the stage's default or made up.


func run() -> void:
	plan(23)
	_attack_against_defence()
	_element()
	_crit()
	_variance()
	_order_is_the_list_order()
	_seeded_is_deterministic()


func _sheet(values: Dictionary[StringName, float]) -> StatSheet:
	var sheet := StatSheet.new()
	for stat: StringName in values:
		sheet.set_base(stat, values[stat])
	return sheet


func _formula(stages: Array[DamageStage]) -> DamageFormula:
	var formula := DamageFormula.new()
	formula.stages = stages
	return formula


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _attack_against_defence() -> void:
	var formula := _formula([AttackDefenceStage.new()])
	var attacker := _sheet({&"attack": 10.0})
	equal("(30 + 10) x 100 / (100 + 100)",
		formula.resolve(DamageRequest.of(attacker, _sheet({&"defence": 100.0}), 30.0), _rng(1)).amount, 20.0)
	equal("no defence takes nothing",
		formula.resolve(DamageRequest.of(attacker, _sheet({}), 30.0), _rng(1)).amount, 40.0)
	var off := AttackDefenceStage.new()
	off.softness = 0.0
	equal("softness zero switches defence off",
		_formula([off]).resolve(DamageRequest.of(attacker, _sheet({&"defence": 100.0}), 30.0), _rng(1)).amount, 40.0)
	equal("null sheets read as zeroes",
		formula.resolve(DamageRequest.of(null, null, 30.0), _rng(1)).amount, 30.0)


func _element() -> void:
	var formula := _formula([ElementStage.new()])
	var attacker := _sheet({})
	equal("half resistance halves",
		formula.resolve(DamageRequest.of(attacker, _sheet({&"resist_kind_a": 0.5}), 20.0, &"kind_a"), _rng(1)).amount, 10.0)
	equal("negative resistance is a weakness",
		formula.resolve(DamageRequest.of(attacker, _sheet({&"resist_kind_a": -0.5}), 20.0, &"kind_a"), _rng(1)).amount, 30.0)
	equal("no element skips the stage",
		formula.resolve(DamageRequest.of(attacker, _sheet({&"resist_kind_a": 0.5}), 20.0), _rng(1)).amount, 20.0)
	equal("resistance above one absorbs: the total is a heal",
		formula.resolve(DamageRequest.of(attacker, _sheet({&"resist_kind_a": 2.0}), 20.0, &"kind_a"), _rng(1)).total(), -20)


func _crit() -> void:
	var always := CritStage.new()
	always.base_chance = 1.0
	var hit := _formula([always]).resolve(DamageRequest.of(_sheet({}), _sheet({}), 20.0), _rng(1))
	equal("a certain crit is critical", hit.critical, true)
	equal("and multiplies", hit.amount, 30.0)
	var never := CritStage.new()
	never.base_chance = 0.0
	var plain := _formula([never]).resolve(DamageRequest.of(_sheet({}), _sheet({}), 20.0), _rng(1))
	equal("an impossible crit is not critical", plain.critical, false)
	equal("and leaves the amount", plain.amount, 20.0)
	equal("the attacker's crit_chance stat adds to the chance",
		_formula([never]).resolve(DamageRequest.of(_sheet({&"crit_chance": 1.0}), _sheet({}), 20.0), _rng(1)).critical, true)


func _variance() -> void:
	var formula := _formula([VarianceStage.new()])
	var rng := _rng(7)
	var inside: bool = true
	for i: int in 200:
		var amount: float = formula.resolve(DamageRequest.of(null, null, 100.0), rng).amount
		inside = inside and amount >= 90.0 and amount <= 110.0
	equal("200 hits all land within 10% either side", inside, true)
	var flat := VarianceStage.new()
	flat.spread = 0.0
	equal("spread zero is exact", _formula([flat]).resolve(DamageRequest.of(null, null, 100.0), rng).amount, 100.0)


## (30 + 10) x 0.5 x 0.5 = 10, but (30 x 0.5 + 10) x 0.5 = 12.5: the list is the formula.
func _order_is_the_list_order() -> void:
	var request := DamageRequest.of(_sheet({&"attack": 10.0}),
		_sheet({&"defence": 100.0, &"resist_kind_a": 0.5}), 30.0, &"kind_a")
	var first := _formula([AttackDefenceStage.new(), ElementStage.new()]).resolve(request, _rng(1))
	var second := _formula([ElementStage.new(), AttackDefenceStage.new()]).resolve(request, _rng(1))
	equal("attack, then element", first.amount, 10.0)
	equal("element, then attack", second.amount, 12.5)
	var ran: Array[StringName] = [&"ElementStage", &"AttackDefenceStage"]
	equal("the result records the order the stages ran in", second.stages_run, ran)


func _seeded_is_deterministic() -> void:
	var formula := DamageFormula.standard()
	var request := DamageRequest.of(_sheet({&"attack": 12.0, &"crit_chance": 0.3}),
		_sheet({&"defence": 40.0, &"resist_kind_a": 0.25}), 25.0, &"kind_a")
	var once := formula.resolve(request, _rng(42))
	var again := formula.resolve(request, _rng(42))
	equal("the same seed gives the same amount", once.amount, again.amount)
	equal("and the same crit", once.critical, again.critical)
	equal("the standard formula runs all six shipped stages", once.stages_run.size(), 6)
	var gappy := _formula([null, AttackDefenceStage.new()])
	equal("a null in the list is skipped", gappy.resolve(DamageRequest.of(null, null, 5.0), _rng(1)).stages_run.size(), 1)
	var rounding := DamageResult.new()
	rounding.amount = 9.6
	equal("the total rounds", rounding.total(), 10)
