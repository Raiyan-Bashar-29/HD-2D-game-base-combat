class_name PowerSet
extends Node
## The hero powers one fighter has equipped (C6.1b): a child of the body, beside its `Vitals`,
## `StatusSet` and `Combatant`. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: `equip` puts a `PowerKit` on the fighter. While it is on:
## - its `stat_bonuses` sit on the fighter's sheet, under the kit's id as their source;
## - its `passives` are held as statuses (give them duration 0, so they never run out);
## - each power with a mechanism has its own running `PowerExecutor`;
## - each power used counts down its cooldown here, and says so on
##   `Events.power_cooldown_changed` each time the whole number left changes (C6.3b), so the
##   HUD and the command menu can show "ready in 3s" without asking every frame.
## - its `gauges` (C6.4a) fill and drain by their rules, through a `KitGauges`: this set tells it
##   when time passes and when the fighter lands a hit, takes one, dodges or misses, and every
##   change to a gauge pool, whoever made it, moves that gauge's level status. Since C6.4b it
##   also hears a kill, an ally falling, a new move (`moved`, from `ActionFighter`) and a cost
##   paid (`spent`, from `SkillUse.pay`).
## - every running mechanism hears of each power used (`used`, from `PowerUse.use`, C6.5a), so a
##   form's cycle can move on after a finisher.
## - in the field, the fighter plays the moves its running mechanisms hand it (`moves_over`,
##   C6.5b): a form's own attack chain and dodge.
##
## A KILL WITHOUT A LOOKUP: `Combatant.receive` changes the pool first, which announces
## `combatant_defeated`, and then announces `combatant_damaged`. So the id that just fell is
## remembered, and a damage event on that same id thrown by this fighter is its kill.
## `unequip` takes all of it off again, and nothing else: another source's modifiers and
## statuses stay.
##
## TIME, IN BOTH FORMULAS. A field fighter (`Combatant.real_time`) counts down in seconds of FIGHT
## time, every physics frame, so a fight slowed by `CombatClock` cools slowly. A battle fighter
## counts in turns: `Battle` calls `tick_turn` at the START of the holder's turn (C6.2a), so a
## sleeping fighter's cooldowns still count.
##
## NOT SAVED: the kit comes from the fighter's definition each time a fighter is built (C6.2a in
## a battle, C6.2b in the field), and a cooldown is a moment's state, like the ATB gauge. The
## passives are statuses, and a load or a new game clears the `StatusSet`, which cannot find a
## status that lives only in a kit. So after either one the set puts its passives back
## (`_hold_passives`), never twice.
##
## A PARTY SWITCH MOVES THIS NODE to another body (`FieldParty`), and moving a node makes it
## leave the tree and enter again. So its mechanisms end only when it is freed, not when it
## leaves the tree.
##
## OWNS: which kit is equipped, its cooldowns, its running executors, and its gauges.
## MUST NOT: decide whether a power may be used, or use one. `PowerUse` does both.

var kit: PowerKit
var _cooling: Dictionary[StringName, float] = {}
var _running: Dictionary[StringName, PowerExecutor] = {}
var _passives: Array[StringName] = []
## The equipped kit's gauges. Empty, never null, with no kit.
var gauges: KitGauges = KitGauges.new()
# The id that fell a moment ago, until the next damage event says who felled it.
var _just_fell: StringName = &""


## The set under `who`, or null.
static func of(who: Node) -> PowerSet:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: PowerSet = child as PowerSet
		if found != null:
			return found
	return null


## The passive `status_id` of the kit worn under `who`, or null. A passive lives only in its kit
## file, so `StatusSet` finds it here when it loads a save (C6.2b).
static func passive_of(who: Node, status_id: StringName) -> StatusEffect:
	var powers: PowerSet = of(who)
	if powers == null or powers.kit == null:
		return null
	for passive: StatusEffect in powers.kit.passives:
		if passive != null and passive.id == status_id:
			return passive
	return null


func _physics_process(delta: float) -> void:
	var fighter: Combatant = Combatant.of(get_parent())
	if fighter != null and fighter.real_time:
		tick_seconds(CombatClock.scaled(delta))


# Connected each time it enters, and after its `StatusSet` (an earlier sibling, moved first on a
# switch), so on a new game the set has already cleared when the passives go back on.
func _enter_tree() -> void:
	for pair: Array in _listens():
		var heard: Signal = pair[0]
		var handler: Callable = pair[1]
		if not heard.is_connected(handler):
			heard.connect(handler)


