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
##   when time passes and when the fighter lands a hit, takes one, dodges (perfectly too, C6.6c)
##   or misses, and every change to a gauge pool, whoever made it, moves that gauge's level
##   status. Since C6.4b it also hears a kill, an ally falling, a new move (`moved`, from
##   `ActionFighter`) and a cost paid (`spent`, from `SkillUse.pay`).
## - every running mechanism hears of each power used (`used`, from `PowerUse.use`, C6.5a), so a
##   form's cycle can move on after a finisher.
## - in the field, the fighter plays the moves its running mechanisms hand it (`moves_over`,
##   C6.5b): a form's own attack chain and dodge.
## - a hit about to land on the fighter, or on an ally, is shown to every running mechanism
##   first (`PowerGuard.incoming`, then `intercept_incoming` here, C6.6a), so a barrier can stop or soften it.
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
## (`_hold_passives`), never twice. A form's status IS saved, by the `StatusSet`, and found
## again on load through `passive_of` (C6.5c), so a form outlives a save though its executor
## does not.
##
## A PARTY SWITCH MOVES THIS NODE to another body (`FieldParty`), and moving a node makes it
## leave the tree and enter again. So its mechanisms end only when it is freed, not when it
## leaves the tree.
##
## SEVERAL KITS AT ONCE (C7.3). The fighter's own kit is `kit`, put on with `equip`. A worn piece
## of gear can lend one more kit each (`lend`, called by `GearSet`), held under its own source.
## Every kit's powers, passives, gauges and stat bonuses are live together, the fighter's own
## first. Taking one kit off removes only that kit's parts. Two kits on one fighter should not
## share a power id or a passive: the set tells them apart by those ids.
##
## OWNS: which kits are on, their cooldowns, its running executors, and its gauges.
## MUST NOT: decide whether a power may be used, or use one. `PowerUse` does both.

## The fighter's own kit, from its definition. Null when it has none.
var kit: PowerKit
# Kits lent by what the fighter wears (C7.3): source -> kit, in the order their powers are listed.
var _lent: Dictionary[StringName, PowerKit] = {}
# Kits a battlefield holds on its caster while it stands (C6.9e), by the source they went on under.
var _held: Dictionary[StringName, PowerKit] = {}
var _cooling: Dictionary[StringName, float] = {}
var _running: Dictionary[StringName, PowerExecutor] = {}
var _passives: Array[StringName] = []
## The once-per-battle powers already used (C6.5f). Forgotten when an area is entered (which a
## new game and a load also do); a battle builds a fresh set, so a new battle starts clean.
## Taking a kit off does not forget it, so swapping gear cannot buy a second use.
var once: OnceLedger = OnceLedger.new()
## The equipped kit's gauges. Empty, never null, with no kit.
var gauges: KitGauges = KitGauges.new()
# The gauge side of what this fighter hears (C6.4a); it remembers who just fell (a kill).
var _feed := PowerGaugeFeed.new()


## The set under `who`, or null.
static func of(who: Node) -> PowerSet:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: PowerSet = child as PowerSet
		if found != null:
			return found
	return null


## The status `status_id` granted by a kit worn under `who`, or null: a passive, or a form's
## status (C6.5c). Such a status lives only in its kit file, so `StatusSet` finds it here when it
## loads a save (C6.2b), and a form held when the game was saved is held again.
static func passive_of(who: Node, status_id: StringName) -> StatusEffect:
	var powers: PowerSet = of(who)
	return powers.status(status_id) if powers != null else null


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
		[Events.combatant_defeated, _on_defeated], [Events.combatant_revived, _on_revived],
		[Events.area_entered, once.forget], [Events.perfect_dodge, _on_perfect_dodge]]


func _notification(what: int) -> void:
	# Freed: its mechanisms stop. Not on leaving the tree, which a party switch does.
	if what == NOTIFICATION_PREDELETE:
		for executor: PowerExecutor in _running.values():
			executor.end()


## Puts `new_kit` on as the fighter's own kit, taking off whatever own kit was on first. Null
## just takes the old one off. Kits lent by gear stay as they are.
func equip(new_kit: PowerKit) -> void:
	unequip()
	kit = new_kit
	if kit != null:
		_put_on(kit, kit.kit_id)


## Takes the fighter's own kit off: its stat bonuses, passives, executors and cooldowns.
func unequip() -> void:
	if kit == null:
		return
	var old: PowerKit = kit
	kit = null
	_take_off(old, old.kit_id)


## Sets the kits lent by what the fighter wears (C7.3): `wanted` is source -> kit, in the order
## their powers should be listed. A kit already lent under the same source is left alone, so
## its cooldowns and forms carry on; one no longer wanted comes off; a new one goes on.
func lend(wanted: Dictionary[StringName, PowerKit]) -> void:
	for source: StringName in _lent.keys():
		if wanted.get(source) != _lent[source]:
			var old: PowerKit = _lent[source]
			_lent.erase(source)
			_take_off(old, source)
	var before: Dictionary[StringName, PowerKit] = _lent
	_lent = {}
	for source: StringName in wanted:
		if wanted[source] != null:
			_lent[source] = wanted[source]
	for source: StringName in _lent:
		if not before.has(source):
			_put_on(_lent[source], source)


