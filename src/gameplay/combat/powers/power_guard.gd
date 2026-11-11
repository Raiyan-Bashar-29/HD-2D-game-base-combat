class_name PowerGuard
extends RefCounted
## The one hook the hero powers have in the damage path (C6.6a; its own file since C7.3).
##
## IN PLAIN WORDS: just before a hit lands, `Combatant.receive` shows it here. The barriers of
## the target's own kits see it first, then the barriers of each ally, so a shield a friend holds
## up can stop a hit meant for someone else. A barrier may soften the hit or block it outright.
##
## OWNS: who is asked about an incoming hit, and in what order.
## MUST NOT: change a hit itself. Each running mechanism decides that (`intercept_incoming`).


## The hit `result`, thrown by `from`, is about to land on `target` (`Combatant.receive`): the
## barriers of its own kit see it first, then those of each ally living on the same clock (a
## field body never guards a battle fighter). It stops once a barrier has blocked the hit.
static func incoming(target: Combatant, result: DamageResult, from: StringName) -> void:
	var own: PowerSet = PowerSet.of(target.get_parent())
	if own != null:
		own.intercept_incoming(target, result, from)
	if not target.is_inside_tree():
		return
	for node: Node in target.get_tree().get_nodes_in_group(Combatant.GROUP):
		var ally: Combatant = node as Combatant
		if result.blocked:
			return
		if ally == null or ally == target or ally.real_time != target.real_time \
				or not ally.can_target(target, FactionTable.Target.ALLY):
			continue
		var theirs: PowerSet = PowerSet.of(ally.get_parent())
		if theirs != null:
			theirs.intercept_incoming(target, result, from)
