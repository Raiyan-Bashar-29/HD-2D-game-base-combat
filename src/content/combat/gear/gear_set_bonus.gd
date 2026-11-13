class_name GearSetBonus
extends Resource
## A gear set (C7.4b): pieces that give more when worn together. See `docs/GEAR.md` § Sets.
##
## IN PLAIN WORDS: each piece of a set names this file in its `set_bonus`, the way it names its
## `type`. The worn pieces are counted by `set_id`, and every tier whose `pieces` the count has
## reached gives its stat changes and its kit. Taking a piece off drops the tiers no longer
## reached.
##
## OWNS: the set's id, its tiers, and checking them.
## MUST NOT: know who wears the set or count anything. `GearSetBonuses` does.

## The set's id, such as `gear_set/<name>`. Its bonuses are held under the source `set/<id>`.
@export var set_id: StringName = &""
## The steps, each reached at its own piece count.
@export var tiers: Array[GearSetTier] = []


## True when any tier lends a kit, so a body wearing the set may need a `PowerSet`.
func has_kit() -> bool:
	for tier: GearSetTier in tiers:
		if tier != null and tier.kit != null:
			return true
	return false


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s set %s" % [context, set_id]
	if set_id == &"":
		found.append("%s has a set with no set_id" % context)
	if tiers.is_empty():
		found.append("%s has no tiers" % where)
	var counts: Array[int] = []
	for tier: GearSetTier in tiers:
		if tier == null:
			found.append("%s lists an empty tier" % where)
			continue
		if tier.pieces < 1:
			found.append("%s has a tier below one piece" % where)
		elif counts.has(tier.pieces):
			found.append("%s has two tiers at %d pieces" % [where, tier.pieces])
		counts.append(tier.pieces)
		for modifier: StatModifier in tier.modifiers:
			if modifier == null or modifier.stat == &"":
				found.append("%s has an empty modifier or one with no stat" % where)
		if tier.kit != null:
			found.append_array(tier.kit.problems(where))
	return found
