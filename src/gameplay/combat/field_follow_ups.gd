class_name FieldFollowUps
extends RefCounted
## Follow-ups in the field (C8.22c): the real-time side of `TeamAttacks.follow_ups`.
##
## IN PLAIN WORDS: when a real-time hit lands on a foe (`Hurtbox.take`), every other fighter on
## the attacker's side standing within `REACH` of that foe (a party follower, a summon, the
## player) that holds a FOLLOW_UP status and rolls its `reaction_chance` strikes the foe at once:
## its status's `counter_move`, or one plain hit. The strike lands straight away, as a counter
## with no clock of its own does, so a follower out of swinging range still follows up. It goes
## through `Combatant.hit`, never through a `Hurtbox`, so a follow-up never sets off another.
## An ally with a wall between it and the foe does not follow up (C9.12's rule, `CombatSight`),
## and a hit on a thing in the arena (`Unseen.INERT`: a crate, a barrel) draws no follow-up at all
## (C8.24). `Hurtbox.take` calls this only when its hit really took hp, the battle's rule.
##
## OWNS: which field fighters are near enough to follow up.
## MUST NOT: decide what a hit does, or who follows up in a battle (`TeamAttacks` does both).

## How far from the struck foe an ally may be and still follow up, in metres: the same reach a
## follower uses to think about a foe (`FieldCommands.REACH`).
const REACH: float = FieldCommands.REACH


## `attacker`'s hit just landed on `target` in the field: its allies near `target` may follow
## up. Returns how many did.
static func after_hit(attacker: Combatant, target: Combatant, rng: RandomNumberGenerator) -> int:
	var spot: Node3D = target.get_parent() as Node3D
	if spot == null or not attacker.is_inside_tree() or target.is_in_group(Unseen.INERT):
		return 0
	var allies: Array[Combatant] = []
	for node: Node in attacker.get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var ally: Combatant = (node as Hurtbox).fighter()
		var body: Node3D = ally.get_parent() as Node3D if ally != null else null
		if body == null or ally == attacker or ally == target \
				or not attacker.can_target(ally, FactionTable.Target.ALLY):
			continue
		if body.global_position.distance_to(spot.global_position) <= REACH and not _walled(body, spot):
			allies.append(ally)
	return TeamAttacks.answer_all(allies, attacker, target, rng)


# True when a wall stands between `body` and the struck foe at `spot` (C9.12).
static func _walled(body: Node3D, spot: Node3D) -> bool:
	return CombatSight.wall_between(body, CombatSight.aim(body), CombatSight.aim(spot),
			CombatSight.solids(spot)).is_finite()
