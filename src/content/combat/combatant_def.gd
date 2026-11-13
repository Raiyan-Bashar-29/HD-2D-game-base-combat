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
## What kind of creature this is (dragon, undead), for a passive's "killer" check (C9.2a).
@export var traits: Array[StringName] = []
## The command menu, for one the player controls. Empty means ATTACK, DEFEND and FLEE.
@export var commands: Array[BattleCommand] = []
## How it plays when nobody controls it. Null means the fallback: attack, then defend.
@export var brain: BattleBrain
## The hero powers this fighter has, in both formulas (C6.2): a battle equips them when it builds
## the fighter, and so does the field when this is a loadout's `fighter`. Null means none.
@export var power_kit: PowerKit
## The passives this fighter always holds (C9.1), party member or foe: see `docs/PASSIVES.md`.
@export var passives: Array[PassiveSkill] = []
## The skill-cost budget for passives the player chooses (C9.4), and what each party level
## after the first adds to it. 0 and 0 means this fighter chooses none.
@export var passive_budget: int = 0
@export var passive_budget_per_level: int = 0
## The gear this fighter starts with, by item id (C7.1b). Each needs a gear file. A party member
## puts them on once and may change them after; a foe wears them every fight. Empty means none.
@export var gear: Array[StringName] = []
## Loot this fighter drops when beaten, rolled each time (C7.2): in a battle on top of the
## encounter's, in the field on top of the enemy's own `loot`. Null means none.
@export var loot_table: LootTable
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
	if power_kit != null:
		found.append_array(power_kit.problems(where))
	for passive: PassiveSkill in passives:
		if passive == null:
			found.append("%s has an empty passive" % where)
		else:
			found.append_array(passive.problems())
	if passive_budget < 0 or passive_budget_per_level < 0:
		found.append("%s has a passive budget below zero" % where)
	for item_id: StringName in gear:
		if GearDb.for_item(item_id) == null:
			found.append("%s starts with '%s', which has no gear file" % [where, item_id])
	if loot_table != null:
		found.append_array(loot_table.problems(where))
	return found
