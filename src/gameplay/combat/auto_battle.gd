class_name AutoBattle
extends RefCounted
## Auto-battle (C5.4b): the party plays its own turns in a turn-based battle.
##
## IN PLAIN WORDS: while the flag `combat/auto_battle` is on (saved with the game; the battle
## screen's Auto row turns it on and off; with no flag, the player's setting decides, C5.3b), `Battle.brain_of` asks `brain_for` about each party
## member of its own. It plays by its definition's `brain` when it has one, else by `default_for`
## (C10.19): heal an ally under half, else a skill on a foe found weak to it, else attack.
## Guests and a status that takes a fighter over (berserk) are played as before. The screen paces
## these turns (`BattleScreen.tick_auto`) so the player can follow them and switch it off.
##
## OWNS: whether auto-battle is on, and which brain plays a party member while it is.
## MUST NOT: take a turn itself, or decide whose turn it is.

const FLAG: StringName = &"combat/auto_battle"



## True while auto-battle is on: the save's flag when it has one, else the player's setting (C5.3b).
static func on() -> bool:
	return CombatSettings.flag_or_setting(FLAG, CombatSettings.AUTO_BATTLE)


## Turns auto-battle on when it was off and off when it was on. Returns the new state.
static func toggle() -> bool:
	Flags.set_flag(FLAG, not on())
	return on()


## True when `fighter` is a party member of its own in `battle` that auto-battle plays now.
static func plays(battle: Battle, fighter: Combatant) -> bool:
	return on() and battle != null and fighter != null and battle.party.has(fighter) \
			and not battle.guests.has(fighter.combatant_id)


## The brain auto-battle plays `fighter` by, or null when it does not play it.
static func brain_for(battle: Battle, fighter: Combatant) -> BattleBrain:
	if not plays(battle, fighter):
		return null
	var def: CombatantDef = battle.defs.get(fighter.combatant_id, null)
	return def.brain if def != null and def.brain != null else default_for(def)


## The brain for a member with none of its own (C10.19): heal the most hurt ally under half when
## it has a heal, else use a skill on a foe it has found weak to it, else attack (the fallback).
static func default_for(def: CombatantDef) -> BattleBrain:
	var brain := BattleBrain.new()
	for command: BattleCommand in (def.commands if def != null else []):
		var skill: Skill = command.skill
		if skill == null or command.kind != BattleCommand.Kind.SKILL or skill.power == 0.0:
			continue
		var entry := BrainEntry.new()
		entry.command = command
		if skill.power < 0.0:
			entry.weight = 100.0
			entry.below_any_target = true
			entry.below_fraction = 0.5
			entry.target_rule = BrainEntry.TargetRule.LOWEST_HP
		else:
			entry.needs_weakness = true
			entry.target_rule = BrainEntry.TargetRule.WEAK
		brain.entries.append(entry)
	return brain
