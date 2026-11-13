class_name PassiveSet
extends Node
## The passives one fighter holds (C9.1): a child of the body, beside its `Vitals`, `StatusSet`
## and `Combatant`. See `docs/PASSIVES.md` § The passive.
##
## IN PLAIN WORDS: each source (the character itself, a kit, a piece of gear, later the loadout)
## hands this set its list of `PassiveSkill`s under its own name (`hold`, through
## `PassiveLending`), and takes it back with `release`. While a passive is held:
## - its `held` status sits on the fighter (and comes off when no source holds it any more);
## - each of its triggers waits for its event. When the event happens this set rolls the
##   trigger's chance, checks its cooldown and limit, and runs its effects.
## The same passive from two sources counts once, and of passives sharing a `group` only the
## highest `rank` counts (C9.2a).
##
## A trigger's `conditions` are asked just before it wakes (`PassiveConditions`). The HP-line
## events wake once as the holder's HP share crosses the line; a status gained while one of
## this set's own effects is running wakes nothing, so a passive cannot feed itself.
##
## EARLY TRIGGERS (C9.2b) wake before a hit lands, through `before` (`PassiveHits` calls it):
## those that scale the hit, and LETHAL_HIT. A trigger never wakes inside itself, and a hit the
## holder deals from one of its own effects (EXTRA_HIT) wakes none of its dealt-hit triggers,
## so two passives cannot feed each other forever.
##
## A FIELD BODY SLEEPS DURING A TURN-BASED BATTLE: a party member's battle copy shares its id
## and its pools, and only the copy's set may answer the battle's events.
##
## WHAT IT HEARS. A battle tells it when the holder's turn begins (`turn`). Everything else comes
## from `Events`: a battle starting, an area entered, a hit, a fighter falling. A kill is told
## as `PowerSet` tells it: the id that just fell is remembered, and a damage event on that id
## thrown by this fighter is its kill.
##
## TIME, IN BOTH FORMULAS. In a battle a cooldown counts in the holder's turns, counted down as
## the turn begins and before the turn's own triggers, so a cooldown of 2 wakes every second
## turn. In the field it counts in seconds of fight time, and TURN_START wakes every `interval`
## seconds. A limit lasts one battle (each battle builds a fresh set) or, in the field, until
## the next area is entered.
##
## A FALLEN HOLDER'S PASSIVES DO NOTHING until it is back up.
##
## NOT SAVED: the lists come from the fighter's definition each time it is built, and a
## cooldown is a moment's state. The held statuses ARE saved by the `StatusSet`, which finds
## them again through `held_of`; after a new game or a load this set puts back any missing one.
##
## OWNS: who gave which passives, their held statuses, and each trigger's cooldown and count.
## MUST NOT: say what an effect does. `PassiveEffects` does.

## The source a fighter's own passives (`CombatantDef.passives`) are held under.
const OWN: StringName = &"own"
## The events of a hit the holder deals.
const DEALT: Array[PassiveTrigger.Event] = [PassiveTrigger.Event.HIT_DEALT, PassiveTrigger.Event.CRIT_DEALT]

## The random numbers chances are rolled with. A battle hands over its own (`join`), so a
## seeded battle replays the same.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sources: Dictionary[StringName, Array] = {}
var _statuses: Array[StringName] = []
var _cooling: Dictionary[PassiveTrigger, float] = {}
var _woken: Dictionary[PassiveTrigger, int] = {}
var _waited: Dictionary[PassiveTrigger, float] = {}
var _just_fell: StringName = &""
var _battling: bool = false
# The triggers whose effects are running right now. A trigger never wakes inside itself.
var _running: Array[PassiveTrigger] = []
# The holder's HP share before and after the last change, for the HP-line events.
var _was: float = -1.0
var _now: float = -1.0
var _gained: Array[StringName] = []


## The set under `who`, or null.
static func of(who: Node) -> PassiveSet:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: PassiveSet = child as PassiveSet
		if found != null:
			return found
	return null


## The held status `status_id` of a passive on `who`, or null. Such a status may live only in
## its passive's file, so `StatusSet` finds it here when it loads a save.
static func held_of(who: Node, status_id: StringName) -> StatusEffect:
	var passives: PassiveSet = of(who)
	if passives == null:
		return null
	for passive: PassiveSkill in passives.passives():
		if passive.held != null and passive.held.id == status_id:
			return passive.held
	return null


## A battle begins with the fighter under `body` in it: its chances use the battle's `seeded`.
static func join(body: Node, seeded: RandomNumberGenerator) -> void:
	var passives: PassiveSet = of(body)
	if passives != null and seeded != null:
		passives.rng = seeded


## One battle turn of the fighter under `body` begins.
static func turn(body: Node) -> void:
	var passives: PassiveSet = of(body)
	if passives != null:
		passives._count_down(1.0)
		passives._wake(PassiveTrigger.Event.TURN_START, null, 0)


func _ready() -> void:
	rng.randomize()


