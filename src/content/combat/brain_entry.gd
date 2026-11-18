class_name BrainEntry
extends Resource
## One thing a `BattleBrain` may choose: a command, how much it wants it, whom it aims at, and
## when it is allowed at all.
##
## TWO CONDITIONS, BOTH OPTIONAL. A flag test, the closed set `FlagQuery` already reads for
## dialogue and quests (so "after the bridge burns, the boss uses fire" is data), and the one
## thing a flag cannot say: the user's own pool below a fraction ("heal under half hp"). With
## `below_any_target` (C8.25) the pool test asks every target the command may aim at instead,
## so "heal whoever is under half" is data; pair it with LOWEST_HP to aim at the most hurt.
##
## OWNS: the shape of one choice.
## MUST NOT: evaluate itself. `BattleAi` (gameplay) does, because the pool test reads `Vitals`.

## How a ONE-target command picks among the legal targets. SELF aims at the user. WEAK (C10.19)
## aims at the first foe weak to what the command carries, else the first. THREAT (C10.28) aims
## at whoever has the most threat on the user's table, else the first.
enum TargetRule { FIRST, RANDOM, LOWEST_HP, SELF, WEAK, THREAT }

@export var command: BattleCommand
## Relative chance among the entries allowed this turn. Zero never fires.
@export var weight: float = 1.0
@export var target_rule: TargetRule = TargetRule.FIRST
## True passes over a target that would bounce the command's skill back (a REFLECT it carries
## the tag of, C10.19).
@export var avoids_reflect: bool = false
## Boost levels spent on the command when the user has them (C10.19). Zero never boosts.
@export var boost: int = 0
## True allows the entry only while a target it may aim at has a weakness it carries that the
## player has found (C10.19), so "use fire on what is weak to fire" is data.
@export var needs_weakness: bool = false

@export_group("Condition")
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
@export var condition_value: int = 0
## Allowed only while the user's `below_pool` is under this fraction of its maximum. Zero is off.
@export var below_pool: StringName = &"hp"
@export_range(0.0, 1.0, 0.01) var below_fraction: float = 0.0
## True asks the pool test of each target the command may aim at, not of the user: allowed while
## any of them is under `below_fraction` (C8.25).
@export var below_any_target: bool = false
## Allowed only while the user's `below_pool` is at or above this fraction of its maximum
## (C10.19): "spend mp freely while it is over half". Zero is off.
@export_range(0.0, 1.0, 0.01) var above_fraction: float = 0.0


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if command == null:
		found.append("%s has an entry with no command" % context)
	else:
		found.append_array(command.problems(context))
	if boost < 0:
		found.append("%s has an entry with a negative boost" % context)
	if weight < 0.0:
		found.append("%s has an entry with a negative weight" % context)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s has an entry testing a flag but names none" % context)
	return found
