class_name Rows
extends RefCounted
## Front and back rows in a turn-based battle (C8.5), the classic rule.
##
## IN PLAIN WORDS: each battle fighter stands in the front row or the back row
## (`Combatant.back_row`, set from `CombatantDef.back_row`). A CLOSE blow is softened to
## `BACK_SHARE` when the attacker stands at the back, and again when the target does, while its
## side still has someone standing at the front to hide behind. A hit tagged `ranged` or `magic`,
## or a plain attack by a fighter whose `attack_tags` hold `ranged`, is not a close blow. A
## landed hit tagged `knock_back` sends its target to the back row; one tagged `pull` brings it to
## the front. Outside a battle, where bodies have real places, nothing changes.
##
## OWNS: the row rule.
## MUST NOT: move a field body, or decide what a hit is (its tags say).

const BACK_SHARE: float = 0.5
const RANGED: StringName = &"ranged"
const MAGIC: StringName = &"magic"
const KNOCK_BACK: StringName = &"knock_back"
const PULL: StringName = &"pull"


## Softens `result`, a hit `attacker` is landing on `target`, for the rows both stand in.
static func soften(attacker: Combatant, target: Combatant, result: DamageResult) -> void:
	var battle: Battle = Battle.running
	if battle == null or result == null or result.missed or not _close(attacker, result):
		return
	if attacker.back_row and _in(battle, attacker):
		result.amount *= BACK_SHARE
	if target.back_row and _in(battle, target) and _screened(battle, target):
		result.amount *= BACK_SHARE


## Moves `target` between rows when `result` landed and carries `knock_back` or `pull`.
static func shift(target: Combatant, result: DamageResult) -> void:
	if Battle.running == null or result == null or result.missed or not _in(Battle.running, target):
		return
	var back: bool = target.back_row
	if result.tags.has(KNOCK_BACK):
		back = true
	elif result.tags.has(PULL):
		back = false
	if back != target.back_row:
		target.back_row = back
		Events.row_changed.emit(target.combatant_id, back)


# A blow that needs to reach: not ranged, not magic.
static func _close(attacker: Combatant, result: DamageResult) -> bool:
	return not result.tags.has(RANGED) and not result.tags.has(MAGIC) and not attacker.attack_tags.has(RANGED)


static func _in(battle: Battle, fighter: Combatant) -> bool:
	return battle.party.has(fighter) or battle.enemies.has(fighter)


# True while someone on `target`'s side still stands in the front row.
static func _screened(battle: Battle, target: Combatant) -> bool:
	for one: Combatant in (battle.party if battle.party.has(target) else battle.enemies):
		var vitals: Vitals = Vitals.of(one.get_parent())
		if not one.back_row and vitals != null and not vitals.is_defeated():
			return true
	return false
