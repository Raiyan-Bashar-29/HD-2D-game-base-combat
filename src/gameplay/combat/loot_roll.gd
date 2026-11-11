class_name LootRoll
extends RefCounted
## Rolls a `LootTable` into a list of item ids (C7.2).
##
## IN PLAIN WORDS: for each roll of the table, the lines that are allowed right now are put in
## a hat, each with its weight, and one is drawn. The item of that line is added, as many times
## as its count says. A line is allowed when its `needs_flag` is empty or true. A piece of
## gear's weight is multiplied by its rarity's `drop_weight`, so a rarer tier turns up less
## often with no change to the table, and a tier with weight 0 is never drawn.
##
## THE SAME SEED GIVES THE SAME LOOT: every draw uses the `rng` handed in, which is the
## battle's own, or the field enemy's.
##
## OWNS: the drawing rule.
## MUST NOT: put anything in a bag. `Rewards.give` does that with the list this returns.

## The items one table gives this time, one id per item. A null table gives nothing.
static func roll(table: LootTable, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	if table == null or rng == null:
		return out
	for _i: int in table.rolls:
		var picked: LootEntry = _pick(table, rng)
		if picked == null or picked.item_id == &"":
			continue
		for _n: int in rng.randi_range(picked.min_count, picked.max_count):
			out.append(picked.item_id)
	return out


## Every table's items, in order. Null tables are skipped.
static func all(tables: Array[LootTable], rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	for table: LootTable in tables:
		out.append_array(roll(table, rng))
	return out


## The share a line has right now: 0 when its flag is not set, else its weight, times its
## rarity's drop weight when the item is gear with a rarity.
static func weight_of(entry: LootEntry) -> float:
	if entry == null or entry.weight <= 0.0:
		return 0.0
	if entry.needs_flag != &"" and not Flags.get_bool(entry.needs_flag):
		return 0.0
	var piece: GearDefinition = GearDb.for_item(entry.item_id)
	var tier: Rarity = RarityDb.of(piece.rarity) if piece != null else null
	return entry.weight * (tier.drop_weight if tier != null else 1.0)


static func _pick(table: LootTable, rng: RandomNumberGenerator) -> LootEntry:
	var total: float = 0.0
	for entry: LootEntry in table.entries:
		total += weight_of(entry)
	if total <= 0.0:
		return null
	var point: float = rng.randf() * total
	var last: LootEntry = null
	for entry: LootEntry in table.entries:
		var share: float = weight_of(entry)
		if share <= 0.0:
			continue
		last = entry
		point -= share
		if point < 0.0:
			return entry
	return last
