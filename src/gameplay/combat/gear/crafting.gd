class_name Crafting
extends RefCounted
## Making things from recipes, and taking pieces apart (C7.6). See `docs/GEAR.md` § Crafting.
##
## IN PLAIN WORDS:
##   - `known(station)` lists the recipes the player may see at a station: the ones whose
##     `needs_flag` is set (or that need none) and whose station is this one or anywhere.
##   - `refusal(recipe, bag, station)` says why a recipe cannot be made now, or NONE.
##   - `make(recipe, bag, rng)` pays and gives. With `rng`, a recipe's lucky outputs may come
##     out in place of the plain ones.
##   - `salvage(piece_id)` is what taking a piece apart gives: its DISMANTLE recipe's outputs,
##     else a share of the CRAFT recipe that makes it. The share is its rarity's `salvage`
##     (0 means the tier is never taken apart). `dismantle(bag, piece_id)` does it.
##
## An UPGRADE recipe hands the work to `GearUpgrades`, so the level, its cost and its gains are
## the track's. A piece used up by AWAKEN or DISMANTLE loses its recorded level. Taking the
## piece out of the bag takes it off whoever wears it (`GearSet` does that itself).
##
## IT KEEPS NOTHING. What is known is `Flags`; what is held is the bag.
##
## OWNS: the rules of making and dismantling.
## MUST NOT: draw anything, decide what is worn, or name a game's recipes.

## Why a recipe cannot be made, or a piece taken apart. NONE means it can.
enum Refusal {
	NONE,
	## The recipe's flag is not set.
	UNKNOWN,
	## The recipe belongs to another station.
	STATION,
	## The bag does not hold the inputs.
	INPUTS,
	## The bag does not hold the piece worked on.
	NO_PIECE,
	## The piece cannot go up (no track, capped, won by fights) or is below its cap (awaken).
	NOT_READY,
	## The bag cannot take what would be given.
	BAG_FULL,
	## Taking the piece apart would give nothing.
	NOTHING,
}

## The share of a piece's recipe given back when its rarity has none of its own.
const DEFAULT_SHARE: float = 0.5


## The recipes the player may see at `station`, in id order.
static func known(station: StringName = &"") -> Array[Recipe]:
	var out: Array[Recipe] = []
	for recipe: Recipe in RecipeDb.all():
		if _is_known(recipe) and (recipe.station == &"" or recipe.station == station):
			out.append(recipe)
	return out


## Why `recipe` cannot be made from `bag` at `station`, or NONE.
static func refusal(recipe: Recipe, bag: Inventory, station: StringName = &"") -> Refusal:
	if recipe == null or not _is_known(recipe):
		return Refusal.UNKNOWN
	if recipe.station != &"" and recipe.station != station:
		return Refusal.STATION
	if bag == null:
		return Refusal.INPUTS
	if recipe.kind == Recipe.Kind.UPGRADE:
		return _upgrade_refusal(bag, recipe.piece)
	if recipe.works_on_piece() and not bag.has(recipe.piece):
		return Refusal.NO_PIECE
	if recipe.kind == Recipe.Kind.AWAKEN and not _at_cap(recipe.piece):
		return Refusal.NOT_READY
	for item_id: StringName in recipe.inputs:
		if not bag.has(item_id, recipe.inputs[item_id]):
			return Refusal.INPUTS
	if not (_fits(bag, recipe.outputs) and _fits(bag, recipe.lucky_outputs)):
		return Refusal.BAG_FULL
	return Refusal.NONE


## Makes `recipe` from `bag` at `station`: pays, and gives. Returns whether it did.
static func make(recipe: Recipe, bag: Inventory, station: StringName = &"",
		rng: RandomNumberGenerator = null) -> bool:
	if refusal(recipe, bag, station) != Refusal.NONE:
		return false
	if recipe.kind == Recipe.Kind.UPGRADE:
		return GearUpgrades.upgrade(bag, recipe.piece)
	var given: Dictionary[StringName, int] = recipe.outputs
	if rng != null and recipe.lucky_chance > 0.0 and rng.randf() < recipe.lucky_chance:
		given = recipe.lucky_outputs
	for item_id: StringName in recipe.inputs:
		bag.remove(item_id, recipe.inputs[item_id])
	if recipe.works_on_piece():
		_use_up(bag, recipe.piece)
	_give(bag, given)
	return true


## What taking `piece_id` apart gives: item id -> how many. Empty when it gives nothing.
static func salvage(piece_id: StringName) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var share: float = _share(piece_id)
	if share <= 0.0:
		return out
	var own: Recipe = RecipeDb.about(piece_id, Recipe.Kind.DISMANTLE)
	if own != null:
		return own.outputs.duplicate()
	var maker: Recipe = RecipeDb.about(piece_id, Recipe.Kind.CRAFT)
	if maker == null:
		return out
	for item_id: StringName in maker.inputs:
		var back: int = floori(maker.inputs[item_id] * share / maxi(maker.outputs[piece_id], 1))
		if back > 0:
			out[item_id] = back
	return out


## Why `piece_id` cannot be taken apart from `bag`, or NONE.
static func dismantle_refusal(bag: Inventory, piece_id: StringName) -> Refusal:
	if bag == null or not bag.has(piece_id):
		return Refusal.NO_PIECE
	var given: Dictionary[StringName, int] = salvage(piece_id)
	if given.is_empty():
		return Refusal.NOTHING
	return Refusal.NONE if _fits(bag, given) else Refusal.BAG_FULL


## Takes `piece_id` apart: it leaves `bag` and its salvage goes in. Returns whether it did.
static func dismantle(bag: Inventory, piece_id: StringName) -> bool:
	if dismantle_refusal(bag, piece_id) != Refusal.NONE:
		return false
	var given: Dictionary[StringName, int] = salvage(piece_id)
	_use_up(bag, piece_id)
	_give(bag, given)
	return true


static func _is_known(recipe: Recipe) -> bool:
	return recipe.needs_flag == &"" or Flags.get_bool(recipe.needs_flag)


static func _upgrade_refusal(bag: Inventory, piece_id: StringName) -> Refusal:
	if not bag.has(piece_id):
		return Refusal.NO_PIECE
	match GearUpgrades.refusal(bag, piece_id):
		GearUpgrades.Refusal.NONE:
			return Refusal.NONE
		GearUpgrades.Refusal.COST:
			return Refusal.INPUTS
	return Refusal.NOT_READY


# A piece with no track is always ready: an AWAKEN recipe is then a plain exchange.
static func _at_cap(piece_id: StringName) -> bool:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	return piece == null or GearUpgrades.level(piece_id) >= piece.upgrade_cap()


static func _share(piece_id: StringName) -> float:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	var tier: Rarity = RarityDb.of(piece.rarity) if piece != null else null
	return tier.salvage if tier != null else DEFAULT_SHARE


static func _fits(bag: Inventory, given: Dictionary[StringName, int]) -> bool:
	for item_id: StringName in given:
		if not bag.can_accept(item_id, given[item_id]):
			return false
	return true


# The level is forgotten first, so a set woken by the bag's change no longer counts it.
static func _use_up(bag: Inventory, piece_id: StringName) -> void:
	GearUpgrades.forget(piece_id)
	bag.remove(piece_id)


static func _give(bag: Inventory, given: Dictionary[StringName, int]) -> void:
	for item_id: StringName in given:
		bag.add(item_id, given[item_id])
