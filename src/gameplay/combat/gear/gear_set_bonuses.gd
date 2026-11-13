class_name GearSetBonuses
extends RefCounted
## Gives a fighter the bonuses of the gear sets it is wearing (C7.4b). See `docs/GEAR.md` § Sets.
##
## IN PLAIN WORDS: after every change to what is worn, `GearLending` calls `apply`. It counts the
## worn pieces of each set (by `set_id`), and for every tier the count reaches:
##   - puts the tier's stat changes on the wearer's sheet, under the source `set/<set id>`;
##   - adds the tier's kit to the kits the wearer borrows, under `set/<set id>/<pieces>`.
## It keeps nothing between calls. It first takes every set's stat changes off, so a refresh or
## a load cannot give a bonus twice.
##
## OWNS: counting set pieces and turning the reached tiers into stat changes and kits.
## MUST NOT: decide what is worn, or hand kits to the `PowerSet`. `GearLending` does that.

const SOURCE_PREFIX: String = "set/"


## Puts `gear`'s reached set bonuses on its wearer's sheet and into `kits`.
static func apply(gear: GearSet, kits: Dictionary[StringName, PowerKit]) -> void:
	var fighter: Combatant = Combatant.of(gear.get_parent())
	if fighter == null:
		return
	for set_id: StringName in GearDb.set_ids():
		fighter.sheet.remove_from(StringName(SOURCE_PREFIX + String(set_id)))
	var tiers: Dictionary[StringName, GearSetTier] = reached(gear)
	for key: StringName in tiers:
		for modifier: StatModifier in tiers[key].modifiers:
			if modifier != null:
				fighter.sheet.add(StatModifier.of(
					modifier.stat, modifier.op, modifier.value, StringName(String(key).get_base_dir())))
		if tiers[key].kit != null:
			kits[key] = tiers[key].kit


## The set tiers `gear` has reached, each under `set/<set id>/<pieces>`.
static func reached(gear: GearSet) -> Dictionary[StringName, GearSetTier]:
	var out: Dictionary[StringName, GearSetTier] = {}
	var counts: Dictionary[StringName, int] = {}
	var bonuses: Dictionary[StringName, GearSetBonus] = {}
	for item_id: StringName in gear.worn_ids():
		var piece: GearDefinition = GearDb.for_item(item_id)
		if piece == null or piece.set_bonus == null:
			continue
		var set_id: StringName = piece.set_bonus.set_id
		if not bonuses.has(set_id):
			bonuses[set_id] = piece.set_bonus
		counts[set_id] = counts.get(set_id, 0) + 1
	for set_id: StringName in bonuses:
		for tier: GearSetTier in bonuses[set_id].tiers:
			if tier != null and tier.pieces <= counts[set_id]:
				out[StringName("%s%s/%d" % [SOURCE_PREFIX, set_id, tier.pieces])] = tier
	return out
