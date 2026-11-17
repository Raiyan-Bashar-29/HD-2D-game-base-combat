class_name SacrificeRun
extends PowerExecutor
## Runs an M11 sacrifice (C6.12b) on one fighter. Its settings are a `SacrificeMechanism`.
##
## IN PLAIN WORDS: using the power takes HP (and buffs, when asked) from every standing ally in
## reach, gives them to the user, then puts the gain on the user. A user on a ledger (C8.15a)
## banks the heal like any other.
##
## OWNS: carrying out one sacrifice, and `side`, the user's allies in reach (a refresh uses it).
## MUST NOT: knock an ally out, resolve a hit, or name a character.


func use(user: Combatant, _targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var sacrifice: SacrificeMechanism = mechanism as SacrificeMechanism
	var mine: StatusSet = StatusSet.of(user.get_parent())
	var taken: int = 0
	for ally: Combatant in side(user, sacrifice.radius):
		var vitals: Vitals = Vitals.of(ally.get_parent())
		var part: int = mini(floori(vitals.current(ally.damage_pool) * sacrifice.fraction),
			vitals.current(ally.damage_pool) - 1)
		if part > 0:
			vitals.change(ally.damage_pool, -part)
			taken += part
		if sacrifice.take_buffs and mine != null:
			_take_buffs(StatusSet.of(ally.get_parent()), mine, rng, user.combatant_id)
	if taken > 0:
		Delayed.heal(user, taken)
	if sacrifice.gain != null and mine != null:
		mine.apply(sacrifice.gain, rng, user.combatant_id)


## Every standing ally of `user` (never the user) within `radius` metres; 0 is any distance,
## and a body with no place in the world (a turn battle's) is always in reach.
static func side(user: Combatant, radius: float) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var here: Node3D = user.get_parent() as Node3D
	for node: Node in user.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other: Combatant = node as Combatant
		if other == null or other == user or not user.can_target(other, FactionTable.Target.ALLY):
			continue
		var vitals: Vitals = Vitals.of(other.get_parent())
		if vitals == null or vitals.is_defeated():
			continue
		var there: Node3D = other.get_parent() as Node3D
		if radius > 0.0 and here != null and there != null \
				and here.global_position.distance_to(there.global_position) > radius:
			continue
		out.append(other)
	return out


# Moves each buff `theirs` holds over to `mine`, at its full length.
func _take_buffs(theirs: StatusSet, mine: StatusSet, rng: RandomNumberGenerator, by: StringName) -> void:
	if theirs == null:
		return
	var tag: StringName = (mechanism as SacrificeMechanism).buff_tag
	for effect: StatusEffect in theirs.held():
		if effect.tags.has(tag) and theirs.cure(effect.id):
			mine.apply(effect, rng, by)
