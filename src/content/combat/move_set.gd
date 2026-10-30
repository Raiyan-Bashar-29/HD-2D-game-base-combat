class_name MoveSet
extends Resource
## Everything one real-time fighter can do: an attack chain, a dodge, and skill slots.
##
## IN PLAIN WORDS: pressing attack plays `attack_chain[0]`; pressing again in its chain window
## plays `attack_chain[1]`, and so on to the end of the chain, after which the chain starts over
## once the fighter is idle. `dodge` is the move the dodge button plays; it may cut short the
## recovery of a swing. `skills` are the moves a skill button or the hybrid's menu (C4) plays,
## each usually wrapping a `Skill`.
##
## OWNS: which moves a fighter has, and what is wrong with the set.
## MUST NOT: time a move or read input. `MoveTimeline` and C3.4's `ActionFighter` do those.

@export var attack_chain: Array[ActionMove] = []
## Null means this fighter cannot dodge.
@export var dodge: ActionMove
@export var skills: Array[ActionMove] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if attack_chain.is_empty():
		found.append("%s has no attack chain" % context)
	for i: int in attack_chain.size():
		if attack_chain[i] == null:
			found.append("%s has an empty attack chain slot %d" % [context, i])
		else:
			found.append_array(attack_chain[i].problems("%s chain %d" % [context, i]))
	if dodge != null:
		found.append_array(dodge.problems("%s dodge" % context))
		if dodge.iframes_to <= dodge.iframes_from:
			found.append("%s has a dodge with no i-frames" % context)
	for i: int in skills.size():
		if skills[i] == null:
			found.append("%s has an empty skill slot %d" % [context, i])
		else:
			found.append_array(skills[i].problems("%s skill %d" % [context, i]))
	return found
