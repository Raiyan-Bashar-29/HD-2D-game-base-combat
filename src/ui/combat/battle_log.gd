class_name BattleLog
extends RefCounted
## The battle's running commentary (C2.19): the combat signals on the bus, turned into short
## lines a player reads, newest last, only the last `MAX_LINES` kept.
##
## IN PLAIN WORDS: while a battle screen is open, this listens on `Events` for damage, misses,
## counters, reflects, breaks, revealed weaknesses, statuses and defeats, and writes one line for
## each: "Wisp takes 12.", "The attack on Wisp missed.", "Wisp is broken!". `BattleScreen` shows
## `lines` under the turn order.
##
## IT ONLY LISTENS. Every line comes from a signal another system already emits, so the log can
## never disagree with what happened. Names come from the screen's `namer`, so a duplicate
## enemy reads "Wisp 2" here just as in the menu.
##
## OWNS: the lines, and connecting to and disconnecting from the bus.
## MUST NOT: change the battle, or keep listening after `stop()`: a closed screen's log is dead.

const MAX_LINES: int = 4
const DAMAGE_KEY: String = "ui.battle.log.damage"
const CRITICAL_KEY: String = "ui.battle.log.critical"
const HEALED_KEY: String = "ui.battle.log.healed"
const MISSED_KEY: String = "ui.battle.log.missed"
const RESISTED_KEY: String = "ui.battle.log.resisted"
const SKIPPED_KEY: String = "ui.battle.log.skipped"
const COUNTERED_KEY: String = "ui.battle.log.countered"
const REFLECTED_KEY: String = "ui.battle.log.reflected"
const WEAK_KEY: String = "ui.battle.log.weak"
const BROKEN_KEY: String = "ui.battle.log.broken"
const DEFEATED_KEY: String = "ui.battle.log.defeated"
const STATUS_KEY: String = "ui.battle.log.status"

## Oldest first; never more than MAX_LINES.
var lines: Array[String] = []
var _battle: Battle
## Turns a combatant into the name the player sees. The screen passes its own `name_of`.
var _namer: Callable


func _init(battle: Battle, namer: Callable) -> void:
	_battle = battle
	_namer = namer


## Starts listening. The screen calls it when it opens.
func start() -> void:
	Events.combatant_damaged.connect(_on_damaged)
	Events.attack_missed.connect(_on_missed)
	Events.status_resisted.connect(_on_resisted)
	Events.turn_skipped.connect(_on_skipped)
	Events.countered.connect(_on_countered)
	Events.skill_reflected.connect(_on_reflected)
	Events.weakness_revealed.connect(_on_weak)
	Events.combatant_broken.connect(_on_broken)
	Events.combatant_defeated.connect(_on_defeated)
	Events.status_applied.connect(_on_status)


## Stops listening. The screen calls it when it closes, so a later battle's signals land only
## in that battle's own log.
func stop() -> void:
	for pair: Array in [[Events.combatant_damaged, _on_damaged], [Events.attack_missed, _on_missed],
			[Events.status_resisted, _on_resisted], [Events.turn_skipped, _on_skipped],
			[Events.countered, _on_countered], [Events.skill_reflected, _on_reflected],
			[Events.weakness_revealed, _on_weak], [Events.combatant_broken, _on_broken],
			[Events.combatant_defeated, _on_defeated], [Events.status_applied, _on_status]]:
		var bus: Signal = pair[0]
		var handler: Callable = pair[1]
		if bus.is_connected(handler):
			bus.disconnect(handler)


## The status's own name: from its `name_key` when the fighter holds it or the catalogue has it,
## else the last part of its id.
func status_name(who: StringName, status_id: StringName) -> String:
	var fighter: Combatant = _fighter(who)
	var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if fighter != null else null
	if statuses != null:
		for effect: StatusEffect in statuses.held():
			if effect.id == status_id and effect.name_key != "":
				return TranslationServer.translate(effect.name_key)
	var known: StatusEffect = StatusDb.status(status_id)
	if known != null and known.name_key != "":
		return TranslationServer.translate(known.name_key)
	return String(status_id).get_slice("/", String(status_id).get_slice_count("/") - 1)


func _add(key: String, values: Dictionary) -> void:
	lines.append(TranslationServer.translate(key).format(values))
	while lines.size() > MAX_LINES:
		lines.pop_front()


func _name(who: StringName) -> String:
	var fighter: Combatant = _fighter(who)
	return _namer.call(fighter) as String if fighter != null else String(who)


func _fighter(who: StringName) -> Combatant:
	for fighter: Combatant in _battle.party + _battle.enemies:
		if is_instance_valid(fighter) and fighter.combatant_id == who:
			return fighter
	return null


func _on_damaged(who: StringName, _by: StringName, amount: int, critical: bool) -> void:
	if amount < 0:
		_add(HEALED_KEY, {"name": _name(who), "amount": -amount})
	else:
		_add(CRITICAL_KEY if critical else DAMAGE_KEY, {"name": _name(who), "amount": amount})


func _on_missed(who: StringName, _by: StringName) -> void:
	_add(MISSED_KEY, {"name": _name(who)})


func _on_resisted(who: StringName, status_id: StringName) -> void:
	_add(RESISTED_KEY, {"name": _name(who), "status": status_name(who, status_id)})


func _on_skipped(who: StringName, status_id: StringName) -> void:
	_add(SKIPPED_KEY, {"name": _name(who), "status": status_name(who, status_id)})


func _on_countered(who: StringName, _against: StringName) -> void:
	_add(COUNTERED_KEY, {"name": _name(who)})


func _on_reflected(who: StringName, _back_to: StringName, _skill_id: StringName) -> void:
	_add(REFLECTED_KEY, {"name": _name(who)})


func _on_weak(who: StringName, key: StringName) -> void:
	_add(WEAK_KEY, {"name": _name(who), "key": TranslationServer.translate(String(key))})


func _on_broken(who: StringName) -> void:
	_add(BROKEN_KEY, {"name": _name(who)})


func _on_defeated(who: StringName) -> void:
	_add(DEFEATED_KEY, {"name": _name(who)})


func _on_status(who: StringName, status_id: StringName, _stacks: int) -> void:
	_add(STATUS_KEY, {"name": _name(who), "status": status_name(who, status_id)})
