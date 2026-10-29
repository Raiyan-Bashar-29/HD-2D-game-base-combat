class_name BrainEntry
extends Resource
## One thing a `BattleBrain` may choose: a command, how much it wants it, whom it aims at, and
## when it is allowed at all.
##
## TWO CONDITIONS, BOTH OPTIONAL. A flag test, the closed set `FlagQuery` already reads for
## dialogue and quests (so "after the bridge burns, the boss uses fire" is data), and the one
## thing a flag cannot say: the user's own pool below a fraction ("heal under half hp").
##
## OWNS: the shape of one choice.
## MUST NOT: evaluate itself. `BattleAi` (gameplay) does, because the pool test reads `Vitals`.

## How a ONE-target command picks among the legal targets. SELF aims at the user.
enum TargetRule { FIRST, RANDOM, LOWEST_HP, SELF }

@export var command: BattleCommand
## Relative chance among the entries allowed this turn. Zero never fires.
@export var weight: float = 1.0
@export var target_rule: TargetRule = TargetRule.FIRST

@export_group("Condition")
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
@export var condition_value: int = 0
## Allowed only while the user's `below_pool` is under this fraction of its maximum. Zero is off.
@export var below_pool: StringName = &"hp"
@export_range(0.0, 1.0, 0.01) var below_fraction: float = 0.0


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if command == null:
		found.append("%s has an entry with no command" % context)
	else:
		found.append_array(command.problems(context))
	if weight < 0.0:
		found.append("%s has an entry with a negative weight" % context)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s has an entry testing a flag but names none" % context)
	return found