func _exit_tree() -> void:
	for pair: Array in _listens():
		var heard: Signal = pair[0]
		var handler: Callable = pair[1]
		if heard.is_connected(handler):
			heard.disconnect(handler)


# Every event this set answers, with its handler.
func _listens() -> Array[Array]:
	return [[Events.game_started, _hold_passives], [Events.game_loaded, _on_game_loaded],
		[Events.combatant_damaged, _on_damaged], [Events.attack_dodged, _on_dodged],
		[Events.attack_missed, _on_missed], [Events.vitals_changed, _on_vitals_changed],
		[Events.combatant_defeated, _on_defeated], [Events.combatant_revived, _on_revived]]


func _notification(what: int) -> void:
	# Freed: its mechanisms stop. Not on leaving the tree, which a party switch does.
	if what == NOTIFICATION_PREDELETE:
		for executor: PowerExecutor in _running.values():
			executor.end()


## Puts `new_kit` on, taking off whatever kit was on first. Null just takes the old one off.
func equip(new_kit: PowerKit) -> void:
	unequip()
	if new_kit == null:
		return
	kit = new_kit
	var sheet: StatSheet = _sheet()
	if sheet != null:
		for bonus: StatModifier in kit.stat_bonuses:
			# Re-sourced to the kit's id, so taking the kit off removes exactly these.
			if bonus != null:
				sheet.add(StatModifier.of(bonus.stat, bonus.op, bonus.value, kit.kit_id))
	_hold_passives()
	gauges = KitGauges.new(kit.gauges)
	for pool: StringName in gauges.pools():
		gauges.refresh_levels(get_parent(), pool)
	for power: Power in kit.powers:
		if power == null or power.mechanism == null:
			continue
		var executor: PowerExecutor = PowerMechanisms.make(power.mechanism)
		if executor != null:
			executor.power = power
			executor.holder = self
			_running[power.power_id] = executor


## Takes the kit off: its stat bonuses, the passives it put on, its executors and cooldowns.
func unequip() -> void:
	if kit == null:
		return
	var sheet: StatSheet = _sheet()
	if sheet != null:
		sheet.remove_from(kit.kit_id)
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null:
		for status_id: StringName in _passives:
			statuses.cure(status_id)
	for executor: PowerExecutor in _running.values():
		executor.end()
	gauges.clear(get_parent())
	gauges = KitGauges.new()
	_passives.clear()
	_running.clear()
	# Every cooldown goes with the kit, so each one is announced as over, once it is gone.
	var cooled: Dictionary[StringName, float] = _cooling.duplicate()
	_cooling.clear()
	for power_id: StringName in cooled:
		_announce(power_id, cooled[power_id], 0.0)
	kit = null


## True when `power` is one of the equipped kit's own.
func has(power: Power) -> bool:
	return kit != null and power != null and kit.powers.has(power)


## How long before `power_id` can be used again: seconds in the field, turns in a battle.
func cooldown_left(power_id: StringName) -> float:
	return _cooling.get(power_id, 0.0)


## Starts `power`'s cooldown. `PowerUse.use` calls it after a use.
func start_cooldown(power: Power) -> void:
	if power.cooldown > 0.0:
		var before: float = cooldown_left(power.power_id)
		_cooling[power.power_id] = power.cooldown
		_announce(power.power_id, before, power.cooldown)


## Every running executor of the kit, in no set order: a form uses it to find its rivals (C6.5a).
func running() -> Array[PowerExecutor]:
	var out: Array[PowerExecutor] = []
	out.assign(_running.values())
	return out


## `power` was just used (`PowerUse.use`): every running mechanism hears of it (C6.5a).
func used(power: Power) -> void:
	for executor: PowerExecutor in _running.values():
		executor.power_used(power)


## The running executor of `power_id`'s mechanism, or null.
func executor(power_id: StringName) -> PowerExecutor:
	return _running.get(power_id, null)


## `delta` seconds of fight time pass: cooldowns count down, mechanisms tick, gauges move.
func tick_seconds(delta: float) -> void:
	_count_down(delta)
	gauges.tick_seconds(get_parent(), delta)