func _physics_process(delta: float) -> void:
	var fighter: Combatant = Combatant.of(get_parent())
	if fighter == null or not fighter.real_time:
		return
	var seconds: float = CombatClock.scaled(delta)
	_count_down(seconds)
	for passive: PassiveSkill in passives():
		for trigger: PassiveTrigger in passive.triggers:
			if trigger == null or trigger.event != PassiveTrigger.Event.TURN_START:
				continue
			_waited[trigger] = _waited.get(trigger, 0.0) + seconds
			if _waited[trigger] >= trigger.interval:
				_waited[trigger] -= trigger.interval
				_try(trigger, fighter, null, 0)


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


func _listens() -> Array[Array]:
	return [[Events.game_started, _sync_held], [Events.game_loaded, _on_game_loaded],
		[Events.battle_started, _on_battle_started], [Events.area_entered, _on_area_entered],
		[Events.combatant_damaged, _on_damaged], [Events.combatant_defeated, _on_defeated],
		[Events.combatant_revived, _on_revived], [Events.battle_ended, _on_battle_ended],
		[Events.attack_dodged, _on_dodged], [Events.attack_blocked, _on_blocked],
		[Events.vitals_changed, _on_vitals], [Events.status_applied, _on_status]]


## Holds `given` under `source`, in place of whatever that source gave before.
func hold(source: StringName, given: Array[PassiveSkill]) -> void:
	var kept: Array[PassiveSkill] = []
	for passive: PassiveSkill in given:
		if passive != null and not kept.has(passive):
			kept.append(passive)
	_sources[source] = kept
	_sync_held()


## Takes back everything `source` gave. Another source's passives stay.
func release(source: StringName) -> void:
	if _sources.erase(source):
		_sync_held()


## The names passives are held under now.
func sources() -> Array[StringName]:
	return _sources.keys()


## Every passive that counts, each once, in the order the sources gave them. Of passives in
## one `group`, only the highest `rank` is here (the first given, on a tie).
func passives() -> Array[PassiveSkill]:
	var out: Array[PassiveSkill] = []
	var best: Dictionary[StringName, PassiveSkill] = {}
	for source: StringName in _sources:
		for passive: PassiveSkill in _sources[source]:
			if out.has(passive):
				continue
			out.append(passive)
			if passive.group != &"" and (not best.has(passive.group) or passive.rank > best[passive.group].rank):
				best[passive.group] = passive
	return out.filter(func(passive: PassiveSkill) -> bool:
		return passive.group == &"" or best[passive.group] == passive)


# Puts on the held status of every passive, and takes off one no passive gives any more.
func _sync_held() -> void:
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses == null:
		return
	var wanted: Array[StringName] = []
	for passive: PassiveSkill in passives():
		if passive.held == null:
			continue
		wanted.append(passive.held.id)
		if statuses.stacks(passive.held.id) == 0:
			statuses.apply(passive.held)
		if statuses.stacks(passive.held.id) > 0 and not _statuses.has(passive.held.id):
			_statuses.append(passive.held.id)
	for status_id: StringName in _statuses.duplicate():
		if not wanted.has(status_id):
			_statuses.erase(status_id)
			statuses.cure(status_id)


func _count_down(amount: float) -> void:
	for trigger: PassiveTrigger in _cooling.keys():
		_cooling[trigger] -= amount
		if _cooling[trigger] <= 0.0:
			_cooling.erase(trigger)


## A hit is about to land (`PassiveHits`): the EARLY triggers of `event` get their try.
func before(event: PassiveTrigger.Event, other: Combatant, damage: int) -> void:
	_wake(event, other, damage, true)


## A moment `PassiveMoments` tells of (C9.2c): a skill used, with its `tags`; a form's start or end.
func happened(event: PassiveTrigger.Event, tags: Array[StringName]) -> void:
	_gained = tags
	_wake(event, null, 0)
	_gained = []


# `event` happened to the holder: every held trigger waiting for it gets its try. A hit the
# holder deals while one of its own effects runs (an extra hit) wakes no dealt-hit trigger.
func _wake(event: PassiveTrigger.Event, other: Combatant, damage: int, early: bool = false) -> void:
	var me: Combatant = Combatant.of(get_parent())
	if me == null or (me.real_time and _battling):
		return
	if not _running.is_empty() and DEALT.has(event):
		return
	for passive: PassiveSkill in passives():
		for trigger: PassiveTrigger in passive.triggers:
			if trigger != null and trigger.event == event and trigger.early() == early and _fits(trigger):
				_try(trigger, me, other, damage)


# What the event itself asks of a trigger: its HP line crossed, its status or skill tag met.
func _fits(trigger: PassiveTrigger) -> bool:
	match trigger.event:
		PassiveTrigger.Event.HP_BELOW:
			return _was >= trigger.threshold and _now < trigger.threshold
		PassiveTrigger.Event.HP_ABOVE:
			return _was < trigger.threshold and _now >= trigger.threshold
		PassiveTrigger.Event.STATUS_GAINED, PassiveTrigger.Event.SKILL_USED:
			return trigger.tag == &"" or _gained.has(trigger.tag)
	return true


