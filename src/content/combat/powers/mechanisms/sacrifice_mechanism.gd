class_name SacrificeMechanism
extends PowerMechanism
## M11, a sacrifice (C6.12b): the user grows by taking from its own side. See `docs/POWERS.md`
## § M11.
##
## IN PLAIN WORDS: using the power takes `fraction` of each standing ally's current HP (never
## the last point, so nobody falls to it) and heals the user by the sum. With `take_buffs`, each
## status an ally holds that carries `buff_tag` leaves the ally and goes on the user, fresh.
## Then `gain` is put on the user. In the field only allies within `radius` metres give (0 for
## every ally); in a battle the whole side gives.
##
## OWNS: the shape of a sacrifice.
## MUST NOT: hold running state. `SacrificeRun` (gameplay) runs it.

## The share of each ally's current HP taken, 0 to 1.
@export_range(0.0, 1.0, 0.01) var fraction: float = 0.3
## True: the allies' buffs go to the user as well.
@export var take_buffs: bool = false
## The tag that marks a status as a buff.
@export var buff_tag: StringName = &"buff"
## Put on the user after it has taken. Null for none.
@export var gain: StatusEffect
## Field: metres an ally may stand from the user and still give. 0: any distance.
@export var radius: float = 0.0


func kind() -> StringName:
	return &"sacrifice"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if gain != null:
		out.append(gain)
	return out


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if fraction <= 0.0 and not take_buffs:
		found.append("%s takes neither HP nor buffs" % context)
	if radius < 0.0:
		found.append("%s has a negative radius" % context)
	if take_buffs and buff_tag == &"":
		found.append("%s takes buffs but names no buff tag" % context)
	if gain != null:
		found.append_array(gain.problems())
	return found