## The fighter started `move` in the field: a gauge's `on_new_move` counts when it is new, and
## every running mechanism hears of it (a form's drain per action, C6.5b).
func moved(move: ActionMove) -> void:
	gauges.moved(get_parent(), move)
	for executor: PowerExecutor in _running.values():
		executor.moved(move)


## The moves the fighter plays in the field now: `base` (its own), handed through each running
## mechanism in the kit's order, so a form can put its own chain and dodge in (C6.5b).
func moves_over(base: MoveSet) -> MoveSet:
	var out: MoveSet = base
	if kit == null:
		return out
	for power: Power in kit.powers:
		var running: PowerExecutor = executor(power.power_id) if power != null else null
		if running != null:
			out = running.moves(out)
	return out


## The fighter paid `amount` points of `pool` as a cost: `SkillUse.pay` says so.
func spent(pool: StringName, amount: int) -> void:
	gauges.spent(get_parent(), pool, amount)


## One of this fighter's battle turns passes.
func tick_turn() -> void:
	_count_down(1.0)
	gauges.tick_turn(get_parent())


func _count_down(amount: float) -> void:
	if amount <= 0.0:
		return
	for power_id: StringName in _cooling.keys():
		var before: float = _cooling[power_id]
		var left: float = before - amount
		if left <= 0.0:
			_cooling.erase(power_id)
		else:
			_cooling[power_id] = left
		_announce(power_id, before, maxf(left, 0.0))
	for running: PowerExecutor in _running.values():
		running.tick(amount)


# Puts each of the kit's passives on, unless it is already held (a save that kept it), and
# remembers it so `unequip` takes it off again.
func _hold_passives() -> void:
	var statuses: StatusSet = StatusSet.of(get_parent())
	if kit == null or statuses == null:
		return
	for passive: StatusEffect in kit.passives:
		if passive == null:
			continue
		if statuses.stacks(passive.id) == 0:
			statuses.apply(passive)
		if statuses.stacks(passive.id) > 0 and not _passives.has(passive.id):
			_passives.append(passive.id)


# Called after the cooldown has changed, so a listener reading `cooldown_left` sees the new value.
# Tells everyone when the whole seconds or turns left on `power_id` change, from `before` to
# `after`; nothing when only a fraction of one passed.
func _announce(power_id: StringName, before: float, after: float) -> void:
	if ceili(before) == ceili(after):
		return
	Events.power_cooldown_changed.emit(_id(), power_id, ceili(after))


func _on_game_loaded(_slot: int) -> void:
	_hold_passives()


# A hit landed or taken moves the gauges; a heal (a negative amount) does not.
func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	var me: StringName = _id()
	var felled: bool = who != &"" and who == _just_fell
	_just_fell = &""
	if amount <= 0 or me == &"":
		return
	if felled and by == me and who != me:
		gauges.happen(get_parent(), GaugeRule.Event.KILL)
	if by == me:
		gauges.happen(get_parent(), GaugeRule.Event.HIT_DEALT)
	if who == me:
		gauges.happen(get_parent(), GaugeRule.Event.HIT_TAKEN)


# Remembers who fell, for the damage event that follows; and an ally falling moves the gauges.
func _on_defeated(who: StringName) -> void:
	_just_fell = who
	var me: Combatant = Combatant.of(get_parent())
	if me == null or who == &"" or who == me.combatant_id:
		return
	var other: Combatant = Combatant.find(get_tree(), who)
	if other != null and me.can_target(other, FactionTable.Target.ALLY):
		gauges.happen(get_parent(), GaugeRule.Event.ALLY_DEFEATED)


func _on_revived(who: StringName) -> void:
	if who == _just_fell:
		_just_fell = &""


func _on_dodged(who: StringName, _by: StringName) -> void:
	if who != &"" and who == _id():
		gauges.happen(get_parent(), GaugeRule.Event.DODGE)


# `who` is the one the attack missed; `by` threw it.
func _on_missed(_who: StringName, by: StringName) -> void:
	if by != &"" and by == _id():
		gauges.happen(get_parent(), GaugeRule.Event.MISS)


func _on_vitals_changed(who: StringName, pool: StringName, _value: int, _maximum: int) -> void:
	if who != &"" and who == _id() and gauges.has_pool(pool):
		gauges.refresh_levels(get_parent(), pool)


func _id() -> StringName:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.combatant_id if fighter != null else &""


## The fighter's sheet, which its `Vitals` and `StatusSet` share.
func _sheet() -> StatSheet:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.sheet if fighter != null else null