func _try(trigger: PassiveTrigger, me: Combatant, other: Combatant, damage: int) -> void:
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals == null or vitals.is_defeated() or _cooling.has(trigger) or _running.has(trigger):
		return
	if trigger.limit > 0 and _woken.get(trigger, 0) >= trigger.limit:
		return
	if not PassiveConditions.all(trigger.conditions, me, other):
		return
	if trigger.chance < 1.0 and rng.randf() >= trigger.chance:
		return
	_woken[trigger] = _woken.get(trigger, 0) + 1
	if trigger.cooldown > 0.0:
		_cooling[trigger] = trigger.cooldown
	_running.append(trigger)
	for effect: PassiveEffect in trigger.effects:
		if effect != null:
			PassiveEffects.run(effect, me, other, damage, rng)
	_running.erase(trigger)


func _on_game_loaded(_slot: int) -> void:
	_sync_held()


func _on_battle_started(_enemy_ids: Array[StringName]) -> void:
	_battling = true
	var me: Combatant = Combatant.of(get_parent())
	if me != null and not me.real_time:
		_wake(PassiveTrigger.Event.FIGHT_START, null, 0)


# A new area is a new fight in the field: counts and waits start again.
func _on_area_entered(_area_id: StringName) -> void:
	var me: Combatant = Combatant.of(get_parent())
	_battling = false
	if me != null and me.real_time:
		_woken.clear()
		_cooling.clear()
		_wake(PassiveTrigger.Event.FIGHT_START, null, 0)


# A hit landed. A heal (a negative amount) is not a hit.
func _on_damaged(who: StringName, by: StringName, amount: int, critical: bool) -> void:
	var me: Combatant = Combatant.of(get_parent())
	var felled: bool = who != &"" and who == _just_fell
	_just_fell = &""
	if me == null or amount <= 0 or who == by:
		return
	if by == me.combatant_id:
		var struck: Combatant = PassiveEffects.find(me, who)
		_wake(PassiveTrigger.Event.HIT_DEALT, struck, amount)
		if critical:
			_wake(PassiveTrigger.Event.CRIT_DEALT, struck, amount)
		if felled:
			_wake(PassiveTrigger.Event.KILL, struck, amount)
	elif who == me.combatant_id:
		_wake(PassiveTrigger.Event.HIT_TAKEN, PassiveEffects.find(me, by), amount)


# Remembers who fell, for the damage event that follows. An ally falling, and the last foe
# falling, wake their own events here.
func _on_defeated(who: StringName) -> void:
	_just_fell = who
	var me: Combatant = Combatant.of(get_parent())
	var fallen: Combatant = PassiveEffects.find(me, who)
	if fallen == null or fallen == me or fallen.real_time != me.real_time:
		return
	if me.can_target(fallen, FactionTable.Target.ALLY):
		_wake(PassiveTrigger.Event.ALLY_DEFEATED, fallen, 0)
	elif me.can_target(fallen, FactionTable.Target.ENEMY) and PassiveEffects.side(me, true).is_empty():
		_wake(PassiveTrigger.Event.FIGHT_WON, fallen, 0)


func _on_revived(who: StringName) -> void:
	if who == _just_fell:
		_just_fell = &""


func _on_battle_ended(_outcome: int) -> void:
	_battling = false


func _on_dodged(who: StringName, by: StringName) -> void:
	var me: Combatant = Combatant.of(get_parent())
	if me != null and who == me.combatant_id:
		_wake(PassiveTrigger.Event.DODGE, PassiveEffects.find(me, by), 0)


func _on_blocked(who: StringName, by: StringName) -> void:
	var me: Combatant = Combatant.of(get_parent())
	if me != null and who == me.combatant_id:
		_wake(PassiveTrigger.Event.GUARD, PassiveEffects.find(me, by), 0)


# The holder's own pool is read, not the event's numbers: a battle copy shares this id.
func _on_vitals(who: StringName, pool: StringName, _value: int, _maximum: int) -> void:
	var me: Combatant = Combatant.of(get_parent())
	var vitals: Vitals = Vitals.of(get_parent())
	if me == null or vitals == null or who != me.combatant_id or pool != me.damage_pool:
		return
	_was = _now if _now >= 0.0 else 1.0
	_now = float(vitals.current(pool)) / float(maxi(1, vitals.maximum(pool)))
	_wake(PassiveTrigger.Event.HP_BELOW, null, 0)
	_wake(PassiveTrigger.Event.HP_ABOVE, null, 0)
	_was = _now


func _on_status(who: StringName, status_id: StringName, _stacks: int) -> void:
	var me: Combatant = Combatant.of(get_parent())
	var statuses: StatusSet = StatusSet.of(get_parent())
	if me == null or statuses == null or not _running.is_empty() or who != me.combatant_id:
		return
	for status: StatusEffect in statuses.held():
		if status.id == status_id:
			_gained = status.tags
			_wake(PassiveTrigger.Event.STATUS_GAINED, null, 0)
	_gained = []
