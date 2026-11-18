class_name Pilfer
extends RefCounted
## Stealing from a fighter and capturing one (C8.7b), for the STEAL and CAPTURE skill effects.
##
## IN PLAIN WORDS: `steal` rolls a chance; on success the user gets one roll of the target's
## `steal_table`, and the target is marked so nobody steals from it again this fight.
## `capture` rolls a chance that grows as the target loses hp; on success the target leaves the
## fight (it falls), its `capture_item` goes to the user, and a count of that kind goes up in
## `Flags` (`captured/<kind>`), so a game can keep a bestiary or a ranch.
##
## WHERE THE ITEMS GO: into the bag on the user's body (the player in the field). A fighter
## with no bag (a party member in a battle) keeps them in `Combatant.spoils`, and the battle's
## `Rewards` hand them over when the fight is won.
##
## OWNS: the steal and capture rolls, the robbed mark and the captured count.
## MUST NOT: choose targets, or decide what a captured creature is for.

const CAPTURED_PREFIX: String = "captured/"
const ROBBED_META: StringName = &"pilfer_robbed"


## True when one roll of `target`'s steal table went to `user`.
static func steal(user: Combatant, target: Combatant, chance: float, rng: RandomNumberGenerator) -> bool:
	if target.steal_table == null or target.has_meta(ROBBED_META) or _down(target):
		return false
	if rng.randf() >= chance:
		return false
	target.set_meta(ROBBED_META, true)
	for item_id: StringName in LootRoll.roll(target.steal_table, rng):
		_give(user, item_id)
		Events.item_stolen.emit(user.combatant_id, target.combatant_id, item_id)
	return true


## True when `target` was captured: it falls, and its capture item goes to `user`.
static func capture(user: Combatant, target: Combatant, chance: float, rng: RandomNumberGenerator) -> bool:
	if target.capture_item == &"" or _down(target):
		return false
	var vitals: Vitals = Vitals.of(target.get_parent())
	var lost: float = 1.0 - float(vitals.current(vitals.defeat_pool)) / float(vitals.maximum(vitals.defeat_pool))
	if rng.randf() >= chance * lost:
		return false
	_give(user, target.capture_item)
	Events.creature_captured.emit(user.combatant_id, target.combatant_id, target.capture_item)
	Flags.advance(captured_flag(target))
	vitals.set_to(vitals.defeat_pool, 0)
	return true


## The flag that counts how many of `fighter`'s kind have been captured.
static func captured_flag(fighter: Combatant) -> StringName:
	var kind: StringName = fighter.kind if fighter.kind != &"" else fighter.combatant_id
	return StringName(CAPTURED_PREFIX + String(kind))


static func _give(user: Combatant, item_id: StringName) -> void:
	var bag: Inventory = Inventory.of(user.get_parent())
	if bag == null or not bag.add(item_id, 1):
		user.spoils.append(item_id)


static func _down(fighter: Combatant) -> bool:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	return vitals == null or vitals.is_defeated()
