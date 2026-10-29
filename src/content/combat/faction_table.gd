class_name FactionTable
extends Resource
## Who is hostile to whom, and what a target filter allows. One table per game, as a `.tres`.
##
## THE DEFAULT NEEDS NO TABLE: the same faction is allied and different factions are hostile,
## which is every simple game's rule. A table is for the rest: two factions at peace, or a
## faction at war with itself. Hostility is symmetric, so a pair is written once.
##
## A FILTER IS A QUESTION ABOUT TWO COMBATANTS, not a list of them. SELF is only the user; ALLY is
## anyone not hostile, the user included, so a party heal reaches its caster; ENEMY is anyone
## hostile; ANY is everyone. Choosing among the matches is a formula's (C2's cursor, C3's lock-on).
##
## OWNS: the hostility rule and the meaning of each filter.
## MUST NOT: know which factions exist, find combatants, or pick a target.

enum Target { SELF, ALLY, ENEMY, ANY }

## When true, every pair not listed below is hostile across factions and allied within one.
## When false, nothing is hostile unless listed.
@export var different_is_hostile: bool = true
## Pairs that break the default, each written `a:b`. Listing a faction with itself (`a:a`)
## makes it fight itself.
@export var exceptions: PackedStringArray = PackedStringArray()


func is_hostile(a: StringName, b: StringName) -> bool:
	var hostile: bool = different_is_hostile and a != b
	if _listed(a, b):
		hostile = not hostile
	return hostile


## Whether a user may target a candidate under `filter`. Ids say who is who; factions say who
## is hostile.
func allows(filter: Target, user_id: StringName, user_faction: StringName,
		candidate_id: StringName, candidate_faction: StringName) -> bool:
	match filter:
		Target.SELF:
			return user_id == candidate_id
		Target.ALLY:
			return user_id == candidate_id or not is_hostile(user_faction, candidate_faction)
		Target.ENEMY:
			return user_id != candidate_id and is_hostile(user_faction, candidate_faction)
	return true


func _listed(a: StringName, b: StringName) -> bool:
	return exceptions.has("%s:%s" % [a, b]) or exceptions.has("%s:%s" % [b, a])
