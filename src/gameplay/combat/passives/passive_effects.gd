class_name PassiveEffects
extends RefCounted
## Runs one `PassiveEffect` (C9.1): finds who it lands on and changes their pool or statuses.
##
## IN PLAIN WORDS: `PassiveSet` decides WHEN a passive wakes; this does WHAT it says. Pools are
## changed through `Vitals` directly, not as a hit, so a passive's heal or drain wakes no other
## passive and two passives cannot feed each other forever. A fallen fighter is skipped.
##
## OWNS: applying an effect to its targets.
## MUST NOT: decide whether a trigger wakes, or remember anything.

## In the field, a fighter farther than this from the holder is not one of its allies or foes.
const NEAR: float = 20.0


## Runs `effect` for the holder `me`. `other` is the other fighter in the event (may be null),
## and `damage` the hit's amount (0 when the event has none).
static func run(effect: PassiveEffect, me: Combatant, other: Combatant, damage: int,
		rng: RandomNumberGenerator) -> void:
	for target: Combatant in _targets(effect.target, me, other):
		var body: Node = target.get_parent()
		var vitals: Vitals = Vitals.of(body)
		if vitals == null or vitals.is_defeated():
			continue
		match effect.kind:
			PassiveEffect.Kind.POOL_FLAT:
				vitals.change(effect.pool, roundi(effect.amount))
			PassiveEffect.Kind.POOL_SHARE:
				vitals.change(effect.pool, roundi(vitals.maximum(effect.pool) * effect.amount))
			PassiveEffect.Kind.POOL_FROM_DAMAGE:
				vitals.change(effect.pool, roundi(damage * effect.amount))
			PassiveEffect.Kind.GIVE_STATUS:
				var statuses: StatusSet = StatusSet.of(body)
				if statuses != null:
					for i: int in effect.stacks:
						statuses.apply(effect.status, rng)
			PassiveEffect.Kind.CURE:
				var held: StatusSet = StatusSet.of(body)
				if held != null:
					held.cure_tagged(effect.tag)


## Everyone standing on `me`'s side (`foes` false, `me` included) or against it (`foes` true),
## in the same kind of fight: a battle's fighters, or the field's within `NEAR`.
static func side(me: Combatant, foes: bool) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if me == null or not me.is_inside_tree():
		return out
	for node: Node in me.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other: Combatant = node as Combatant
		if other == null or other.real_time != me.real_time or not _near(me, other):
			continue
		var vitals: Vitals = Vitals.of(other.get_parent())
		if vitals == null or vitals.is_defeated():
			continue
		var wanted: FactionTable.Target = FactionTable.Target.ENEMY if foes else FactionTable.Target.ALLY
		if (other == me and not foes) or (other != me and me.can_target(other, wanted)):
			out.append(other)
	return out


## The fighter with the id `id` in `me`'s kind of fight, or null. A party member's field body
## and its battle copy share an id, so the one in the same fight as `me` is the one meant.
static func find(me: Combatant, id: StringName) -> Combatant:
	if me == null or id == &"" or not me.is_inside_tree():
		return null
	for node: Node in me.get_tree().get_nodes_in_group(Combatant.GROUP):
		var found: Combatant = node as Combatant
		if found != null and found.combatant_id == id and found.real_time == me.real_time:
			return found
	return null


static func _targets(target: PassiveEffect.Target, me: Combatant, other: Combatant) -> Array[Combatant]:
	match target:
		PassiveEffect.Target.SELF:
			return [me]
		PassiveEffect.Target.OTHER:
			var one: Array[Combatant] = []
			if other != null and is_instance_valid(other):
				one.append(other)
			return one
		PassiveEffect.Target.ALLIES:
			return side(me, false)
	return side(me, true)


static func _near(me: Combatant, other: Combatant) -> bool:
	var mine: Node3D = me.get_parent() as Node3D
	var theirs: Node3D = other.get_parent() as Node3D
	if not me.real_time or mine == null or theirs == null:
		return true
	return mine.global_position.distance_to(theirs.global_position) <= NEAR
