class_name CombatDifficulty
extends RefCounted
## Which difficulty is on, and what it does to a hit (C5.4a).
##
## IN PLAIN WORDS: the flag `combat/difficulty` names a `Difficulty` by id. It is a flag, so it is
## saved with the game and each save keeps its own; `choose` sets it. With no flag, the player's
## setting does (`CombatSettings.DIFFICULTY`, C5.3b, which drops the flag when changed), and before
## that is installed the project setting `combat/difficulty/default`; with none of them,
## or with the flag set empty (`choose(&"")`, which turns even a default off), there is none and
## every hit is what the formula made it. `Combatant.hit` calls `scale` once the
## formula has resolved a hit: a hit the difficulty's side lands on another side is multiplied by
## 1 plus `dealt`, one it takes from another side by 1 plus `taken`, never below 0.
##
## OWNS: which difficulty is on, and scaling a resolved hit by it.
## MUST NOT: change a fighter's stats or hp, or resolve a hit (the formula does).

const FLAG: StringName = &"combat/difficulty"
const SETTING: String = "combat/difficulty/default"


## The difficulty on now, or null for none.
static func current() -> Difficulty:
	# Only a missing flag falls back to the default, so choosing none really is none (C8.27a).
	var id: String = CombatSettings.difficulty(str(ProjectSettings.get_setting(SETTING, "")))
	if Flags.has_flag(FLAG):
		id = Flags.get_string(FLAG)
	return DifficultyDb.of(StringName(id)) if id != "" else null


## Turns on the difficulty `id`, or none with an empty id. False, changing nothing, for an id no
## difficulty file has.
static func choose(id: StringName) -> bool:
	if id != &"" and DifficultyDb.of(id) == null:
		return false
	Flags.set_flag(FLAG, String(id))
	return true


## Scales `result`, a hit `attacker` landed on `target`, by the difficulty on now.
static func scale(attacker: Combatant, target: Combatant, result: DamageResult) -> void:
	if result == null or result.missed or result.amount <= 0.0 or attacker == null or target == null:
		return
	var on: Difficulty = current()
	if on == null:
		return
	var dealing: bool = attacker.side() == on.side
	if dealing == (target.side() == on.side):
		return
	result.amount *= maxf(0.0, 1.0 + (on.dealt if dealing else on.taken))
