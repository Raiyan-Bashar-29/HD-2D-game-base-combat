extends TestCase
## `StatSheet` and `StatModifier`: the fixed order, removal by source, and what is refused.
##
## OWNS: assertions about how a sheet turns base values and modifiers into a value.
## MUST NOT: name a game's stats. The names here are made up for the case, which is the point:
## the base knows no stat names at all.


func run() -> void:
	plan(14)
	_base_values()
	_order_is_add_then_multiply()
	_override_wins_and_the_latest_override_wins()
	_removal_is_by_source()
	_a_modifier_with_problems_is_refused()


func _base_values() -> void:
	var sheet := StatSheet.new()
	equal("an unmentioned stat is zero", sheet.value(&"stat_a"), 0.0)
	sheet.set_base(&"stat_a", 10.0)
	equal("a base value is the value with no modifiers", sheet.value(&"stat_a"), 10.0)


## +5 then x2 and x2 then +5 must be the same character: (10 + 5) x 2 = 30 either way.
func _order_is_add_then_multiply() -> void:
	var first := StatSheet.new()
	first.set_base(&"stat_a", 10.0)
	first.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 5.0, &"source_one"))
	first.add(StatModifier.of(&"stat_a", StatModifier.Op.MULTIPLY, 2.0, &"source_two"))
	var second := StatSheet.new()
	second.set_base(&"stat_a", 10.0)
	second.add(StatModifier.of(&"stat_a", StatModifier.Op.MULTIPLY, 2.0, &"source_two"))
	second.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 5.0, &"source_one"))
	equal("add then multiply is (base + add) x factor", first.value(&"stat_a"), 30.0)
	equal("the order things were added in does not matter", second.value(&"stat_a"), 30.0)
	second.add(StatModifier.of(&"stat_a", StatModifier.Op.MULTIPLY, 1.5, &"source_three"))
	equal("multipliers stack by product", second.value(&"stat_a"), 45.0)
	equal("a modifier touches only its own stat", second.value(&"stat_b"), 0.0)


func _override_wins_and_the_latest_override_wins() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(&"stat_a", 10.0)
	sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 5.0, &"source_one"))
	sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.OVERRIDE, 1.0, &"source_two"))
	equal("an override is the value", sheet.value(&"stat_a"), 1.0)
	sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.OVERRIDE, 3.0, &"source_three"))
	equal("the most recent override wins", sheet.value(&"stat_a"), 3.0)
	sheet.remove_from(&"source_three")
	equal("removing it uncovers the one before", sheet.value(&"stat_a"), 1.0)


func _removal_is_by_source() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(&"stat_a", 10.0)
	sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 5.0, &"source_one"))
	sheet.add(StatModifier.of(&"stat_b", StatModifier.Op.ADD, 2.0, &"source_one"))
	sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 1.0, &"source_two"))
	equal("a source's modifiers all leave together", sheet.remove_from(&"source_one"), 2)
	equal("and only that source's", sheet.value(&"stat_a"), 11.0)
	equal("the base is untouched by removal", sheet.base(&"stat_a"), 10.0)


func _a_modifier_with_problems_is_refused() -> void:
	var sheet := StatSheet.new()
	equal("a modifier with no source is refused",
		sheet.add(StatModifier.of(&"stat_a", StatModifier.Op.ADD, 5.0, &"")), false)
	equal("and changes nothing", sheet.value(&"stat_a"), 0.0)
