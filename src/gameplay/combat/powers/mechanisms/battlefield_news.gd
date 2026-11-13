class_name BattlefieldNews
extends RefCounted
## Finds battlefields for the log and the HUD to name (C6.9g).
##
## IN PLAIN WORDS: the bus carries ids only (`Events.battlefield_raised`, `battlefield_lowered`,
## `battlefield_clashed`). A readout that wants the battlefield's name or its place's name asks
## here: `field_of` finds one caster's battlefield by its power id, and `standing` lists every
## battlefield standing in a fighter's fight. `power_name_key` and `place_name_key` read the
## translation keys off one.
##
## OWNS: looking battlefields up for readouts.
## MUST NOT: change a battlefield, or hold on to what it finds.

## Every battlefield standing in `me`'s fight (the fighters on its clock, `me` included).
static func standing(me: Combatant) -> Array[BattlefieldRun]:
	var out: Array[BattlefieldRun] = []
	if me == null or not me.is_inside_tree():
		return out
	for node: Node in me.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other := node as Combatant
		if other != null and other.real_time == me.real_time:
			for run: BattlefieldRun in _runs(other):
				if run.standing():
					out.append(run)
	return out


## `who`'s battlefield for `power_id`, standing or not, or null.
static func field_of(who: Combatant, power_id: StringName) -> BattlefieldRun:
	for run: BattlefieldRun in _runs(who):
		if run.power != null and run.power.power_id == power_id:
			return run
	return null


## The battlefield's own name key, or "" when it has none.
static func power_name_key(run: BattlefieldRun) -> String:
	return run.power.name_key if run != null and run.power != null else ""


## The name key of the place the battlefield gives, or "" when it gives none (C6.9f).
static func place_name_key(run: BattlefieldRun) -> String:
	var field: BattlefieldMechanism = run.mechanism as BattlefieldMechanism if run != null else null
	return field.place.name_key if field != null and field.place != null else ""


# The battlefields `who` is running.
static func _runs(who: Combatant) -> Array[BattlefieldRun]:
	var out: Array[BattlefieldRun] = []
	var powers: PowerSet = PowerSet.of(who.get_parent()) if is_instance_valid(who) and who.get_parent() != null else null
	for run: PowerExecutor in powers.running() if powers != null else []:
		if run is BattlefieldRun:
			out.append(run as BattlefieldRun)
	return out
