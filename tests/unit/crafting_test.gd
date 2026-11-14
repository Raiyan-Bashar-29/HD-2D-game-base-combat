extends TestCase
## Crafting (C7.6): recipes are found by station and by a flag; a recipe pays its inputs and
## gives its outputs; an upgrade recipe raises the piece on its own track; an awakening needs
## the piece at its cap; a piece taken apart gives its dismantle recipe, else a share of the
## recipe that makes it, by rarity.
##
## OWNS: assertions about `Recipe`, `RecipeDb`, `Crafting`, `Rarity.salvage` and
## `GearUpgrades.forget`.
## MUST NOT: name a game's gear, items or recipes, or wait for frames. The files are written to
## this run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.WORN_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEMSTONE: StringName = FixtureContent.STACK_ITEM
const CROWN: StringName = FixtureContent.UNIQUE_ITEM
const SCRAP: StringName = FixtureContent.HELD_ITEM
const TIER: StringName = &"rarity/fixture_whole"
const FORGE: StringName = &"fixture_forge"
const BLUEPRINT: StringName = &"fixture/blueprint"

var _directory: String


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_content()
	var body: Node = _body()
	_making(Inventory.of(body))
	_dismantling(body, Inventory.of(body))
	GearDb.content_dir = GearDb.GEAR_DIR
	RarityDb.content_dir = RarityDb.RARITY_DIR
	RecipeDb.content_dir = RecipeDb.RECIPE_DIR
	GearDb.rescan()
	RarityDb.rescan()
	RecipeDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var listed: Recipe = Recipe.new()
	listed.name_key = "ui.cancel"
	listed.kind = Recipe.Kind.UPGRADE
	listed.piece = PIECE
	listed.inputs = {ORE: 1}
	var lucky: Recipe = _recipe("x", Recipe.Kind.CRAFT, {ORE: 1}, {PIECE: 1})
	lucky.lucky_chance = 0.5
	equal("the scratch recipes are sound; an empty recipe, an upgrade listing items and a lucky "
			+ "chance with nothing to give are each flagged",
		[RecipeDb.problems().size(), RecipeDb.all().size(), Recipe.new().problems().size(),
		listed.problems().size(), lucky.problems().size()], [0, 5, 3, 1, 1])
	equal("a station shows its own recipes and the ones for anywhere; a flagged one waits",
		[Crafting.known().size(), Crafting.known(FORGE).size()], [3, 4])
	Flags.set_flag(BLUEPRINT, true)
	equal("once its flag is set, the recipe is known", Crafting.known(FORGE).size(), 5)
	Flags.erase_flag(BLUEPRINT)


func _making(bag: Inventory) -> void:
	var coat: Recipe = RecipeDb.about(PIECE, Recipe.Kind.CRAFT)
	var crown: Recipe = RecipeDb.about(PIECE, Recipe.Kind.AWAKEN)
	var raise: Recipe = RecipeDb.about(PIECE, Recipe.Kind.UPGRADE)
	var secret: Recipe = RecipeDb.about(GEMSTONE, Recipe.Kind.TRANSMUTE)
	equal("an unknown recipe, the wrong station, an empty bag and a missing piece are refused",
		[Crafting.refusal(secret, bag), Crafting.refusal(coat, bag), Crafting.refusal(coat, bag, FORGE),
		Crafting.refusal(crown, bag), Crafting.refusal(raise, bag)],
		[Crafting.Refusal.UNKNOWN, Crafting.Refusal.STATION, Crafting.Refusal.INPUTS,
		Crafting.Refusal.NO_PIECE, Crafting.Refusal.NO_PIECE])
	bag.add(ORE, 10)
	equal("a craft pays its inputs and gives its output; a second copy does not fit the bag",
		[Crafting.make(coat, bag, FORGE), bag.count_of(PIECE), bag.count_of(ORE),
		Crafting.refusal(coat, bag, FORGE)], [true, 1, 6, Crafting.Refusal.BAG_FULL])
	equal("below its cap a piece cannot be awakened by a recipe",
		[Crafting.refusal(crown, bag), Crafting.make(crown, bag)], [Crafting.Refusal.NOT_READY, false])
	equal("an upgrade recipe raises the piece at its track's cost, and stops at the cap",
		[Crafting.make(raise, bag), GearUpgrades.level(PIECE), bag.count_of(ORE),
		Crafting.refusal(raise, bag)], [true, 1, 5, Crafting.Refusal.NOT_READY])
	equal("at the cap the awakening uses the piece up, gives the new one and forgets the level",
		[Crafting.make(crown, bag), bag.count_of(PIECE), bag.count_of(CROWN), bag.count_of(ORE),
		GearUpgrades.level(PIECE)], [true, 0, 1, 4, 0])
	Flags.set_flag(BLUEPRINT, true)
	var rng := RandomNumberGenerator.new()
	var counts: Array[int] = []
	Crafting.make(secret, bag, &"", rng)
	counts.append(bag.count_of(GEMSTONE))
	Crafting.make(secret, bag)
	counts.append(bag.count_of(GEMSTONE))
	equal("with dice a sure lucky chance gives the lucky outputs; with none, the plain ones",
		counts + [bag.count_of(ORE)], [2, 3, 0])


