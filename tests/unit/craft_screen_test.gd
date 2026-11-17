extends TestCase
## The craft screen (C7.8): a `CraftStation` asks for it; the host opens it at that station;
## it lists the recipes known there with what they need, greys one that cannot be made with the
## reason, makes one when pressed, and takes a piece apart.
##
## OWNS: assertions about `CraftStation`, `CraftHost` and `CraftScreen`.
## MUST NOT: name a game's gear, items or recipes, or wait for frames. The files are written to
## this run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.WORN_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEMSTONE: StringName = FixtureContent.STACK_ITEM
const FORGE: StringName = &"fixture_screen_forge"

var _asked: Array[StringName] = []


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	var station := CraftStation.new()
	station.station = FORGE
	station.label_key = "ui.cancel"
	attach(station)
	Events.craft_requested.connect(_on_asked)
	var who := Node3D.new()
	station.perform(who)
	who.free()
	Events.craft_requested.disconnect(_on_asked)
	var stack := UiRoot.new()
	attach(stack)
	var host := CraftHost.new()
	host.bag = Inventory.new()
	attach(host)
	host.bag.add(ORE, 3)
	equal("a station asks for its screen, and the host opens it there",
		[_asked, host.open(stack, FORGE), (stack.top() as CraftScreen).station if stack.top() is CraftScreen else &""],
		[[FORGE], true, FORGE])
	_screen(stack.top() as CraftScreen, host.bag)
	stack.close_all()
	var elsewhere: CraftScreen = CraftScreen.for_station(&"", host.bag)
	stack.open(elsewhere)
	equal("another station does not offer the forge's recipe",
		_row_starting(elsewhere, tr("ui.pause.resume")), null)
	stack.close_all()
	for node: Node in [station, host, stack]:
		node.free()
	RecipeDb.content_dir = RecipeDb.RECIPE_DIR
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	RecipeDb.rescan()
	Flags.clear_all()


func _screen(screen: CraftScreen, bag: Inventory) -> void:
	var coat: Button = _row_starting(screen, tr("ui.pause.resume"))
	var gem: Button = _row_starting(screen, tr("ui.pause.save"))
	equal("the recipes known here are listed with what they need; one short of materials is greyed",
		[coat != null and coat.text.contains(CraftScreen.listed({ORE: 2})), coat.disabled if coat != null else true,
			gem.disabled if gem != null else false,
			gem.text.contains(tr(CraftScreen.refusal_key(Crafting.Refusal.INPUTS))) if gem != null else false],
		[true, false, true, true])
	coat.pressed.emit()
	equal("pressing a recipe makes it and says so",
		[bag.count_of(PIECE), bag.count_of(ORE), screen.row_texts().has(tr(CraftScreen.MADE_KEY).format(
			{"name": tr("ui.pause.resume")}))], [1, 1, true])
	var apart: Button = _row_starting(screen, tr(ItemDb.definition(PIECE).name_key))
	apart.pressed.emit()
	equal("a piece in the bag can be taken apart for what it gives back",
		[bag.count_of(PIECE), bag.count_of(ORE)], [0, 2])


func _on_asked(at: StringName) -> void:
	_asked.append(at)


func _row_starting(screen: CraftScreen, text: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			return button
	return null


func _write_content() -> void:
	var directory: String = RunScratch.path("craft_screen")
	for sub: String in ["gear", "recipes"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var piece := GearDefinition.new()
	piece.id = StringName(GearDb.ID_PREFIX + "fixture_screen_coat")
	piece.item_id = PIECE
	piece.slot = &"body"
	ResourceSaver.save(piece, directory.path_join("gear/fixture_screen_coat.tres"))
	var coat: Recipe = _recipe("fixture_screen_coat", Recipe.Kind.CRAFT, {ORE: 2}, {PIECE: 1}, "ui.pause.resume")
	coat.station = FORGE
	var gem: Recipe = _recipe("fixture_screen_gem", Recipe.Kind.TRANSMUTE, {ORE: 9}, {GEMSTONE: 1}, "ui.pause.save")
	var scrap: Recipe = _recipe("fixture_screen_scrap", Recipe.Kind.DISMANTLE, {}, {ORE: 1}, "ui.menu.load")
	scrap.piece = PIECE
	for made: Recipe in [coat, gem, scrap]:
		ResourceSaver.save(made, directory.path_join("recipes/%s.tres" % String(made.id).get_file()))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	RecipeDb.content_dir = directory.path_join("recipes")
	RecipeDb.rescan()


func _recipe(name: String, kind: Recipe.Kind, inputs: Dictionary[StringName, int],
		outputs: Dictionary[StringName, int], label: String) -> Recipe:
	var made := Recipe.new()
	made.id = StringName(RecipeDb.ID_PREFIX + name)
	made.name_key = label
	made.kind = kind
	made.inputs = inputs
	made.outputs = outputs
	return made