## Puts `held_kit` on the fighter under `source` until `release_kit` takes it off (C6.9e: a kit a
## battlefield lends its caster while it stands). A source already holding one is left alone.
func hold_kit(held_kit: PowerKit, source: StringName) -> void:
	if held_kit != null and not _held.has(source):
		_held[source] = held_kit
		_put_on(held_kit, source)


## Takes off the kit held under `source`, if one is held (C6.9e).
func release_kit(source: StringName) -> void:
	if _held.has(source):
		_take_off(_held[source], source)
		_held.erase(source)


## Every kit on the fighter: its own first, then each lent one, then each held one, in order.
func kits() -> Array[PowerKit]:
	var out: Array[PowerKit] = []
	if kit != null:
		out.append(kit)
	out.append_array(_lent.values())
	out.append_array(_held.values())
	return out


## Every power of every kit on the fighter, in the order menus and quick slots list them.
func powers() -> Array[Power]:
	var out: Array[Power] = []
	for held: PowerKit in kits():
		for power: Power in held.powers:
			if power != null:
				out.append(power)
	return out


## The status `status_id` granted by any kit on the fighter (a passive or a form's), or null.
func status(status_id: StringName) -> StatusEffect:
	for held: PowerKit in kits():
		var found: StatusEffect = held.status(status_id)
		if found != null:
			return found
	return null


# Puts one kit's parts on the fighter. Its stat bonuses are held under `source`, so taking the
# kit off removes exactly these.
func _put_on(added: PowerKit, source: StringName) -> void:
	var sheet: StatSheet = _sheet()
	if sheet != null:
		for bonus: StatModifier in added.stat_bonuses:
			if bonus != null:
				sheet.add(StatModifier.of(bonus.stat, bonus.op, bonus.value, source))
	_hold_passives()
	_regauge()
	for power: Power in added.powers:
		if power == null or power.mechanism == null:
			continue
		var executor: PowerExecutor = PowerMechanisms.make(power.mechanism)
		if executor != null:
			executor.power = power
			executor.holder = self
			_running[power.power_id] = executor


# Takes one kit's parts off again, and nothing of any other kit.
func _take_off(removed: PowerKit, source: StringName) -> void:
	var sheet: StatSheet = _sheet()
	if sheet != null:
		sheet.remove_from(source)
	var statuses: StatusSet = StatusSet.of(get_parent())
	for passive: StatusEffect in removed.passives:
		if passive != null and _passives.has(passive.id):
			_passives.erase(passive.id)
			if statuses != null:
				statuses.cure(passive.id)
	for power: Power in removed.powers:
		if power == null:
			continue
		if _running.has(power.power_id):
			_running[power.power_id].end()
			_running.erase(power.power_id)
		# Its cooldown goes with the kit, and is announced as over once it is gone.
		var left: float = cooldown_left(power.power_id)
		_cooling.erase(power.power_id)
		_announce(power.power_id, left, 0.0)
	_regauge()


# Builds the gauges again from every kit on the fighter. The gauge pools keep their points.
func _regauge() -> void:
	gauges.clear(get_parent())
	var rules: Array[GaugeRule] = []
	for held: PowerKit in kits():
		rules.append_array(held.gauges)
	gauges = KitGauges.new(rules)
	for pool: StringName in gauges.pools():
		gauges.refresh_levels(get_parent(), pool)


## True when `power` belongs to a kit on the fighter, its own or a lent one.
func has(power: Power) -> bool:
	return power != null and powers().has(power)


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
	for power: Power in powers():
		var running: PowerExecutor = executor(power.power_id)
		if running != null:
			out = running.moves(out)
	return out


## Shows a hit about to land on `target` to each running mechanism, in the kit's order (C6.6a).
func intercept_incoming(target: Combatant, result: DamageResult, from: StringName) -> void:
	for power: Power in powers():
		var running: PowerExecutor = executor(power.power_id)
		if running != null:
			running.intercept_incoming(target, result, from)


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


# Puts the passives of every kit on, unless it is already held (a save that kept it), and
# remembers it so `unequip` takes it off again.
func _hold_passives() -> void:
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses == null:
		return
	for held: PowerKit in kits():
		for passive: StatusEffect in held.passives:
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


# The gauge handlers below hand each event to the feed (`PowerGaugeFeed`), which owns the rules.
func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	_feed.damaged(self, who, by, amount)


func _on_defeated(who: StringName) -> void:
	_feed.defeated(self, who)


func _on_revived(who: StringName) -> void:
	_feed.revived(who)


func _on_dodged(who: StringName, _by: StringName) -> void:
	_feed.dodged(self, who)


func _on_perfect_dodge(who: StringName, _by: StringName) -> void:
	_feed.perfect_dodged(self, who)


func _on_missed(_who: StringName, by: StringName) -> void:
	_feed.missed(self, by)


func _on_vitals_changed(who: StringName, pool: StringName, _value: int, _maximum: int) -> void:
	_feed.vitals_changed(self, who, pool)


func _id() -> StringName:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.combatant_id if fighter != null else &""


## The fighter's sheet, which its `Vitals` and `StatusSet` share.
func _sheet() -> StatSheet:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.sheet if fighter != null else null
