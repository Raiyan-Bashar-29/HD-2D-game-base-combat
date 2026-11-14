class_name RecipeDb
extends RefCounted
## Every `Recipe` under `data/recipes/`, found by its id (C7.6). `GearDb`'s shape.
##
## IN PLAIN WORDS: the list of everything that can be crafted. `Crafting` asks it for the
## recipes, and for the recipe that makes a piece (so dismantling can give part of it back).
## A game with no recipes has none. A test points `content_dir` at a scratch directory and
## calls `rescan()`.
##
## OWNS: the catalogue of recipes.
## MUST NOT: know what the player knows or holds, or load anything outside `content_dir`.

const RECIPE_DIR: String = "res://data/recipes"
const ID_PREFIX: String = "recipe/"

static var content_dir: String = RECIPE_DIR
static var _by_id: Dictionary[StringName, Recipe] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## Every recipe, in id order.
static func all() -> Array[Recipe]:
	_ensure_loaded()
	var ids: Array[StringName] = _by_id.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var out: Array[Recipe] = []
	for id: StringName in ids:
		out.append(_by_id[id])
	return out


## The first recipe of `kind` (in id order) that gives `item_id` or, for a dismantling, that
## works on it. Null when there is none.
static func about(item_id: StringName, kind: Recipe.Kind) -> Recipe:
	for recipe: Recipe in all():
		if recipe.kind != kind:
			continue
		if recipe.works_on_piece() and recipe.piece == item_id:
			return recipe
		if not recipe.works_on_piece() and recipe.outputs.has(item_id):
			return recipe
	return null


## Everything wrong with the recipes for `tools/check_content.gd`: the files' own problems, a
## name that is not among the CSV's `keys`, and an item that does not exist.
static func unsound(keys: Dictionary[String, bool]) -> PackedStringArray:
	rescan()
	var found: PackedStringArray = problems().duplicate()
	for recipe: Recipe in all():
		if recipe.name_key != "" and not keys.has(recipe.name_key):
			found.append("%s name_key '%s' is not in the CSV" % [recipe.id, recipe.name_key])
		for item_id: StringName in recipe.item_ids():
			if not ItemDb.has(item_id):
				found.append("%s names the item '%s', which does not exist" % [recipe.id, item_id])
	return found


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


static func rescan() -> void:
	_by_id.clear()
	_problems = PackedStringArray()
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# No directory is no content, not an error: the stripped template has none.
	if not DirAccess.dir_exists_absolute(content_dir):
		return
	_problems = ContentScan.into(
		content_dir, ID_PREFIX, Recipe, "a Recipe", "recipe", _by_id)
