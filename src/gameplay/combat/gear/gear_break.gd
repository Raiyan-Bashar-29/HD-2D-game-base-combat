class_name GearBreak
extends RefCounted
## Breaks the worn piece that gave a passive (C9.5b). See `docs/PASSIVES.md` § As built (C9.5b).
##
## IN PLAIN WORDS: a passive effect of the kind BREAK_PIECE costs the armour that carries it: a
## plate that shatters to save its wearer once, a trump card that burns the weapon out. This
## file finds which source gave the effect. When that source is a worn piece (`gear/<item id>`),
## the piece comes off, cursed or not, and is gone for good: out of the bag, and out of a foe's
## starting gear. Taking it off also takes back its stats, its kit and its passives, as any
## piece taken off does. A passive the character owns, or one from a kit, a set, a gem or an
## upgrade level, has no single piece to break, so nothing happens.
##
## OWNS: finding the piece behind an effect, and removing it.
## MUST NOT: decide when a piece breaks. The passive's trigger does.

const CATEGORY: String = "gear"


## Breaks the piece of the fighter under `body` whose passive holds `effect`. Returns the
## broken piece's item id, or empty when no worn piece gave it.
static func giver(body: Node, effect: PassiveEffect) -> StringName:
	var passives: PassiveSet = PassiveSet.of(body)
	var gear: GearSet = GearSet.of(body)
	if passives == null or gear == null:
		return &""
	for source: StringName in passives.sources():
		var text: String = String(source)
		if not text.begins_with(PassiveLending.GEAR_PREFIX) or not _gives(passives.given_by(source), effect):
			continue
		var item_id: StringName = StringName(text.trim_prefix(PassiveLending.GEAR_PREFIX))
		gear.innate.erase(item_id)
		gear.take_off(item_id, true)
		var bag: Inventory = Inventory.of(body)
		if bag != null:
			bag.remove(item_id)
		Log.info(CATEGORY, "'%s' broke" % item_id)
		return item_id
	return &""


static func _gives(given: Array, effect: PassiveEffect) -> bool:
	for passive: PassiveSkill in given:
		for trigger: PassiveTrigger in passive.triggers:
			if trigger != null and trigger.effects.has(effect):
				return true
	return false
