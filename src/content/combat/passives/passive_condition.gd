class_name PassiveCondition
extends Resource
## One check a passive's trigger makes before it wakes (C9.2a). See `docs/PASSIVES.md`.
##
## IN PLAIN WORDS: a trigger lists conditions, and wakes only when every one holds. `kind` picks
## the check, the other fields are its numbers, and `negate` flips the answer.
## - POOL_SHARE: the holder's `pool` is from `low` to `high` full (0.5 is half). "Below half HP"
##   is pool `hp`, low 0, high 0.5.
## - HOLDS_TAG: the holder has a status tagged `tag`.
## - TARGET_HOLDS_TAG: the other fighter in the event has a status tagged `tag`.
## - TARGET_TRAIT: the other fighter's definition lists the trait `tag` (a species such as
##   dragon or undead). This is the "killer" check.
## - WEARING: the holder wears the piece, or a piece of the gear type, `tag`.
## - ALONE: the holder is the only one of its side standing.
## - ALLIES_STANDING: at least `count` allies stand, the holder not counted.
## - IN_FIELD: the fight is in real time (negate it for a turn-based battle).
## - HOUR: the clock's hour is from `low` to `high`; low 20 and high 5 means the night.
##
## OWNS: the data of one condition, and checking it.
## MUST NOT: answer itself. `PassiveConditions` (gameplay) does.

enum Kind { POOL_SHARE, HOLDS_TAG, TARGET_HOLDS_TAG, TARGET_TRAIT, WEARING, ALONE,
	ALLIES_STANDING, IN_FIELD, HOUR }

@export var kind: Kind = Kind.POOL_SHARE
@export var negate: bool = false
@export var pool: StringName = &"hp"
## A share for POOL_SHARE, an hour for HOUR.
@export var low: float = 0.0
@export var high: float = 1.0
@export var tag: StringName = &""
@export var count: int = 1


## True when the check needs the other fighter of an event.
func needs_other() -> bool:
	return kind == Kind.TARGET_HOLDS_TAG or kind == Kind.TARGET_TRAIT


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	match kind:
		Kind.POOL_SHARE:
			if pool == &"" or low > high:
				found.append("%s has a pool condition with no pool, or low above high" % where)
		Kind.HOLDS_TAG, Kind.TARGET_HOLDS_TAG, Kind.TARGET_TRAIT, Kind.WEARING:
			if tag == &"":
				found.append("%s has a condition that names no tag" % where)
		Kind.ALLIES_STANDING:
			if count < 1:
				found.append("%s asks for fewer than one ally standing" % where)
	return found
