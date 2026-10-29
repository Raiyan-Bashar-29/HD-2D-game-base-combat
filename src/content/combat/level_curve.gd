class_name LevelCurve
extends Resource
## How much experience each level needs, and what each level adds to a fighter's base stats.
## Authored once per class or per character, on its `CombatantDef`.
##
## THE TEMPLATE DEFAULT IS A POWER CURVE: reaching level L needs `base * (L - 1) ^ exponent`
## experience in total, so level 1 needs none and each step costs more than the last. A game
## wanting a hand-made table subclasses this and overrides `exp_for`.
##
## GROWTH IS A DELTA PER LEVEL, added to the definition's base stats `(level - 1)` times. A
## sword or a status still layers on top as a modifier (C1.2), so levels never fight equipment.
##
## OWNS: the experience thresholds and the per-level growth.
## MUST NOT: hold anyone's level or experience. `Party` keeps those, in `Flags`.

@export var base: int = 20
@export var exponent: float = 1.6
@export var max_level: int = 99
## Added to each named base stat once per level above 1.
@export var growth: Dictionary[StringName, float] = {}


## Total experience needed to stand at `level`.
func exp_for(level: int) -> int:
	if level <= 1:
		return 0
	return roundi(base * pow(level - 1, exponent))


## The level `total_exp` reaches, capped at `max_level`.
func level_for(total_exp: int) -> int:
	var level: int = 1
	while level < max_level and total_exp >= exp_for(level + 1):
		level += 1
	return level


## `stats` with `level`'s growth added: the base sheet a fighter of that level starts from.
func grown(stats: Dictionary[StringName, float], level: int) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = stats.duplicate()
	for stat: StringName in growth:
		out[stat] = out.get(stat, 0.0) + growth[stat] * (level - 1)
	return out
