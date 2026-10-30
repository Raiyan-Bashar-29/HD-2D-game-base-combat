class_name CombatantDef
extends Resource
## Everything a battle needs to build one fighter: who it is, which side, its stats, its menu and,
## for one nobody controls, its brain. Party members and enemies are the same shape (C2.0), so a
## guest ally, a charmed enemy and a playable boss need no second type.
##
## AUTHORED INLINE IN AN ENCOUNTER (enemies) OR THE PARTY ROSTER (C2.8), not catalogued alone.
##
## THE FORMULA IS NOT HERE. A `DamageFormula` lives in systems and content may not depend on it,
## so a built fighter uses the standard formula; a game wanting another sets it on the built
## `Combatant`. A stat-only difference needs nothing: the four stages read the stats.
##
## OWNS: the definition of one fighter.
## MUST NOT: hold its current hp, or anything else that changes during play.

@export var combatant_id: StringName = &""
@export var name_key: String = ""
@export var faction: StringName = &"enemy"
## Copied to `Combatant.base_stats`. Every `max_<pool>` here becomes a pool, full at the start.
@export var base_stats: Dictionary[StringName, float] = {}
## Elements or skill tags this fighter is weak to, and what its plain attack counts as (C2.17).
## Give it a `max_shield` stat too, or a weakness is revealed but nothing ever breaks.
@export var weak_to: Array[StringName] = []
@export var attack_tags: Array[StringName] = []
## The command menu, for one the player controls. Empty means ATTACK, DEFEND and FLEE.
@export var commands: Array[BattleCommand] = []
## How it plays when nobody controls it. Null means the fallback: attack, then defend.
@export var brain: BattleBrain
## How a party member grows with experience. Null means it never levels: an enemy, or a guest.
@export var level_curve: LevelCurve


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s (%s)" % [context, combatant_id]
	if combatant_id == &"":
		found.append("%s has a fighter with no combatant_id" % context)
	if name_key == "":
		found.append("%s has no name_key" % where)
	if not base_stats.has(&"max_hp"):
		found.append("%s has no max_hp, so it starts defeated" % where)
	for command: BattleCommand in commands:
		if command == null:
			found.append("%s has an empty command" % where)
		else:
			found.append_array(command.problems(where))
	if brain != null:
		found.append_array(brain.problems(where))
	return found