func _dismantling(body: Node, bag: Inventory) -> void:
	equal("taking apart gives the dismantle recipe, else half the recipe that makes the piece; "
			+ "an item with neither gives nothing",
		[Crafting.salvage(SCRAP), Crafting.salvage(PIECE), Crafting.salvage(GEMSTONE)],
		[{ORE: 3}, {ORE: 2}, {}])
	bag.add(SCRAP)
	equal("a held item is taken apart; one not held, or one that gives nothing, is refused",
		[Crafting.dismantle(bag, SCRAP), bag.count_of(SCRAP), bag.count_of(ORE),
		Crafting.dismantle_refusal(bag, SCRAP), Crafting.dismantle_refusal(bag, CROWN)],
		[true, 0, 3, Crafting.Refusal.NO_PIECE, Crafting.Refusal.NOTHING])
	bag.add(PIECE)
	GearSet.of(body).wear(PIECE)
	Flags.set_flag(StringName(GearUpgrades.PREFIX + String(PIECE)), 1)
	equal("a worn piece taken apart comes off, and its level is forgotten",
		[Crafting.dismantle(bag, PIECE), GearSet.wearing(body, PIECE), GearUpgrades.level(PIECE), bag.count_of(ORE)],
		[true, false, 0, 5])
	GearDb.for_item(PIECE).rarity = TIER
	equal("a tier whose salvage is 0 is never taken apart", Crafting.salvage(PIECE), {})


func _body() -> Node:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	body.add_child(Inventory.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_crafter"
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 40.0, &"attack": 2.0, &"defence": 1.0, &"speed": 5.0}
	body.add_child(fighter)
	attach(body)
	body.add_child(GearSet.new())
	return body


func _write_content() -> void:
	_directory = RunScratch.path("crafting")
	for sub: String in ["gear", "rarities", "recipes"]:
		DirAccess.make_dir_recursive_absolute(_directory.path_join(sub))
	var tier := Rarity.new()
	tier.id = TIER
	tier.name_key = "ui.cancel"
	tier.salvage = 0.0
	ResourceSaver.save(tier, _directory.path_join("rarities/fixture_whole.tres"))
	ResourceSaver.save(_piece(), _directory.path_join("gear/fixture_craft_coat.tres"))
	var secret: Recipe = _recipe("fixture_secret", Recipe.Kind.TRANSMUTE, {ORE: 2}, {GEMSTONE: 1})
	secret.needs_flag = BLUEPRINT
	secret.lucky_outputs = {GEMSTONE: 2}
	secret.lucky_chance = 1.0
	var coat: Recipe = _recipe("fixture_coat", Recipe.Kind.CRAFT, {ORE: 4}, {PIECE: 1})
	coat.station = FORGE
	for made: Recipe in [coat, secret, _recipe("fixture_raise", Recipe.Kind.UPGRADE, {}, {}, PIECE),
			_recipe("fixture_crown", Recipe.Kind.AWAKEN, {ORE: 1}, {CROWN: 1}, PIECE),
			_recipe("fixture_break", Recipe.Kind.DISMANTLE, {}, {ORE: 3}, SCRAP)]:
		ResourceSaver.save(made, _directory.path_join("recipes/%s.tres" % String(made.id).get_file()))
	RarityDb.content_dir = _directory.path_join("rarities")
	RarityDb.rescan()
	GearDb.content_dir = _directory.path_join("gear")
	GearDb.rescan()
	RecipeDb.content_dir = _directory.path_join("recipes")
	RecipeDb.rescan()


func _recipe(name: String, kind: Recipe.Kind, inputs: Dictionary[StringName, int],
		outputs: Dictionary[StringName, int], piece: StringName = &"") -> Recipe:
	var made := Recipe.new()
	made.id = StringName(RecipeDb.ID_PREFIX + name)
	made.name_key = "ui.cancel"
	made.kind = kind
	made.inputs = inputs
	made.outputs = outputs
	made.piece = piece
	return made


# A coat with a one-level track that costs one ore.
func _piece() -> GearDefinition:
	var kind := GearType.new()
	kind.type_id = &"gear_type/fixture_craft_coat"
	kind.name_key = "ui.cancel"
	kind.slots = [&"body"]
	var level := UpgradeLevel.new()
	level.items = {ORE: 1}
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + "fixture_craft_coat")
	made.item_id = PIECE
	made.type = kind
	made.upgrade = UpgradeTrack.new()
	made.upgrade.levels = [level]
	return made
