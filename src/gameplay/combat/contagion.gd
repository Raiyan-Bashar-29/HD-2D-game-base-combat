class_name Contagion
extends RefCounted
## Conditional outcomes of a status (C8.15b): one that spreads, and one that punishes whoever
## attacks its holder.
##
## IN PLAIN WORDS:
## - A status with `spread_reach` above 0 spreads when it runs out: every standing fighter on
##   the holder's side within that many metres gets a copy, if it does not hold one and has
##   not caught this status by spreading before. A body with no place in the world (a turn
##   battle's fighters) counts as in reach. A cure stops the spread.
## - A status with a `punish_status` answers an attack: a foe that hits at the holder gets
##   that status (which can itself be a delayed hit or a poison).
##
## OWNS: what `spread_reach` and `punish_status` do, and the once-per-fighter mark.
## MUST NOT: count a status down or resolve a hit. `Delayed.ended` and `Combatant.hit` call in.

const CAUGHT: StringName = &"contagion_caught"


## `effect` has just run out on the fighter `statuses` belongs to: it passes to those near.
static func passed(statuses: StatusSet, effect: StatusEffect, by: StringName) -> void:
	var holder: Combatant = Combatant.of(statuses.get_parent())
	if effect.spread_reach <= 0.0 or holder == null or not statuses.is_inside_tree():
		return
	# The one it left cannot catch it back, or two fighters would pass it for ever.
	_mark(statuses, effect.id)
	for node: Node in statuses.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other: Combatant = node as Combatant
		var theirs: StatusSet = StatusSet.of(other.get_parent()) if other != null else null
		if theirs == null or other == holder or other.faction != holder.faction:
			continue
		if _caught(theirs).has(effect.id) or theirs.stacks(effect.id) > 0:
			continue
		var vitals: Vitals = Vitals.of(other.get_parent())
		if (vitals != null and vitals.is_defeated()) or not _near(holder, other, effect.spread_reach):
			continue
		if theirs.apply(effect, null, by):
			_mark(theirs, effect.id)


## `attacker` hit at `target`: each punishing status `target` holds lands on a hostile attacker.
static func aimed(attacker: Combatant, target: Combatant) -> void:
	var held: StatusSet = StatusSet.of(target.get_parent()) if target != null else null
	var theirs: StatusSet = StatusSet.of(attacker.get_parent()) if attacker != null else null
	if held == null or theirs == null \
			or not attacker.can_target(target, FactionTable.Target.ENEMY):
		return
	for effect: StatusEffect in held.held():
		if effect.punish_status != null:
			theirs.apply(effect.punish_status, null, target.combatant_id)


static func _caught(statuses: StatusSet) -> Array:
	var ids: Array = statuses.get_meta(CAUGHT, [])
	return ids


static func _mark(statuses: StatusSet, id: StringName) -> void:
	statuses.set_meta(CAUGHT, _caught(statuses) + [id])


static func _near(a: Combatant, b: Combatant, reach: float) -> bool:
	var here: Node3D = a.get_parent() as Node3D
	var there: Node3D = b.get_parent() as Node3D
	if here == null or there == null:
		return true
	return here.global_position.distance_to(there.global_position) <= reach
