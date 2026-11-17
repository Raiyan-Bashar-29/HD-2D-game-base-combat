class_name GearAffixes
extends RefCounted
## The affixes each piece of gear rolled when it dropped (C7.2b). See `docs/GEAR.md` § Affixes.
##
## IN PLAIN WORDS: when loot is given (`Rewards.give`), each unique piece of gear that has not
## rolled yet rolls `Rarity.affixes` of them (`roll`). What it rolled stays with the piece, so
## whoever wears it gets the changes, under the source `affixes` (`apply`, from `GearLending`).
## Taking the piece apart forgets them (`forget`, from `Crafting`).
##
## IT KEEPS NO LIST OF ITS OWN. Each piece is one entry in `Flags`:
##     affix/<piece item id>  ->  ["<affix id>=<value>", ...]
## So it is saved with no new save code, and a new game clears it. A piece that rolled nothing
## still gets an empty list, so it never rolls twice.
##
## OWNS: which affixes a piece holds, and their share of the wearer's sheet.
## MUST NOT: decide what drops or what is worn, or name a game's affixes.

const PREFIX: String = "affix/"
## The source every worn affix's stat change is held under on the wearer's sheet.
const SOURCE: StringName = &"affixes"


## Rolls `piece_id`'s affixes, once: only a unique piece of gear with a rarity that gives some.
## Returns how many it rolled now.
static func roll(piece_id: StringName, rng: RandomNumberGenerator = null) -> int:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	var item: ItemDefinition = ItemDb.definition(piece_id)
	if piece == null or item == null or not item.is_unique() or Flags.has_flag(_key(piece_id)):
		return 0
	var tier: Rarity = RarityDb.of(piece.rarity)
	var wanted: int = tier.affixes if tier != null else 0
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool: Array[Affix] = AffixDb.fitting(piece.slots())
	var rolled: Array[String] = []
	while rolled.size() < wanted and not pool.is_empty():
		var picked: Affix = _draw(pool, rng)
		pool.erase(picked)
		var value: float = snappedf(rng.randf_range(picked.low, picked.high), 0.01)
		rolled.append("%s=%s" % [picked.id, value])
	Flags.set_flag(_key(piece_id), rolled)
	return rolled.size()


## What `piece_id` rolled, as modifiers under `SOURCE`. Empty when it rolled nothing.
static func of(piece_id: StringName) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for entry: Variant in Flags.get_array(_key(piece_id)):
		var parts: PackedStringArray = str(entry).split("=")
		var affix: Affix = AffixDb.of(StringName(parts[0])) if parts.size() == 2 else null
		if affix != null:
			out.append(StatModifier.of(affix.stat, affix.op, parts[1].to_float(), SOURCE))
	return out


## The names of what `piece_id` rolled, as localization keys, in roll order.
static func names(piece_id: StringName) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in Flags.get_array(_key(piece_id)):
		var affix: Affix = AffixDb.of(StringName(str(entry).get_slice("=", 0)))
		if affix != null:
			out.append(affix.name_key)
	return out


## Puts every worn piece's affixes on the wearer's sheet, from scratch.
static func apply(gear: GearSet) -> void:
	var fighter: Combatant = Combatant.of(gear.get_parent())
	if fighter == null:
		return
	fighter.sheet.remove_from(SOURCE)
	for piece_id: StringName in gear.worn_ids():
		for modifier: StatModifier in of(piece_id):
			fighter.sheet.add(modifier)


## Forgets what `piece_id` rolled; the next copy that drops rolls afresh.
static func forget(piece_id: StringName) -> void:
	Flags.erase_flag(_key(piece_id))


static func _draw(pool: Array[Affix], rng: RandomNumberGenerator) -> Affix:
	var total: float = 0.0
	for affix: Affix in pool:
		total += affix.weight
	var at: float = rng.randf() * total
	for affix: Affix in pool:
		at -= affix.weight
		if at < 0.0:
			return affix
	return pool.back()


static func _key(piece_id: StringName) -> StringName:
	return StringName(PREFIX + String(piece_id))
