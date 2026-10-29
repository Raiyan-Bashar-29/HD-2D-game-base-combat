class_name StatSheet
extends RefCounted
## One combatant's numbers: base values, plus the modifiers currently applied to them.
##
## THE ORDER IS FIXED, AND IT IS THE WHOLE FORMULA: (base + every ADD) x every MULTIPLY, unless
## an OVERRIDE exists, in which case the most recently added override is the value. A fixed order
## is what makes "+5 then x2" and "x2 then +5" the same character, so a game never debugs the
## order its equipment happened to load in. MULTIPLY stacks by product: two x1.5 are x2.25. A game
## that wants additive percentages authors one ADD on a `<stat>_pct` stat and reads it itself.
##
## IT IS PURE, NOT A NODE AND NOT SAVED. A sheet is rebuilt from what a combatant IS (its base
## stats, its equipment, its statuses), and those are what get saved, each by its own owner. A
## saved sheet would be a second copy of the truth that could disagree with the first.
##
## OWNS: base values, the modifiers applied to them, and the value that results.
## MUST NOT: know which stats exist, read Flags, emit on the bus, or decide who may modify it.

var _base: Dictionary[StringName, float] = {}
var _modifiers: Array[StatModifier] = []


func set_base(stat: StringName, amount: float) -> void:
	_base[stat] = amount


## The value before any modifier. Zero for a stat nobody has mentioned.
func base(stat: StringName) -> float:
	return _base.get(stat, 0.0)


## Refuses a modifier with problems rather than holding one nothing could remove.
func add(modifier: StatModifier) -> bool:
	if modifier == null or not modifier.problems().is_empty():
		return false
	_modifiers.append(modifier)
	return true


## Removes everything one source added, and says how many that was.
func remove_from(source: StringName) -> int:
	var before: int = _modifiers.size()
	_modifiers = _modifiers.filter(func(each: StatModifier) -> bool: return each.source != source)
	return before - _modifiers.size()


## The number every other system reads. See the header for the order.
func value(stat: StringName) -> float:
	var total: float = base(stat)
	var factor: float = 1.0
	var override_found: bool = false
	var override_value: float = 0.0
	for modifier: StatModifier in _modifiers:
		if modifier.stat != stat:
			continue
		match modifier.op:
			StatModifier.Op.ADD:
				total += modifier.value
			StatModifier.Op.MULTIPLY:
				factor *= modifier.value
			StatModifier.Op.OVERRIDE:
				override_found = true
				override_value = modifier.value
	return override_value if override_found else total * factor
