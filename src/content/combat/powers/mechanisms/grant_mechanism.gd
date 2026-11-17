class_name GrantMechanism
extends PowerMechanism
## M12, a grant (C6.11): the user gives its allies something of its own. See `docs/POWERS.md`
## § M12.
##
## IN PLAIN WORDS: using the power gives each receiver the `gifts` (or one of them at random,
## with `pick_one`), and lends it `kit`, the powers of a kit it holds for `lasts` turns of the
## user in a battle, or seconds in the field. The receivers are the allies the power's skill
## landed on (the user when it has none), or, with `to_all`, every standing ally within
## `radius` metres (0 for any distance), the user too when `with_user`.
##
## OWNS: the shape of a grant.
## MUST NOT: hold running state. `GrantRun` (gameplay) runs it.

## The statuses each receiver gets.
@export var gifts: Array[StatusEffect] = []
## True: each receiver gets one of `gifts`, at random.
@export var pick_one: bool = false
## A kit lent to each receiver for `lasts`. Null for none.
@export var kit: PowerKit
## How long the lent kit stays: the user's turns in a battle, seconds in the field.
@export var lasts: float = 3.0
## True: every standing ally in `radius` receives.
@export var to_all: bool = false
## Field: metres an ally may stand from the user with `to_all`. 0: any distance.
@export var radius: float = 0.0
## With `to_all`, the user receives too.
@export var with_user: bool = true


func kind() -> StringName:
	return &"grant"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	for gift: StatusEffect in gifts:
		if gift != null:
			out.append(gift)
	return out


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if statuses().is_empty() and kit == null:
		found.append("%s grants nothing" % context)
	if gifts.has(null):
		found.append("%s has an empty gift" % context)
	if kit != null and lasts <= 0.0:
		found.append("%s lends a kit for no time" % context)
	if radius < 0.0:
		found.append("%s has a negative radius" % context)
	for gift: StatusEffect in statuses():
		found.append_array(gift.problems())
	return found
