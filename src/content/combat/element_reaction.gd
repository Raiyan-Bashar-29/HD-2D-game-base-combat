class_name ElementReaction
extends ContentEntry
## Two elements meeting on one target (C8.4): a hit of one lands on a fighter still marked by the
## other, and something more happens. Authored at `data/reactions/<name>.tres` with the id
## `reaction/<name>`; no code names an element or a reaction.
##
## IN PLAIN WORDS: a hit carrying an element that some reaction names leaves a mark of that
## element on its target for a while (`ElementReactions`). When a later hit carries the OTHER
## element of a reaction while the mark is held, that hit does `damage_bonus` more (0.5 = half
## as much again), the target gets `status` if one is set, and the mark is used up unless
## `keeps_mark`. The order does not matter: fire then ice and ice then fire are one reaction.
##
## OWNS: which two elements react and what the reaction does.
## MUST NOT: hold running state. `ElementReactions` (gameplay) reads it.

## Shown in the battle log when it happens.
@export var name_key: String = ""
@export var first: StringName = &""
@export var second: StringName = &""
## Extra share of the reacting hit's damage. 0 adds nothing.
@export var damage_bonus: float = 0.5
## Put on the target when it reacts. Null puts nothing.
@export var status: StatusEffect
## True leaves the earlier element's mark on the target after the reaction.
@export var keeps_mark: bool = false


## The element this reaction pairs with `element`; empty when it does not name `element`.
func other(element: StringName) -> StringName:
	if element == first:
		return second
	if element == second:
		return first
	return &""


func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [resource_path, id]
	if name_key == "":
		found.append("%s has no name_key" % where)
	if first == &"" or second == &"" or first == second:
		found.append("%s needs two different elements" % where)
	if damage_bonus < 0.0:
		found.append("%s has a negative damage_bonus" % where)
	return found
