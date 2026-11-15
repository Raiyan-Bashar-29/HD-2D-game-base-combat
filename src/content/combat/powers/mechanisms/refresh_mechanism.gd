class_name RefreshMechanism
extends PowerMechanism
## M14, a refresh (C6.12b): the user's side gets its powers back sooner. See `docs/POWERS.md`
## § M14.
##
## IN PLAIN WORDS: using the power cuts each remaining cooldown by `fraction` (0.5 halves it):
## the user's alone (SELF), or the user's and every standing ally's (ALLIES; in the field only
## those within `radius` metres, 0 for any distance). In a battle a cut cooldown is rounded down
## to whole turns. `pool_gain` points of `pool` go to the user. `speed` is a status put on each
## fighter refreshed: give it a `cooldown_rate` modifier (ADD 0.3 counts cooldowns down 30%
## faster, read by `PowerSet`) and a duration.
##
## OWNS: the shape of a refresh.
## MUST NOT: hold running state. `RefreshRun` (gameplay) runs it.

enum Scope { SELF, ALLIES }

@export var scope: Scope = Scope.SELF
## The share of each remaining cooldown taken off, 0 to 1.
@export_range(0.0, 1.0, 0.01) var fraction: float = 0.5
## A pool of the user's (a gauge, MP) that gains `pool_gain`. Empty for none.
@export var pool: StringName = &""
@export var pool_gain: int = 0
## Put on each fighter refreshed. Null for none.
@export var speed: StatusEffect
## Field, ALLIES: metres an ally may stand from the user. 0: any distance.
@export var radius: float = 0.0


func kind() -> StringName:
	return &"refresh"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if speed != null:
		out.append(speed)
	return out


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if fraction <= 0.0 and pool_gain == 0 and speed == null:
		found.append("%s cuts no cooldown, fills no pool and speeds nobody" % context)
	if radius < 0.0 or pool_gain < 0:
		found.append("%s has a negative radius or pool gain" % context)
	if pool_gain > 0 and pool == &"":
		found.append("%s gains points but names no pool" % context)
	if speed != null:
		found.append_array(speed.problems())
	return found
