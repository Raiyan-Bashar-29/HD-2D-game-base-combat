class_name StealMechanism
extends PowerMechanism
## A steal (C8.13c): the user takes good things off the fighters its power's skill landed on.
##
## IN PLAIN WORDS: from each target, every held status carrying `tag` (`buff` by default) is
## taken off it and put on the user, at most `most` in all (0: no limit). A taken status starts
## afresh on the user. Without a skill to aim it, the power takes from nobody.
##
## OWNS: the shape of a steal.
## MUST NOT: hold running state. `StealRun` (gameplay) runs it.

## The `StatusEffect.tags` label a status needs to be taken.
@export var tag: StringName = &"buff"
## The most statuses taken by one use. 0 means no limit.
@export var most: int = 0


func kind() -> StringName:
	return &"steal"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if tag == &"" or most < 0:
		found.append("%s steals by no tag, or a negative number" % context)
	return found
