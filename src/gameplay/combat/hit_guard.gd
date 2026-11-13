class_name HitGuard
extends RefCounted
## The defences that need no power (C9.5a): invincibility, mercy time and the overshield.
##
## IN PLAIN WORDS: `Combatant` asks here three times while one hit lands, and once as time passes.
## 1. `stops`: a hit does nothing to a fighter that holds a status marked `invincible`, or that
##    was hurt a moment ago and has the stat `mercy_time` (seconds in the field, the fighter's own
##    turns in a battle). The hit is announced as blocked. A hit carrying one of the status's
##    `pierced_by` tags goes through that status. A heal is never stopped.
## 2. `soak`: a fighter with the stat `max_overshield` has a pool `overshield`, a second health
##    layer. A hit empties it first, and only what is left over reaches the damage pool.
## 3. `hurt`: a hit that took something starts the mercy time and makes the overshield wait.
## 4. `pass_time`: the mercy time counts down, and the overshield refills by `overshield_regen`
##    points each second (or turn) once `overshield_delay` has passed with no hit.
## Every number is a stat, so a passive, a status, a worn piece or a form can give any of them.
##
## A DODGE'S I-FRAMES AND A BARRIER ARE NOT HERE. The first is a move's (`ActionMove`, C3.2), the
## second a power's (`BarrierMechanism`, C6.6).
##
## OWNS: what the four stats and the `invincible` mark of a status mean.
## MUST NOT: decide when a hit lands or when time passes. `Combatant`, `Battle` and the field
## fighters call in.

const POOL: StringName = &"overshield"
const REGEN: StringName = &"overshield_regen"
const DELAY: StringName = &"overshield_delay"
const MERCY: StringName = &"mercy_time"


## True when `result` cannot touch `target` now.
static func stops(target: Combatant, result: DamageResult) -> bool:
	if result.total() <= 0:
		return false
	if target.mercy_left > 0.0:
		return true
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	if statuses == null:
		return false
	for effect: StatusEffect in statuses.held():
		if effect.invincible and not _pierces(result, effect):
			return true
	return false


## Takes what the overshield can hold out of `result`, and returns how much that was.
static func soak(vitals: Vitals, result: DamageResult) -> int:
	var soaked: int = mini(vitals.current(POOL), result.total())
	if soaked <= 0:
		return 0
	vitals.change(POOL, -soaked)
	result.amount -= soaked
	return soaked


## A hit just took `lost` points from `target`, its overshield's share counted.
static func hurt(target: Combatant, lost: int) -> void:
	if lost <= 0:
		return
	target.mercy_left = maxf(0.0, target.sheet.value(MERCY))
	target.shield_wait = maxf(0.0, target.sheet.value(DELAY))


## `step` seconds pass for `fighter` in the field, or 1 for one of its turns in a battle.
static func pass_time(fighter: Combatant, step: float) -> void:
	fighter.mercy_left = maxf(0.0, fighter.mercy_left - step)
	var rate: float = fighter.sheet.value(REGEN)
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	if rate <= 0.0 or vitals == null or vitals.is_defeated():
		return
	if fighter.shield_wait > 0.0:
		fighter.shield_wait = maxf(0.0, fighter.shield_wait - step)
		return
	fighter.shield_carry += rate * step
	var whole: int = floori(fighter.shield_carry)
	if whole > 0:
		fighter.shield_carry -= whole
		vitals.change(POOL, whole)


static func _pierces(result: DamageResult, effect: StatusEffect) -> bool:
	for tag: StringName in effect.pierced_by:
		if result.tags.has(tag):
			return true
	return false
