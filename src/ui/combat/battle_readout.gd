class_name BattleReadout
extends RefCounted
## One fighter's line on the battle screen, moved out of `BattleScreen` (C5.4b) so the screen
## stays in its budget. Its keys stay the screen's (`BattleScreen.POOLS_KEY` and the rest).
##
## IN PLAIN WORDS: the fighter's name and hp, then every other pool it has, the weapon it wears,
## its statuses and the weaknesses the player has already found. Parts it has none of are left out.
##
## Also the key of the line saying how the battle ended, and of a command's row (C8.27b).
##
## OWNS: the line's parts and their order, and which outcome line is shown.
## MUST NOT: change the fight, or hold state.

const RAISED_KEY: String = "ui.battle.raised"


## The line for `fighter`, whose name the screen shows as `shown`; `log` names its statuses.
static func line(fighter: Combatant, shown: String, log: BattleLog) -> String:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	var parts: Array[String] = [_tr(BattleScreen.POOLS_KEY).format({"name": shown,
			"hp": vitals.current(&"hp"), "max": vitals.maximum(&"hp")})]
	for stat: StringName in fighter.sheet.mentioned(Vitals.MAX_PREFIX):
		var pool: StringName = StringName(String(stat).trim_prefix(Vitals.MAX_PREFIX))
		if pool != fighter.damage_pool and vitals.maximum(pool) > 0:
			parts.append(_tr(BattleScreen.POOL_KEY).format({"pool": CombatNames.pool(pool),
					"current": vitals.current(pool), "max": vitals.maximum(pool)}))
	var weapon: String = WeaponLine.text(fighter.get_parent())
	if weapon != "":
		parts.append(weapon)
	var names: Array[String] = []
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	for effect: StatusEffect in statuses.held() if statuses != null else []:
		names.append(log.status_name(fighter.combatant_id, effect.id) if log != null else String(effect.id))
	if not names.is_empty():
		parts.append(_tr(BattleScreen.STATUSES_KEY).format({"list": ", ".join(names)}))
	var found: Array[String] = []
	for key: StringName in fighter.weak_to:
		if Weakness.revealed(fighter, key):
			found.append(CombatNames.mark(key))
	if not found.is_empty():
		parts.append(_tr(BattleScreen.WEAK_KEY).format({"list": ", ".join(found)}))
	return "   ".join(parts)


## A line for each piece a won fight raised a level (C9.5d, C10.18): "Coat rose to level 2".
static func raised(rewards: Rewards) -> Array[String]:
	var out: Array[String] = []
	for who: StringName in rewards.upgraded:
		for piece_id: Variant in rewards.upgraded[who]:
			out.append(_tr(RAISED_KEY).format({"item": PieceScreen.item_name(StringName(str(piece_id))),
				"level": GearUpgrades.level(StringName(str(piece_id)))}))
	return out


## The key of the line that says how `battle` ended (moved from `BattleScreen`, C8.26).
static func outcome_key(battle: Battle) -> String:
	match battle.outcome():
		Battle.Outcome.WON:
			return BattleScreen.WON_KEY
		Battle.Outcome.LOST:
			return BattleScreen.LOST_KEY
	return BattleScreen.FLED_KEY


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## The text key of `command`'s row: its own label, its kind's, or its skill's name.
static func command_key(command: BattleCommand) -> String:
	if command.label_key != "":
		return command.label_key
	match command.kind:
		BattleCommand.Kind.ATTACK:
			return BattleScreen.ATTACK_KEY
		BattleCommand.Kind.DEFEND:
			return BattleScreen.DEFEND_KEY
		BattleCommand.Kind.FLEE:
			return BattleScreen.FLEE_KEY
		BattleCommand.Kind.SWAP:
			return BattleScreen.SWAP_KEY
		BattleCommand.Kind.ROW:
			return BattleScreen.ROW_KEY
	return command.skill.name_key
