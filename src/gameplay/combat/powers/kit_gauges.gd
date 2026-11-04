class_name KitGauges
extends RefCounted
## The running side of a kit's gauges (C6.4a, mechanism M6): moves each gauge pool by its
## `GaugeRule`s, and holds the status of the level each pool has reached.
##
## IN PLAIN WORDS: `PowerSet` owns one of these per equipped kit, and tells it what happened to
## its fighter: time passed (`tick_seconds` in the field, `tick_turn` in a battle), or the fighter
## landed a hit, took one, dodged or missed (`happen`). Each rule adds its points to its pool in
## the fighter's `Vitals`. Fractions wait until they make a whole point. A fallen fighter's gauges
## stand still, and a rule paused by `blocked_by_tags` does nothing.
##
## IN THE FIELD, A GAUGE POOL ALSO REGENERATES BY THE SECOND: a `regen_<pool>` stat (a status
## granting `regen_arts` +10) adds that many points a second, as a battle adds it once a turn
## (`Meters.regen_turn`, C2.16). Only the kit's gauge pools do this, so `regen_mp` is unchanged.
##
## LEVELS FOLLOW THE POOL, WHOEVER MOVED IT. `PowerSet` calls `refresh_levels` on every
## `vitals_changed` of a gauge pool, so spending a gauge on a power drops its level too.
##
## OWNS: the fractions not yet added, and which level statuses it put on.
## MUST NOT: decide what counts as a hit or a dodge. `PowerSet` reads `Events` and tells it.

## Faster than this, in metres a second across the ground, a fighter is moving.
const MOVING_SPEED: float = 0.5
## How close to a whole point the carried fraction must come to count as one.
const NEARLY: float = 0.0001

var rules: Array[GaugeRule] = []
var _owed: Dictionary[StringName, float] = {}
var _levels: Dictionary[StringName, StringName] = {}


func _init(kit_rules: Array[GaugeRule] = []) -> void:
	for rule: GaugeRule in kit_rules:
		if rule != null and rule.pool != &"":
			rules.append(rule)


## True when `pool` is one of these gauges.
func has_pool(pool: StringName) -> bool:
	return pools().has(pool)


## Each gauge pool once, in the order the rules name them.
func pools() -> Array[StringName]:
	var found: Array[StringName] = []
	for rule: GaugeRule in rules:
		if not found.has(rule.pool):
			found.append(rule.pool)
	return found


## `seconds` of fight time pass for the fighter `body`, in the field.
func tick_seconds(body: Node, seconds: float) -> void:
	if seconds <= 0.0 or _down(body):
		return
	var moving: bool = _moving(body)
	for rule: GaugeRule in rules:
		if not _blocked(body, rule):
			var rate: float = rule.per_moving_second if moving else rule.per_idle_second
			_give(body, rule.pool, (rule.per_second + rate) * seconds)
	var fighter: Combatant = Combatant.of(body)
	if fighter != null:
		for pool: StringName in pools():
			var regen: float = fighter.sheet.value(StringName(Meters.REGEN_PREFIX + String(pool)))
			if regen != 0.0:
				_give(body, pool, regen * seconds)


## One of the fighter's battle turns begins.
func tick_turn(body: Node) -> void:
	if _down(body):
		return
	for rule: GaugeRule in rules:
		if not _blocked(body, rule):
			_give(body, rule.pool, rule.per_turn)


## `event` happened to the fighter `body`.
func happen(body: Node, event: GaugeRule.Event) -> void:
	if _down(body):
		return
	for rule: GaugeRule in rules:
		if not _blocked(body, rule):
			_give(body, rule.pool, rule.amount(event))


## Holds the status of the level `pool` has reached, and drops the one it held before.
func refresh_levels(body: Node, pool: StringName) -> void:
	var vitals: Vitals = Vitals.of(body)
	var statuses: StatusSet = StatusSet.of(body)
	if vitals == null or statuses == null:
		return
	var reached: StatusEffect = null
	for rule: GaugeRule in rules:
		if rule.pool == pool and not rule.levels.is_empty():
			reached = rule.level_at(vitals.current(pool))
			break
	var was: StringName = _levels.get(pool, &"")
	var now: StringName = reached.id if reached != null else &""
	if was == now:
		return
	if was != &"":
		statuses.cure(was)
	_levels.erase(pool)
	if reached != null and statuses.apply(reached):
		_levels[pool] = now


## Takes off every level status it put on, as the kit comes off.
func clear(body: Node) -> void:
	var statuses: StatusSet = StatusSet.of(body)
	if statuses != null:
		for status_id: StringName in _levels.values():
			statuses.cure(status_id)
	_levels.clear()
	_owed.clear()


# Adds `amount` to `pool`, carrying the part that is not yet a whole point.
func _give(body: Node, pool: StringName, amount: float) -> void:
	var vitals: Vitals = Vitals.of(body)
	if vitals == null or amount == 0.0:
		return
	var owed: float = _owed.get(pool, 0.0) + amount
	# Ten tenths add up to 0.99999..., not 1, so a hair's width counts as the whole point.
	var whole: int = int(owed + signf(owed) * NEARLY)
	_owed[pool] = owed - whole
	if whole != 0:
		vitals.change(pool, whole)


func _blocked(body: Node, rule: GaugeRule) -> bool:
	if rule.blocked_by_tags.is_empty():
		return false
	var statuses: StatusSet = StatusSet.of(body)
	if statuses == null:
		return false
	for status: StatusEffect in statuses.held():
		for tag: StringName in rule.blocked_by_tags:
			if status.tags.has(tag):
				return true
	return false


func _moving(body: Node) -> bool:
	var mover: CharacterBody3D = body as CharacterBody3D
	return mover != null and Vector2(mover.velocity.x, mover.velocity.z).length() > MOVING_SPEED


func _down(body: Node) -> bool:
	var vitals: Vitals = Vitals.of(body)
	return vitals == null or vitals.is_defeated()
