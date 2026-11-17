class_name ForesightMechanism
extends PowerMechanism
## M7, foresight (C6.10): the user sees the next moment and rewrites it. See `docs/POWERS.md`
## § M7.
##
## IN PLAIN WORDS: it works for as long as its kit is worn, inside the power's `active_hours`;
## nothing has to be used. Each fight gives `rewrites`:
## - `dodge`: a foe's hit that would land on the user misses instead, spending one;
## - `force`: the user's own miss is struck again as a sure hit, spending one.
## In the field two rewrites are at least `rewrite_gap` seconds apart, and the count comes back
## on entering an area (a field fight has no clear start); a battle starts with the full count.
## `observe`: a skill (or a field move) that has landed on the user once misses it for the
## rest of the fight, for free. `reveal`: every foe's weaknesses are shown on the user's turn
## in a battle, and the locked-on foe's in the field.
##
## OWNS: the shape of foresight.
## MUST NOT: hold running state. `ForesightRun` and `Foresight` (gameplay) run it.

## Rewrites per fight. 0: none.
@export var rewrites: int = 0
## A rewrite may turn a foe's landing hit into a miss.
@export var dodge: bool = false
## A rewrite may turn the user's miss into a hit.
@export var force: bool = false
## Field: the least seconds between two rewrites.
@export var rewrite_gap: float = 0.0
## A skill or move that has landed once misses the user for the rest of the fight.
@export var observe: bool = false
## Foes' weaknesses are shown on sight.
@export var reveal: bool = false


func kind() -> StringName:
	return &"foresight"


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if rewrites < 0 or rewrite_gap < 0.0:
		found.append("%s has a negative rewrite count or gap" % context)
	if rewrites > 0 and not dodge and not force:
		found.append("%s has rewrites but may neither dodge nor force" % context)
	if rewrites <= 0 and not observe and not reveal:
		found.append("%s foresees nothing" % context)
	return found
