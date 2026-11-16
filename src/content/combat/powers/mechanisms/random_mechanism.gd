class_name RandomMechanism
extends PowerMechanism
## A random power (C8.13c): each use does one power picked at random from `powers`.
##
## IN PLAIN WORDS: the picked power's skill lands on the targets this power's skill landed on
## (or, with none, on nobody), and its mechanism runs as if the user had used it, without its
## cost, cooldown or rules. A picked mechanism that lasts (a barrier, a clone) keeps running until
## the next pick or until the kit comes off.
##
## OWNS: the shape of a random power.
## MUST NOT: hold running state. `RandomRun` (gameplay) runs it.

## The powers one is picked from, each as likely.
@export var powers: Array[Power] = []


func kind() -> StringName:
	return &"random"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if powers.is_empty() or powers.has(null):
		found.append("%s has no powers to pick from, or an empty one" % context)
	return found
