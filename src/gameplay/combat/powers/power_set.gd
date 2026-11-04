class_name PowerSet
extends Node
## The hero powers one fighter has equipped (C6.1b): a child of the body, beside its `Vitals`,
## `StatusSet` and `Combatant`. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: `equip` puts a `PowerKit` on the fighter. While it is on:
## - its `stat_bonuses` sit on the fighter's sheet, under the kit's id as their source;
## - its `passives` are held as statuses (give them duration 0, so they never run out);
## - each power with a mechanism has its own running `PowerExecutor`;
## - each power used counts down its cooldown here.
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
## OWNS: which kit is equipped, its cooldowns, and its running executors.
## MUST NOT: decide whether a power may be used, or use one. `PowerUse` does both.

var kit: PowerKit
var _cooling: Dictionary[StringName, float] = {}
var _running: Dictionary[StringName, PowerExecutor] = {}
var _passives: Array[StringName] = []


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
	if not Events.game_started.is_connected(_hold_passives):
		Events.game_started.connect(_hold_passives)
	if not Events.game_loaded.is_connected(_on_game_loaded):
		Events.game_loaded.connect(_on_game_loaded)


func _exit_tree() -> void:
	if Events.game_started.is_connected(_hold_passives):
		Events.game_started.disconnect(_hold_passives)
	if Events.game_loaded.is_connected(_on_game_loaded):
		Events.game_loaded.disconnect(_on_game_loaded)


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
	_passives.clear()
	_running.clear()
	_cooling.clear()
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
		_cooling[power.power_id] = power.cooldown


## The running executor of `power_id`'s mechanism, or null.
func executor(power_id: StringName) -> PowerExecutor:
	return _running.get(power_id, null)


## `delta` seconds of fight time pass: cooldowns count down and mechanisms tick.
func tick_seconds(delta: float) -> void:
	_count_down(delta)


## One of this fighter's battle turns passes.
func tick_turn() -> void:
	_count_down(1.0)


func _count_down(amount: float) -> void:
	if amount <= 0.0:
		return
	for power_id: StringName in _cooling.keys():
		var left: float = _cooling[power_id] - amount
		if left <= 0.0:
			_cooling.erase(power_id)
		else:
			_cooling[power_id] = left
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


func _on_game_loaded(_slot: int) -> void:
	_hold_passives()


## The fighter's sheet, which its `Vitals` and `StatusSet` share.
func _sheet() -> StatSheet:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.sheet if fighter != null else null
