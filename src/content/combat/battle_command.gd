class_name BattleCommand
extends Resource
## One entry in a combatant's command menu: attack, a skill, an item, defend or flee. Authored
## inline in a combatant's definition (C2.6), not catalogued, because a command is a slot in a
## menu, and what it does lives in the `Skill` it names.
##
## FIVE KINDS, CLOSED. ATTACK uses the combatant's basic hit; SKILL and ITEM carry a `Skill` that
## says what happens; DEFEND and FLEE are the battle's own rules (C2.4). An item is a skill that
## also spends one `item_id` from the inventory, so a potion and a heal spell share every field.
##
## OWNS: which kind a menu entry is and what it carries.
## MUST NOT: run itself. The battle reads it.

enum Kind { ATTACK, SKILL, ITEM, DEFEND, FLEE }

@export var kind: Kind = Kind.ATTACK
## Required for SKILL and ITEM: what the command does.
@export var skill: Skill
## Required for ITEM: the inventory item one use spends.
@export var item_id: StringName = &""
## Localization key for the menu label. Empty means the battle screen's default for the kind,
## or the skill's own `name_key`.
@export var label_key: String = ""
## Localization key of the submenu this command is filed under, such as "Magic" or "Special"
## (C2.18). Empty puts it on the first menu. Commands sharing a key share one submenu.
@export var category: String = ""


## Everything wrong with this entry. `context` names where it was authored, since a command has
## no id of its own.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if (kind == Kind.SKILL or kind == Kind.ITEM) and skill == null:
		found.append("%s: a %s command names no skill" % [context, Kind.keys()[kind]])
	if kind == Kind.ITEM and item_id == &"":
		found.append("%s: an ITEM command names no item_id" % context)
	if skill != null:
		found.append_array(skill.problems())
	return found
