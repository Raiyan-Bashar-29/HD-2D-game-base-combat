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
## counts in turns: `Battle` calls `tick_turn` at its turn's end (wired in C6.2).
##
## NOT SAVED: the kit comes from the loadout or the definition each time a fighter is built
## (C6.2), and a cooldown is a moment's state, like the ATB gauge.
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


func _physics_process(delta: float) -> void:
	var fighter: Combatant = Combatant.of(get_parent())
	if fighter != null and fighter.real_time:
		tick_seconds(CombatClock.scaled(delta))


func _exit_tree() -> void:
	# A body leaving the world stops its mechanisms; its kit stays for when it comes back.
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
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null:
		for passive: StatusEffect in kit.passives:
			if passive != null and statuses.stacks(passive.id) == 0 and statuses.apply(passive):
				_passives.append(passive.id)
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


## The fighter's sheet, which its `Vitals` and `StatusSet` share.
func _sheet() -> StatSheet:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.sheet if fighter != null else null
