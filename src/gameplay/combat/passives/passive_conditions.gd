class_name PassiveConditions
extends RefCounted
## Answers a passive trigger's conditions (C9.2a): is the holder below half HP, is the target a
## dragon, is it night. See `PassiveCondition` for what each kind means.
##
## IN PLAIN WORDS: `PassiveSet` asks `all` just before a trigger wakes. Every condition must
## hold. A check about the other fighter is false when the event has none, and a check of the
## hit (its tag, its element) reads the hit landing right now (`PassiveHits.now`).
##
## OWNS: reading the fight to answer one condition.
## MUST NOT: change anything, or remember anything.


## True when every condition in `conditions` holds for the holder `me` and the event's `other`.
static func all(conditions: Array[PassiveCondition], me: Combatant, other: Combatant) -> bool:
	for condition: PassiveCondition in conditions:
		if condition != null and _holds(condition, me, other) == condition.negate:
			return false
	return true


static func _holds(condition: PassiveCondition, me: Combatant, other: Combatant) -> bool:
	var body: Node = me.get_parent()
	match condition.kind:
		PassiveCondition.Kind.POOL_SHARE:
			return _share_within(body, condition)
		PassiveCondition.Kind.HOLDS_TAG:
			return _tagged(body, condition.tag)
		PassiveCondition.Kind.TARGET_HOLDS_TAG:
			return other != null and _tagged(other.get_parent(), condition.tag)
		PassiveCondition.Kind.TARGET_TRAIT:
			return other != null and other.traits.has(condition.tag)
		PassiveCondition.Kind.WEARING:
			return GearSet.wearing(body, condition.tag)
		PassiveCondition.Kind.ALONE:
			return PassiveEffects.side(me, false).size() <= 1
		PassiveCondition.Kind.ALLIES_STANDING:
			return PassiveEffects.side(me, false).size() - 1 >= condition.count
		PassiveCondition.Kind.IN_FIELD:
			return me.real_time
		PassiveCondition.Kind.HIT_TAG:
			return PassiveHits.now != null and PassiveHits.now.tags.has(condition.tag)
		PassiveCondition.Kind.HIT_ELEMENT:
			return PassiveHits.now != null and PassiveHits.now.element == condition.tag
	var hour: float = float(Clock.hour)
	if condition.low <= condition.high:
		return hour >= condition.low and hour <= condition.high
	return hour >= condition.low or hour <= condition.high


static func _share_within(body: Node, condition: PassiveCondition) -> bool:
	var vitals: Vitals = Vitals.of(body)
	if vitals == null or vitals.maximum(condition.pool) <= 0:
		return false
	var share: float = float(vitals.current(condition.pool)) / float(vitals.maximum(condition.pool))
	return share >= condition.low and share <= condition.high


static func _tagged(body: Node, tag: StringName) -> bool:
	var statuses: StatusSet = StatusSet.of(body)
	if statuses == null:
		return false
	for status: StatusEffect in statuses.held():
		if status.tags.has(tag):
			return true
	return false
