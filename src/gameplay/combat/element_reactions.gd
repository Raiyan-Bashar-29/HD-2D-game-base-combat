class_name ElementReactions
extends RefCounted
## Elemental marks and reactions on a landing hit (C8.4), in a battle and in the field alike.
##
## IN PLAIN WORDS: `Combatant` calls `land` for each hit that is about to hurt. When the hit's
## element pairs, in some `ElementReaction`, with a mark the target holds, it reacts: the hit
## grows by the reaction's `damage_bonus`, its `status` goes on the target, the mark is used up
## (unless `keeps_mark`), and `Events.elements_reacted` says so. Otherwise, when any reaction names
## the hit's element, the target is marked with it: `MARK_TURNS` of its own turns in a battle,
## `MARK_SECONDS` in real time. An element no reaction names leaves no mark.
##
## OWNS: the marks and when a reaction fires.
## MUST NOT: decide which elements react (the data does), or apply the hit itself.

const MARK_PREFIX: String = "status/element/"
const MARK_RT_PREFIX: String = "status/element_rt/"
const MARK_TAG: StringName = &"element_mark"
const MARK_TURNS: float = 2.0
const MARK_SECONDS: float = 6.0

static var _marks: Dictionary[StringName, StatusEffect] = {}


## `result` is about to land on `target`: react with a mark it holds, or leave a mark. Returns
## the reaction that fired, or null.
static func land(target: Combatant, result: DamageResult) -> ElementReaction:
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	if statuses == null or result.element == &"" or result.amount <= 0.0:
		return null
	var reactions: Array[ElementReaction] = ReactionDb.naming(result.element)
	for reaction: ElementReaction in reactions:
		var held: StatusEffect = mark(reaction.other(result.element), target.real_time)
		if statuses.stacks(held.id) == 0:
			continue
		result.amount *= 1.0 + reaction.damage_bonus
		if not reaction.keeps_mark:
			statuses.cure(held.id)
		if reaction.status != null:
			statuses.apply(reaction.status)
		Events.elements_reacted.emit(target.combatant_id, reaction.id)
		return reaction
	if not reactions.is_empty():
		statuses.apply(mark(result.element, target.real_time))
	return null


## The mark `element` leaves: counted in turns, or in seconds for a real-time fighter.
static func mark(element: StringName, real_time: bool) -> StatusEffect:
	var id := StringName((MARK_RT_PREFIX if real_time else MARK_PREFIX) + String(element))
	if not _marks.has(id):
		var made := StatusEffect.new()
		made.id = id
		made.unit = StatusEffect.Unit.SECONDS if real_time else StatusEffect.Unit.TURNS
		made.duration = MARK_SECONDS if real_time else MARK_TURNS
		made.tags = [MARK_TAG, element]
		_marks[id] = made
	return _marks[id]


## The mark whose id is `status_id`, else null. A save that holds one finds it here.
static func built_in(status_id: StringName) -> StatusEffect:
	var text: String = String(status_id)
	if text.begins_with(MARK_RT_PREFIX):
		return mark(StringName(text.trim_prefix(MARK_RT_PREFIX)), true)
	if text.begins_with(MARK_PREFIX):
		return mark(StringName(text.trim_prefix(MARK_PREFIX)), false)
	return null
