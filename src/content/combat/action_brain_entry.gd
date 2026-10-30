class_name ActionBrainEntry
extends Resource
## One move a real-time enemy may choose, with how likely it is and when it is allowed (C3.6).
## The real-time cousin of `BrainEntry`: a move instead of a command, a distance instead of a
## target rule.
##
## IN PLAIN WORDS: when the enemy is close enough to attack, it looks at every entry whose
## conditions hold and picks one, each as likely as its `weight` against the others. A lunge
## that only reaches far, a desperate flurry below a quarter hp: both are conditions here.
##
## Authored inline inside an `ActionBrain`.
##
## OWNS: one move's weight and conditions.
## MUST NOT: choose. `ActionDecider` does.

@export var move: ActionMove
@export var weight: float = 1.0
## The furthest the target may be for this move, in metres. 0 means the brain's `attack_range`.
@export var reach: float = 0.0
## The nearest the target may be, so a lunge is not used point-blank.
@export var min_reach: float = 0.0
## Only used when the enemy's hp is at or below this fraction of its maximum. 1 means always.
@export_range(0.0, 1.0, 0.01) var only_below: float = 1.0


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if move == null:
		found.append("%s has no move" % context)
	else:
		found.append_array(move.problems("%s move" % context))
	if weight <= 0.0:
		found.append("%s has a weight that is never picked" % context)
	if reach > 0.0 and min_reach > reach:
		found.append("%s has a min_reach beyond its reach" % context)
	return found
