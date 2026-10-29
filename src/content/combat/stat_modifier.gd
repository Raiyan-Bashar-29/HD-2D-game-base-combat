class_name StatModifier
extends Resource
## One change to one stat, and who made it: "+5 attack from the sword", "x1.5 speed from haste".
##
## A MODIFIER NAMES ITS SOURCE, AND THAT IS HOW IT LEAVES. Equipment, a status effect and a
## level-up all add modifiers to the same `StatSheet`, and each must later remove exactly its own
## and nobody else's. Keeping a reference to the modifier would work in memory and fail across a
## save; a source id is a string that survives one. So removal is `remove_from(source)`, never
## "remove this object".
##
## THE STAT IS A FREE NAME, NOT AN ENUM, which is `Attributes`' rule: a list of stat names in the
## base would be a list of one game's stats. A game says `&"attack"` or `&"luck"` in its data, and
## the base never knows which names exist.
##
## OWNS: the shape of one modifier, and what is wrong with one.
## MUST NOT: apply itself, touch an autoload, or know which sheet holds it. It is data, and
## tools/check_content.gd loads content classes where autoloads do not resolve.

## The three operations, applied by `StatSheet` in this order and no other. See its header.
enum Op { ADD, MULTIPLY, OVERRIDE }

## Which stat this changes. Any name; the sheet creates the stat on first mention.
@export var stat: StringName = &""
@export var op: Op = Op.ADD
## ADD: added to the base. MULTIPLY: the sum is multiplied by it, so 1.5 is +50%.
## OVERRIDE: the result, whatever the rest says.
@export var value: float = 0.0
## Who applied it. Everything one source added is removed together; see the header.
@export var source: StringName = &""


## Builds one in code, for systems and tests that do not author a `.tres`.
static func of(stat_name: StringName, operation: Op, amount: float, from: StringName) -> StatModifier:
	var made := StatModifier.new()
	made.stat = stat_name
	made.op = operation
	made.value = amount
	made.source = from
	return made


## Empty when it can be applied. A modifier with no source could never be removed.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if stat == &"":
		found.append("names no stat")
	if source == &"":
		found.append("names no source, so nothing could ever remove it")
	return found
