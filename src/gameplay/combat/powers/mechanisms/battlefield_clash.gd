class_name BattlefieldClash
extends RefCounted
## Decides whether a battlefield about to rise may stand, when it overlaps others (C6.9d).
##
## IN PLAIN WORDS: two battlefields clash when they sit in the same `layer`, run on the same clock
## (both in the field or both in a battle) and overlap. In a battle they always overlap. In the
## field they overlap when either has no radius (it covers the fight), or when the two casters
## stand within the larger of the two radii of each other. The newer battlefield's `clash` rule
## decides what happens:
## - STRONGER_WINS: each older one is compared with the newer by `refinement`. The weaker one
##   ends; an equal one ends with it (both end); a stronger one makes the newer one shatter.
## - BOTH_END: every older one ends, and so does the newer one.
## - OVERWRITE: every older one ends and the newer one stands.
## - BOTH_STAND: nothing ends (terrain under a domain).
## A battlefield that ends by a clash is shattered: no aftermath, as with a broken one.
##
## OWNS: the clash rules, what counts as overlapping, and a battlefield's strength.
## MUST NOT: change a battlefield's own settings. It ends rivals through `BattlefieldRun.break_down`
## and only says whether the newcomer may rise; `BattlefieldRun` does the newcomer's own ending.

## True when `newcomer`, the battlefield `field` that `me` is about to raise, may stand. The rivals
## it beats are ended here. When it loses to one, or ties with one, it is not allowed, and the
## caller ends it (returns false).
static func allows(me: Combatant, field: BattlefieldMechanism, newcomer: BattlefieldRun) -> bool:
	if me == null or not me.is_inside_tree() or field.clash == BattlefieldMechanism.Clash.BOTH_STAND:
		return true
	var mine: float = strength(field, me)
	var shattered: bool = false
	for other: Combatant in _others(me):
		var powers: PowerSet = PowerSet.of(other.get_parent())
		if powers == null:
			continue
		for run: PowerExecutor in powers.running():
			var rival := run as BattlefieldRun
			if rival == null or rival == newcomer or not rival.standing():
				continue
			var theirs_field := rival.mechanism as BattlefieldMechanism
			if theirs_field == null or not _overlap(me, field, other, theirs_field):
				continue
			var theirs: float = strength(theirs_field, other)
			match field.clash:
				BattlefieldMechanism.Clash.BOTH_END:
					shattered = true
					rival.break_down()
				BattlefieldMechanism.Clash.OVERWRITE:
					rival.break_down()
				BattlefieldMechanism.Clash.STRONGER_WINS:
					if mine >= theirs:
						rival.break_down()
					if mine <= theirs:
						shattered = true
	return not shattered


## How strong `field` is for its caster `who`: its `refinement`, scaled by the caster's
## `refinement_stat` when one is named (`refinement` times one plus that stat).
static func strength(field: BattlefieldMechanism, who: Combatant) -> float:
	var out: float = field.refinement
	if field.refinement_stat != &"" and who != null:
		out *= 1.0 + who.sheet.value(field.refinement_stat)
	return out


# Every fighter in the fight on `me`'s clock, `me` included.
static func _others(me: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for node: Node in me.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other := node as Combatant
		if other != null and other.real_time == me.real_time:
			out.append(other)
	return out


# True when `field`, cast by `me`, overlaps `theirs`, cast by `other`.
static func _overlap(me: Combatant, field: BattlefieldMechanism, other: Combatant,
		theirs: BattlefieldMechanism) -> bool:
	if field.layer != theirs.layer:
		return false
	if not me.real_time or field.radius <= 0.0 or theirs.radius <= 0.0:
		return true
	var here := me.get_parent() as Node3D
	var there := other.get_parent() as Node3D
	if here == null or there == null:
		return false
	var gap: Vector3 = there.global_position - here.global_position
	gap.y = 0.0
	return gap.length() <= maxf(field.radius, theirs.radius)
