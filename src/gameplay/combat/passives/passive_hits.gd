class_name PassiveHits
extends RefCounted
## The passives' place in the path of one hit (C9.2b). See `docs/PASSIVES.md` § The passive
## (the order inside one hit).
##
## IN PLAIN WORDS: `Combatant.receive` shows each hit here twice before any HP changes.
## 1. `scale`, before the barriers: the attacker's early HIT_DEALT (and CRIT_DEALT) triggers,
##    then the target's early HIT_TAKEN triggers, may multiply the hit (`SCALE_HIT`).
## 2. `lethal`, after the barriers: when the hit would take the target to 0 HP, its LETHAL_HIT
##    triggers wake, and a `SURVIVE` effect may cut the hit.
## While a hit is landing it is kept in `now`, so a condition can ask about its tag or element
## and an effect can change it. A hit inside a hit (a counter, an extra hit) puts the outer one
## back when it is done.
##
## A heal (an absorbed element) and a hit on oneself are not scaled and are never lethal.
##
## OWNS: the hit landing right now, and the order the early triggers are asked in.
## MUST NOT: change a hit itself. The effects do (`PassiveEffects`).

## The hit landing right now, or null. `Combatant.receive` sets it and puts the old one back.
static var now: DamageResult


## `result`, thrown by `from`, is about to land on `target`, before any barrier sees it.
static func scale(target: Combatant, result: DamageResult, from: StringName) -> void:
	if result.total() <= 0 or from == target.combatant_id:
		return
	var attacker: Combatant = PassiveEffects.find(target, from)
	var theirs: PassiveSet = PassiveSet.of(attacker.get_parent()) if attacker != null else null
	if theirs != null:
		theirs.before(PassiveTrigger.Event.HIT_DEALT, target, result.total())
		if result.critical:
			theirs.before(PassiveTrigger.Event.CRIT_DEALT, target, result.total())
	var mine: PassiveSet = PassiveSet.of(target.get_parent())
	if mine != null:
		mine.before(PassiveTrigger.Event.HIT_TAKEN, attacker, result.total())


## `result` got past the barriers. If it would fell `target`, its LETHAL_HIT triggers wake.
static func lethal(target: Combatant, result: DamageResult, from: StringName) -> void:
	var vitals: Vitals = Vitals.of(target.get_parent())
	var mine: PassiveSet = PassiveSet.of(target.get_parent())
	if vitals == null or mine == null or from == target.combatant_id:
		return
	if result.total() <= 0 or result.total() < vitals.current(target.damage_pool):
		return
	mine.before(PassiveTrigger.Event.LETHAL_HIT, PassiveEffects.find(target, from), result.total())
