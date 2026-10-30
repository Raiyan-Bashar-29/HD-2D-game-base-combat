class_name BattleMenu
extends RefCounted
## What the battle menu offers the current fighter, and why a row is greyed out (C2.18).
##
## IN PLAIN WORDS: `BattleScreen` asks two questions here. `top_level` says what goes on the
## first menu: each command with no category, and one row per category, in the order the
## author listed them. `refusal` says whether a command can be used right now, and if not, the
## localization key of the reason a player reads beside it: not enough MP, a status forbids it,
## nothing to aim at, no escape, none left, or it cannot be boosted.
##
## IT ASKS THE BATTLE, IT DECIDES NOTHING. Every answer comes from `Battle.allows`,
## `Battle.can_boost`, `Battle.targets_for` and `SkillUse.affordable`, the same checks
## `Battle.act` makes, so a row the menu offers is a row the battle accepts.
##
## OWNS: grouping commands into categories, and choosing the reason a row is refused.
## MUST NOT: act, draw, or hold any state. The screen does both.

const BLOCKED_REASON_KEY: String = "ui.battle.reason.blocked"
const COST_REASON_KEY: String = "ui.battle.reason.cost"
const ITEM_REASON_KEY: String = "ui.battle.reason.no_item"
const TARGET_REASON_KEY: String = "ui.battle.reason.no_target"
const FLEE_REASON_KEY: String = "ui.battle.reason.no_flee"
const BOOST_REASON_KEY: String = "ui.battle.reason.no_boost"


## The first menu, in authored order: a `BattleCommand` for each command with no category, and
## a `String` (the category's localization key) the first time each category appears.
static func top_level(commands: Array[BattleCommand]) -> Array:
	var out: Array = []
	var seen: Array[String] = []
	for command: BattleCommand in commands:
		if command.category == "":
			out.append(command)
		elif not seen.has(command.category):
			seen.append(command.category)
			out.append(command.category)
	return out


## The commands filed under `category`, in authored order.
static func in_category(commands: Array[BattleCommand], category: String) -> Array[BattleCommand]:
	var out: Array[BattleCommand] = []
	for command: BattleCommand in commands:
		if command.category == category:
			out.append(command)
	return out


## Empty when the current fighter may use `command` with `boost` levels now; otherwise the
## localization key of the reason it may not.
static func refusal(battle: Battle, command: BattleCommand, boost: int) -> String:
	if not battle.allows(command):
		return BLOCKED_REASON_KEY
	if not battle.can_boost(command, boost):
		return BOOST_REASON_KEY
	var actor: Combatant = battle.current()
	match command.kind:
		BattleCommand.Kind.FLEE:
			return "" if battle.can_flee else FLEE_REASON_KEY
		BattleCommand.Kind.DEFEND:
			return ""
		BattleCommand.Kind.SKILL, BattleCommand.Kind.ITEM:
			if not SkillUse.affordable(actor, command.skill):
				return COST_REASON_KEY
			if command.kind == BattleCommand.Kind.ITEM and (battle.inventory == null
					or not battle.inventory.has(command.item_id)):
				return ITEM_REASON_KEY
			# A stance only ever aims at its user, so it never runs out of targets.
			if command.skill.toggle_status != null:
				return ""
	return TARGET_REASON_KEY if battle.targets_for(command).is_empty() else ""
