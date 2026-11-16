class_name TeamMechanism
extends PowerMechanism
## A team tech (C8.2): several fighters strike together in one turn, as a dual or triple tech, a
## chain, or an all-out attack.
##
## IN PLAIN WORDS: the user strikes first, then each partner in turn (a chain), every target
## `hits` times at `power` with `element`, and each landed hit counts against a weakness. It is
## ready only in a battle, while every fighter in `partners` stands on the user's side and is
## awake; with no partners named, everyone standing on the user's side joins (an all-out). With
## `needs_broken`, it waits until every standing foe is broken. In a CTB order each partner is
## pushed back `partner_delay` ticks, so the tech costs them time too.
##
## OWNS: the shape of a team tech.
## MUST NOT: hold running state. `TeamRun` (gameplay) runs it; `TeamAttacks` says when it is ready.

## The `combatant_id`s that must join (a dual or triple tech). Empty: every standing ally.
@export var partners: Array[StringName] = []
## Ready only while every standing foe is broken (an all-out attack).
@export var needs_broken: bool = false
## Each member's strike: its power through the member's own formula.
@export var power: float = 10.0
## How many strikes each member makes on each target.
@export var hits: int = 1
## The strikes' element; empty uses each member's worn weapon's, else none.
@export var element: StringName = &""
## In a CTB order, how far each partner is pushed back.
@export var partner_delay: float = 0.0


func kind() -> StringName:
	return &"team"


func aims_at_foes() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if power < 0.0 or hits < 1 or partner_delay < 0.0:
		found.append("%s has a negative power or partner_delay, or no hits" % context)
	if partners.has(&""):
		found.append("%s names an empty partner" % context)
	return found
