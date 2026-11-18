class_name BattleCommand
extends Resource
## One entry in a combatant's command menu: attack, a skill, an item, defend, flee or a power. Authored
## inline in a combatant's definition (C2.6), not catalogued, because a command is a slot in a
## menu, and what it does lives in the `Skill` it names.
##
## EIGHT KINDS, CLOSED. ATTACK uses the combatant's basic hit; SKILL and ITEM carry a `Skill` that
## says what happens; DEFEND and FLEE are the battle's own rules (C2.4). An item is a skill that
## also spends one `item_id` from the inventory, so a potion and a heal spell share every field.
## POWER (C6.2a) uses a hero `Power` from the fighter's equipped kit, through `PowerUse`. It also
## carries that power's skill in `skill`, so it is aimed exactly like a skill. SWAP (C8.3) trades
## the actor for a member of the battle's reserve, aimed at that member. ROW (C8.22b) steps the
## actor between the front and back rows, aimed at nobody. `one_target` says whether a menu asks
## which fighter a command lands on (C10.1).
##
## OWNS: which kind a menu entry is and what it carries.
## MUST NOT: run itself. The battle reads it.

# POWER and SWAP are last on purpose: a saved menu stores the kind as a number, so new kinds go at the end.
enum Kind { ATTACK, SKILL, ITEM, DEFEND, FLEE, POWER, SWAP, ROW }

@export var kind: Kind = Kind.ATTACK
## Required for SKILL and ITEM: what the command does.
@export var skill: Skill
## Required for ITEM: the inventory item one use spends.
@export var item_id: StringName = &""
## Required for POWER: the hero power it uses (C6.2a). Build one with `for_power`.
@export var power: Power
## Localization key for the menu label. Empty means the battle screen's default for the kind,
## or the skill's own `name_key`.
@export var label_key: String = ""
## Localization key of the submenu this command is filed under, such as "Magic" or "Special"
## (C2.18). Empty puts it on the first menu. Commands sharing a key share one submenu.
@export var category: String = ""


## A POWER command for `used`: it carries the power, and the power's skill (which may be null for
## a power that is all mechanism) so the battle aims it like a skill. Its label is the power's name.
static func for_power(used: Power) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = Kind.POWER
	command.power = used
	command.skill = used.skill if used != null else null
	command.label_key = used.name_key if used != null else ""
	return command


## True when the player picks one target for this command (C10.1): an attack, a swap, a skill or
## item that lands on one, or a power with no skill whose mechanism strikes one foe (a finisher, a
## command, a blink to a foe). DEFEND, FLEE and ROW aim at nobody.
func one_target() -> bool:
	if kind == Kind.ATTACK or kind == Kind.SWAP:
		return true
	if kind == Kind.DEFEND or kind == Kind.FLEE or kind == Kind.ROW:
		return false
	if skill != null:
		return skill.scope == Skill.Scope.ONE
	return kind == Kind.POWER and power != null and power.mechanism != null and power.mechanism.aims_at_one()


## Everything wrong with this entry. `context` names where it was authored, since a command has
## no id of its own.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if (kind == Kind.SKILL or kind == Kind.ITEM) and skill == null:
		found.append("%s: a %s command names no skill" % [context, Kind.keys()[kind]])
	if kind == Kind.ITEM and item_id == &"":
		found.append("%s: an ITEM command names no item_id" % context)
	if kind == Kind.POWER and power == null:
		found.append("%s: a POWER command names no power" % context)
	if power != null:
		found.append_array(power.problems(context))
	elif skill != null:
		found.append_array(skill.problems())
	return found
