class_name CraftScreen
extends MenuScreen
## The craft screen (C7.8): make things from recipes, and take pieces apart. See
## `docs/GEAR.md` § Crafting.
##
## IN PLAIN WORDS:
##   - MAKE: each recipe known at this station (`Crafting.known`), with what it needs. Press one
##     to make it. One that cannot be made now is greyed out with the reason.
##   - TAKE APART: each piece in the bag that gives something back, with what it gives.
## A short note says what was made or taken apart.
##
## OWNS: the rows and what pressing one does.
## MUST NOT: decide what can be made or what it costs (`Crafting` does).

const SCREEN_ID: StringName = &"craft"
const TITLE_KEY: String = "combat.craft.title"
const HINT_KEY: String = "combat.craft.hint"
const MAKE_KEY: String = "combat.craft.make"
const NONE_KNOWN_KEY: String = "combat.craft.none_known"
const RECIPE_KEY: String = "combat.craft.recipe"
const APART_KEY: String = "combat.craft.apart"
const PIECE_KEY: String = "combat.craft.piece"
const COUNT_KEY: String = "combat.craft.count"
const MADE_KEY: String = "combat.craft.made"
const TAKEN_APART_KEY: String = "combat.craft.taken_apart"
const REFUSED_KEY: String = "combat.loadout.row_refused"
const REFUSAL_PREFIX: String = "combat.craft.refusal."

## The station's id; empty is "anywhere".
var station: StringName = &""
## The bag crafted from.
var bag: Inventory
## What the last press did, shown at the top; empty for nothing yet.
var last: String = ""
## Seeded randomly. A test seeds it to make a lucky roll repeatable.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## A screen for `at` over `used`.
static func for_station(at: StringName, used: Inventory) -> CraftScreen:
	var screen := CraftScreen.new()
	screen.station = at
	screen.bag = used
	return screen


## "2 x Iron, 1 x Gem": the items and counts in `counts`, by id.
static func listed(counts: Dictionary[StringName, int]) -> String:
	var ids: Array[StringName] = counts.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in ids:
		parts.append(TranslationServer.translate(COUNT_KEY).format(
			{"count": counts[item_id], "item": _item_name(item_id)}))
	return ", ".join(parts)


## The key that says why a recipe cannot be made.
static func refusal_key(why: Crafting.Refusal) -> String:
	return REFUSAL_PREFIX + str(Crafting.Refusal.find_key(why)).to_lower()


func _fill() -> void:
	if bag == null or not is_instance_valid(bag):
		return
	if last != "":
		add_note(last)
	add_note(tr(MAKE_KEY))
	var recipes: Array[Recipe] = Crafting.known(station)
	if recipes.is_empty():
		add_note(tr(NONE_KNOWN_KEY))
	for recipe: Recipe in recipes:
		var row: Button = add_row(tr(RECIPE_KEY).format({"name": tr(recipe.name_key),
			"needs": listed(_needs(recipe))}), _on_make.bind(recipe))
		_refuse(row, Crafting.refusal(recipe, bag, station))
	_fill_apart()


func _fill_apart() -> void:
	var lines: Array[StringName] = []
	for item_id: StringName in bag.ids():
		if GearDb.for_item(item_id) != null and not Crafting.salvage(item_id).is_empty():
			lines.append(item_id)
	if lines.is_empty():
		return
	add_note(tr(APART_KEY))
	for item_id: StringName in lines:
		var row: Button = add_row(tr(PIECE_KEY).format({"item": _item_name(item_id),
			"gives": listed(Crafting.salvage(item_id))}), _on_apart.bind(item_id))
		_refuse(row, Crafting.dismantle_refusal(bag, item_id))


# What a recipe takes from the bag: its inputs and, for one worked on a piece, the piece.
func _needs(recipe: Recipe) -> Dictionary[StringName, int]:
	var needs: Dictionary[StringName, int] = recipe.inputs.duplicate()
	if recipe.works_on_piece():
		needs[recipe.piece] = needs.get(recipe.piece, 0) + 1
	return needs


func _refuse(row: Button, why: Crafting.Refusal) -> void:
	if why != Crafting.Refusal.NONE:
		row.disabled = true
		row.text = tr(REFUSED_KEY).format({"label": row.text, "reason": tr(refusal_key(why))})


static func _item_name(item_id: StringName) -> String:
	var item: ItemDefinition = ItemDb.definition(item_id)
	return TranslationServer.translate(item.name_key) if item != null else String(item_id)


func _on_make(recipe: Recipe) -> void:
	if Crafting.make(recipe, bag, station, rng):
		last = tr(MADE_KEY).format({"name": tr(recipe.name_key)})
		refresh()


func _on_apart(item_id: StringName) -> void:
	if Crafting.dismantle(bag, item_id):
		last = tr(TAKEN_APART_KEY).format({"item": _item_name(item_id)})
		refresh()
