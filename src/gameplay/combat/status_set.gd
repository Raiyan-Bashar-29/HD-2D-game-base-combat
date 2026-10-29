class_name StatusSet
extends Node
## The statuses one combatant holds, how long each has left, and their stacks.
##
## IT DOES NOT TICK ITSELF. A turn-based battle calls `tick_turn()` at a turn's end and an action
## one calls `tick_seconds(delta)` from its own clock, so a pause, a slowed menu or a stopped
## battle all stop statuses with no code here. A status answers only to its own unit.
##
## A STATUS'S MODIFIERS GO ON A SHEET UNDER THE STATUS'S ID, and leave by it (C1.2), on expiry,
## on cure, on a new game and before a load. The sheet is `sheet` when set; otherwise the
## sibling `Vitals`' own, until C1.6's `Combatant` hands both the same one.
##
## ITS OWN SAVE SECTION, `Inventory`'s pattern: registered on ready, unregistered on exit, so
## `save_system.gd` is untouched. It stores ids, time left and stacks, and rebuilds the modifiers
## from `StatusDb` on load, so a sheet is never saved. A status whose definition has gone is
## dropped with a warning: without its definition nothing knows what it changed.
##
## OWNS: which statuses are held, their time left, stacks and tick timing, and its save section.
## MUST NOT: decide when a turn or a second passes, or what a status means beyond its data.

const CATEGORY: String = "status"
const SAVE_VERSION: int = 1


class Held:
	extends RefCounted
	var effect: StatusEffect
	var remaining: float = 0.0
	var stacks: int = 1
	## Seconds gathered toward the next tick of a SECONDS status.
	var carry: float = 0.0


## Unique per combatant: it is the `who` in every signal. Vitals' rule.
@export var owner_id: StringName = &"player"
## Unique per combatant, Inventory's rule: two sets sharing it means one never saves.
@export var save_id: StringName = &"statuses/player"

## Where modifiers go. Null means the sibling `Vitals`' sheet.
var sheet: StatSheet

var _held: Dictionary[StringName, Held] = {}


func _ready() -> void:
	SaveSystem.register(save_id, _collect_save, _apply_save, SAVE_VERSION)
	Events.game_started.connect(_on_game_started)


func _exit_tree() -> void:
	SaveSystem.unregister(save_id)
	if Events.game_started.is_connected(_on_game_started):
		Events.game_started.disconnect(_on_game_started)


static func of(who: Node) -> StatusSet:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: StatusSet = child as StatusSet
		if found != null:
			return found
	return null


## Applies a status, by its stacking rule. False when refused: a broken status, or IGNORE held.
func apply(effect: StatusEffect) -> bool:
	if effect == null or not effect.problems().is_empty():
		return false
	if not _held.has(effect.id):
		var held := Held.new()
		held.effect = effect
		held.remaining = effect.duration
		_held[effect.id] = held
		_add_modifiers(effect)
	else:
		var held: Held = _held[effect.id]
		match effect.stacking:
			StatusEffect.Stacking.IGNORE:
				return false
			StatusEffect.Stacking.REFRESH:
				held.remaining = effect.duration
			StatusEffect.Stacking.STACK:
				held.remaining = effect.duration
				if held.stacks < effect.max_stacks:
					held.stacks += 1
					_add_modifiers(effect)
	Events.status_applied.emit(owner_id, effect.id, stacks(effect.id))
	return true


## Zero when not held.
func stacks(status_id: StringName) -> int:
	return _held[status_id].stacks if _held.has(status_id) else 0


func remaining(status_id: StringName) -> float:
	return _held[status_id].remaining if _held.has(status_id) else 0.0


## Ends a status early. False when it was not held.
func cure(status_id: StringName) -> bool:
	if not _held.has(status_id):
		return false
	_expire(status_id)
	return true


## One turn passes for every TURNS status: each ticks, then loses a turn.
func tick_turn() -> void:
	for status_id: StringName in _ids():
		var held: Held = _held[status_id]
		if held.effect.unit != StatusEffect.Unit.TURNS:
			continue
		_tick(held)
		if held.effect.duration > 0.0:
			held.remaining -= 1.0
			if held.remaining <= 0.0:
				_expire(status_id)


## `delta` seconds pass for every SECONDS status. Never ticks past its own expiry.
func tick_seconds(delta: float) -> void:
	for status_id: StringName in _ids():
		var held: Held = _held[status_id]
		if held.effect.unit != StatusEffect.Unit.SECONDS:
			continue
		var lasting: bool = held.effect.duration > 0.0
		var step: float = minf(delta, held.remaining) if lasting else delta
		var interval: float = held.effect.tick_interval
		if interval > 0.0:
			held.carry += step
			while held.carry >= interval:
				held.carry -= interval
				_tick(held)
		if lasting:
			held.remaining -= step
			if held.remaining <= 0.0:
				_expire(status_id)


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_held.keys())
	return out


func _tick(held: Held) -> void:
	if held.effect.tick_change == 0 or held.effect.tick_pool == &"":
		return
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals != null:
		vitals.change(held.effect.tick_pool, held.effect.tick_change * held.stacks)


func _sheet() -> StatSheet:
	if sheet != null:
		return sheet
	var vitals: Vitals = Vitals.of(get_parent())
	return vitals.sheet if vitals != null else null


func _add_modifiers(effect: StatusEffect) -> void:
	var target: StatSheet = _sheet()
	if target == null:
		return
	for modifier: StatModifier in effect.modifiers:
		target.add(StatModifier.of(modifier.stat, modifier.op, modifier.value, effect.id))


func _expire(status_id: StringName) -> void:
	var target: StatSheet = _sheet()
	if target != null:
		target.remove_from(status_id)
	_held.erase(status_id)
	Events.status_expired.emit(owner_id, status_id)


## Quietly: a new game or a load is not every status wearing off.
func _clear() -> void:
	var target: StatSheet = _sheet()
	for status_id: StringName in _ids():
		if target != null:
			target.remove_from(status_id)
	_held.clear()


func _on_game_started() -> void:
	_clear()


func _collect_save() -> Dictionary:
	var out: Dictionary = {}
	for status_id: StringName in _held:
		var held: Held = _held[status_id]
		out[String(status_id)] = {"remaining": held.remaining, "stacks": held.stacks, "carry": held.carry}
	return out


func _apply_save(data: Dictionary, _from_version: int) -> void:
	_clear()
	for key: String in data:
		var effect: StatusEffect = StatusDb.status(StringName(key))
		if effect == null:
			Log.warn(CATEGORY, "'%s' held a status '%s' that no longer exists; dropped" % [owner_id, key])
			continue
		var row: Dictionary = DictRead.get_dict(data, key)
		var held := Held.new()
		held.effect = effect
		held.remaining = DictRead.get_float(row, "remaining", effect.duration)
		held.stacks = clampi(DictRead.get_int(row, "stacks", 1), 1, effect.max_stacks)
		held.carry = DictRead.get_float(row, "carry", 0.0)
		_held[effect.id] = held
		for i: int in held.stacks:
			_add_modifiers(effect)
