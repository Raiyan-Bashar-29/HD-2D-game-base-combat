class_name PowerMenu
extends RefCounted
## What the menus offer from a fighter's hero powers, and the words for why one is greyed out
## (C6.2c). See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: both menus, the battle screen and the hybrid's command overlay, ask this file
## the same three questions about powers:
## - `commands`: one menu entry for each power in the fighter's equipped kit (passives are held,
##   never used, so they get no entry), all filed under one "Powers" category. `with_powers`
##   puts them after the menu's own commands, so `BattleMenu.top_level` shows one "Powers" row.
## - `reason_key`: why a power cannot be used now, as the localization key a player reads:
##   "ready in 2 turns" in a battle, "ready in 3s" in the field, "not at this hour", and so on.
## - `reason_args`: the blanks those words fill: the pool ("not enough MP", "SUN too low") and
##   how long is left.
##
## IT DECIDES NOTHING. Every refusal comes from `PowerUse.refusal`, the same check `PowerUse.use`
## makes, so a row the menu offers is a row the power accepts.
##
## OWNS: turning a kit into menu entries, and a `PowerUse.Reason` into words.
## MUST NOT: use a power, hold any state, or name a character.

const CATEGORY_KEY: String = "ui.battle.powers"
const COOLDOWN_TURNS_KEY: String = "ui.battle.reason.cooldown_turns"
const COOLDOWN_SECONDS_KEY: String = "ui.battle.reason.cooldown_seconds"
const HOURS_KEY: String = "ui.battle.reason.hours"
const STATUS_KEY: String = "ui.battle.reason.needs_status"
const POOL_KEY: String = "ui.battle.reason.pool_low"
const NOT_EQUIPPED_KEY: String = "ui.battle.reason.not_equipped"


## One POWER command for each usable power in `user`'s equipped kit, in kit order, all under the
## Powers category. Empty when the fighter has no kit.
static func commands(user: Combatant) -> Array[BattleCommand]:
	var out: Array[BattleCommand] = []
	var powers: PowerSet = PowerSet.of(user.get_parent()) if user != null else null
	if powers == null or powers.kit == null:
		return out
	for power: Power in powers.kit.powers:
		if power == null or power.passive:
			continue
		var command := BattleCommand.for_power(power)
		command.category = CATEGORY_KEY
		out.append(command)
	return out


## `offered` followed by `user`'s powers: what a menu lists.
static func with_powers(offered: Array[BattleCommand], user: Combatant) -> Array[BattleCommand]:
	var out: Array[BattleCommand] = offered.duplicate()
	out.append_array(commands(user))
	return out


## The words for why `user` cannot use `power` now, or "" when it can. A cooldown is counted in
## seconds for a fighter on the field's clock (`Combatant.real_time`), and in turns in a battle.
static func reason_key(user: Combatant, power: Power) -> String:
	match PowerUse.refusal(user, power):
		PowerUse.Reason.NONE:
			return ""
		PowerUse.Reason.COOLDOWN:
			return COOLDOWN_SECONDS_KEY if user.real_time else COOLDOWN_TURNS_KEY
		PowerUse.Reason.HOURS:
			return HOURS_KEY
		PowerUse.Reason.STATUS:
			return STATUS_KEY
		PowerUse.Reason.POOL:
			return POOL_KEY
		PowerUse.Reason.BLOCKED:
			return BattleMenu.BLOCKED_REASON_KEY
		PowerUse.Reason.COST:
			return BattleMenu.COST_REASON_KEY
	return NOT_EQUIPPED_KEY


## The blanks a reason's words fill, for any command: `pool` (the pool its skill costs, or for a
## power refused for POOL, the pool it needs full) and `left` (a power's cooldown, rounded up).
static func reason_args(user: Combatant, command: BattleCommand) -> Dictionary:
	var pool: StringName = command.skill.cost_pool if command.skill != null else &""
	var left: int = 0
	var power: Power = command.power if command.kind == BattleCommand.Kind.POWER else null
	if power != null and user != null:
		if PowerUse.refusal(user, power) == PowerUse.Reason.POOL:
			pool = power.requires_pool
		var powers: PowerSet = PowerSet.of(user.get_parent())
		left = ceili(powers.cooldown_left(power.power_id)) if powers != null else 0
	return {"pool": String(pool).to_upper(), "left": left}
