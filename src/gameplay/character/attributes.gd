class_name Attributes
extends RefCounted
## What a character is LIKE, as opposed to what they carry. A namespace over `Flags`, and the
## fifth use of that shape after `PersistentState`, `Standing`, `Equipment` and `WorldMap`.
##
##     attr/<who>/<name>        attr/player/pace        -> an integer number of STEPS
##
## THE FIRST QUESTION WAS NOT "WHAT IS AN ATTRIBUTE", IT WAS "WHAT READS ONE".
## 17 of this project's 23 settings have no consumer, and `Gate.locked_key` was declared,
## validated by a content gate and read by nothing for six packages. So this file ships with
## exactly ONE consumer — `PlayerController.current_speed()` — and the arrangement below is
## built so that number cannot grow silently:
##
##   - THERE IS NO REGISTRY, NO `AttributeDef` AND NO ENUM OF NAMES. Any StringName is an
##     attribute the moment something writes it, so declaring the fiftieth costs no code — the
##     ADR-0006 test, met without a sixth directory scan (see `area_db.gd`'s header for why a
##     sixth would have been the wrong answer).
##   - AN ATTRIBUTE'S NAME IS A CONST ON ITS CONSUMER, never here. `PlayerController.PACE` is
##     declared beside the line that reads it, so an attribute nobody reads has NOWHERE to be
##     written down and cannot accumulate in this file as a table of good intentions. That is
##     the whole of the design; it is a rule about where a name lives, not a mechanism.
##
## WHY STEPS AND NOT THE NUMBER ITSELF. A flag holding `4.7` would be a walk speed authored into
## a save file, and the tuned value in `player_controller.gd` would stop being the truth. A step
## is a bounded, reviewable integer and the consumer decides what one is worth — here, `STEP`
## of the base value, clamped so a repeatable action cannot farm a number that later gates
## content. Same reasoning, and the same clamp, as `Standing`.
##
## WHAT IT COSTS, STATED. The key contains a character id, so that id is a public identifier the
## way an `object_id` is: renaming a carrier resets its attributes to their defaults on an old
## save. Identical to the price `Equipment` pays for an item id and `WorldMap` for an area id.
##
## OWNS: the key shape, the range, the clamp, and what one step is worth.
## MUST NOT: name an attribute, decide what any attribute MEANS, or know what reads one.

const PREFIX: String = "attr/"
## A character with no flag at all has every attribute at this value, so a save file carries no
## row for the ninety attributes nobody has touched.
const BASELINE: int = 0
## Clamped rather than unbounded, for `Standing`'s reason: the ceiling is the design.
const MINIMUM: int = -4
const MAXIMUM: int = 4
## What one step is worth to a consumer that scales something by it. At the bounds this gives
## half speed and one and a half times speed, which is the widest range that still leaves the
## authored base value recognisable as the truth.
const STEP: float = 0.125


static func key(who: StringName, attribute: StringName) -> StringName:
	return StringName(PREFIX + String(who) + "/" + String(attribute))


static func of(who: StringName, attribute: StringName) -> int:
	return Flags.get_int(key(who, attribute), BASELINE)


## Returns the NEW value, so a caller can report what happened without reading it back and
## without assuming the delta applied in full — at the ceiling it does not.
static func change(who: StringName, attribute: StringName, delta: int) -> int:
	return set_to(who, attribute, of(who, attribute) + delta)


## Set it outright. Clamped on the way in, so nothing downstream has to defend itself against a
## value the range forbids — including a hand-edited save and `--flag=attr/player/pace:99`.
static func set_to(who: StringName, attribute: StringName, value: int) -> int:
	var next: int = clampi(value, MINIMUM, MAXIMUM)
	Flags.set_flag(key(who, attribute), next)
	return next


## The multiplier a consumer scales by. A pure function of the step, given a name here rather
## than left to each caller so two consumers cannot disagree about what one point is worth.
static func multiplier(who: StringName, attribute: StringName) -> float:
	return 1.0 + float(of(who, attribute)) * STEP


## Every attribute one character has ever been given a value for. For a debug dump or a future
## character sheet — read through `Flags`, so there is no second list to keep in step.
static func all_of(who: StringName) -> Dictionary[StringName, Variant]:
	return Flags.with_prefix(PREFIX + String(who) + "/")
