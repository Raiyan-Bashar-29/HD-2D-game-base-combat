class_name AutoBattle
extends RefCounted
## Auto-battle (C5.4b): the party plays its own turns in a turn-based battle.
##
## IN PLAIN WORDS: while the flag `combat/auto_battle` is on (saved with the game; the battle
## screen's Auto row turns it on and off), `Battle.brain_of` asks `brain_for` about each party
## member of its own. It plays by its definition's `brain` when it has one, else by a plain brain
## with no entries, whose fallback attacks the first foe it may (`BattleBrainContext.fallback`).
## Guests and a status that takes a fighter over (berserk) are played as before. The screen paces
## these turns (`BattleScreen.tick_auto`) so the player can follow them and switch it off.
##
## OWNS: whether auto-battle is on, and which brain plays a party member while it is.
## MUST NOT: take a turn itself, or decide whose turn it is.

const FLAG: StringName = &"combat/auto_battle"

static var _plain: BattleBrain = BattleBrain.new()


## True while auto-battle is on.
static func on() -> bool:
	return Flags.get_bool(FLAG)


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
	return def.brain if def != null and def.brain != null else _plain
