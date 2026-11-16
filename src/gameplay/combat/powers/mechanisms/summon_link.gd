class_name SummonLink
extends RefCounted
## The two links a summon can keep with its user (C8.10f), for `SummonRun`.
##
## IN PLAIN WORDS: `key` names the flag a `saved` summon keeps its field count in,
## `summon/<user id>/<power id>`, and `save` writes it (erased at 0, so an unset flag means none).
## `ours` says whether a hurt combatant is one of the run's fighters, and `share_hurt` takes the
## `linked_hp` share of that hurt from the user's defeat pool.
##
## OWNS: the shape of the saved count's flag.
## MUST NOT: bring or send anyone (the run does), or name a character.

const PREFIX: String = "summon/"


## The flag for this summon's count, or "" when it is not saved or has no user.
static func key(holder: PowerSet, power: Power, summon: SummonMechanism) -> StringName:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	if me == null or power == null or summon == null or not summon.saved:
		return &""
	return StringName(PREFIX + "%s/%s" % [me.combatant_id, power.power_id])


static func save(flag: StringName, count: int) -> void:
	if flag.is_empty():
		return
	if count <= 0:
		Flags.erase_flag(flag)
	else:
		Flags.set_flag(flag, count)


## True when `who` is one of the field fighters `out` or the battle's `called`.
static func ours(who: StringName, out: Array[OwnedFighter], called: Array[Combatant]) -> bool:
	for one: OwnedFighter in out:
		var mine: Combatant = Combatant.of(one) if is_instance_valid(one) else null
		if mine != null and mine.combatant_id == who:
			return true
	for one: Combatant in called:
		if is_instance_valid(one) and one.combatant_id == who:
			return true
	return false


## The user loses `share` of `amount` from its defeat pool.
static func share_hurt(user: Node, share: float, amount: int) -> void:
	var vitals: Vitals = Vitals.of(user) if user != null else null
	if vitals == null or share <= 0.0 or amount <= 0:
		return
	vitals.change(vitals.defeat_pool, -roundi(amount * share))
