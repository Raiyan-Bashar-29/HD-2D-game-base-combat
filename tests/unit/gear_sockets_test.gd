extends TestCase
## Gem sockets (C7.4c): a gem socketed into a piece is used up, gives its stat changes and its
## element while the piece is worn, and comes back out into the bag, using up a remover when the
## project names one. A refresh does not give a gem twice.
##
## OWNS: assertions about `GemDefinition`, `GemDb`, `GearDefinition.sockets` and
## `socket_count`, and `GearSockets` through `GearSet`.
## MUST NOT: name a game's gear, gems or items, or wait for frames. The gear, gem and rarity
## files are written to this run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.STACK_ITEM
const PLAIN: StringName = FixtureContent.UNIQUE_ITEM
const RUBY: StringName = FixtureContent.SPARE_ITEM
const FLAME: StringName = FixtureContent.HELD_ITEM
const REMOVER: StringName = FixtureContent.OTHER_HELD_ITEM
const HERO: StringName = &"fixture_socket_wearer"
const TIER: StringName = &"rarity/fixture_socketed"

var _directory: String


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_content()
	_sockets(_body())
	ProjectSettings.set_setting(GearSockets.REMOVER_SETTING, "")
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	RarityDb.content_dir = RarityDb.RARITY_DIR
	RarityDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var broken := GemDefinition.new()
	equal("a sound gem has no problems; one with no item that gives nothing has two",
		[GemDb.for_item(RUBY).problems().size(), broken.problems().size()], [0, 2])
	var piece := GearDefinition.new()
	piece.item_id = PIECE
	piece.type = GearDb.for_item(PIECE).type
	piece.sockets = -1
	equal("a piece with fewer than zero sockets is flagged", piece.problems().size(), 1)
	equal("the gems load with no problems, and a gem is found by its item",
		[GemDb.problems().size(), GemDb.for_item(FLAME) != null, GemDb.for_item(REMOVER)], [0, true, null])
	equal("a piece holds its own sockets plus its rarity's", GearDb.for_item(PIECE).socket_count(), 2)


func _sockets(body: Node) -> void:
	var bag: Inventory = Inventory.of(body)
	var gear: GearSet = GearSet.of(body)
	var fighter: Combatant = Combatant.of(body)
	equal("not gear, not a gem, and a gem not carried are each refused", [
		GearSockets.socket_refusal(bag, REMOVER, RUBY), GearSockets.socket_refusal(bag, PIECE, REMOVER),
		GearSockets.socket_refusal(bag, PIECE, RUBY)], [GearSockets.Refusal.NOT_GEAR,
		GearSockets.Refusal.NOT_GEM, GearSockets.Refusal.NOT_CARRIED])
	bag.add(RUBY)
	bag.add(FLAME)
	equal("a piece with no sockets takes no gem", GearSockets.socket_refusal(bag, PLAIN, RUBY),
		GearSockets.Refusal.NO_FREE_SOCKET)
	gear.wear(PIECE)
	equal("a socketed gem is used up and its stat change is on the wearer",
		[GearSockets.socket(bag, PIECE, RUBY), bag.count_of(RUBY), fighter.sheet.value(&"strength")], [true, 0, 9.0])
	GearSockets.socket(bag, PIECE, FLAME)
	equal("a gem's element counts before the piece's own, and both sockets are filled",
		[fighter.lent_element, GearSockets.gems(PIECE)], [&"fixture_fire", [RUBY, FLAME]])
	gear.refresh()
	equal("a refresh does not give a gem twice, and the socket is a saved flag",
		[fighter.sheet.value(&"strength"), Flags.get_string(StringName("socket/%s/0" % PIECE))], [9.0, String(RUBY)])
	ProjectSettings.set_setting(GearSockets.REMOVER_SETTING, String(REMOVER))
	equal("with a remover named and none carried, the gem stays in",
		GearSockets.removal_refusal(bag, PIECE, 1), GearSockets.Refusal.NO_REMOVER)
	bag.add(REMOVER)
	equal("taking a gem out uses up the remover and gives the gem and the piece's element back",
		[GearSockets.unsocket(bag, PIECE, 1), bag.count_of(FLAME), bag.count_of(REMOVER), fighter.lent_element],
		[true, 1, 0, &"fixture_plain"])
	ProjectSettings.set_setting(GearSockets.REMOVER_SETTING, "")
	equal("with no remover named, taking a gem out is free",
		[GearSockets.unsocket(bag, PIECE, 0), bag.count_of(RUBY), fighter.sheet.value(&"strength")], [true, 1, 4.0])
	gear.take_off(PIECE)
	GearSockets.socket(bag, PIECE, RUBY)
	var unworn: float = fighter.sheet.value(&"strength")
	gear.wear(PIECE)
	var worn: float = fighter.sheet.value(&"strength")
	gear.take_off(PIECE)
	equal("a gem in a piece not worn gives nothing, and wearing the piece gives it",
		[unworn, worn, fighter.sheet.value(&"strength")], [4.0, 9.0, 4.0])


func _body() -> Node:
	var body := Node.new()
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"strength": 4.0}
	body.add_child(fighter)
	body.add_child(GearSet.new())
	attach(body)
	bag.add(PIECE)
	bag.add(PLAIN)
	return body


func _write_content() -> void:
	_directory = RunScratch.path("gear_sockets")
	for sub: String in ["gear", "gems", "rarities"]:
		DirAccess.make_dir_recursive_absolute(_directory.path_join(sub))
	var tier := Rarity.new()
	tier.id = TIER
	tier.name_key = "ui.cancel"
	tier.sockets = 1
	ResourceSaver.save(tier, _directory.path_join("rarities/fixture_socketed.tres"))
	var piece: GearDefinition = _piece("fixture_socket_blade", PIECE, &"weapon")
	piece.sockets = 1
	piece.rarity = TIER
	piece.element = &"fixture_plain"
	ResourceSaver.save(piece, _directory.path_join("gear/fixture_socket_blade.tres"))
	ResourceSaver.save(_piece("fixture_socket_ring", PLAIN, &"accessory_1"),
		_directory.path_join("gear/fixture_socket_ring.tres"))
	var ruby: GemDefinition = _gem("fixture_ruby", RUBY)
	ruby.modifiers = [StatModifier.of(&"strength", StatModifier.Op.ADD, 5.0, &"")]
	ResourceSaver.save(ruby, _directory.path_join("gems/fixture_ruby.tres"))
	var flame: GemDefinition = _gem("fixture_flame", FLAME)
	flame.element = &"fixture_fire"
	ResourceSaver.save(flame, _directory.path_join("gems/fixture_flame.tres"))
	RarityDb.content_dir = _directory.path_join("rarities")
	RarityDb.rescan()
	GearDb.content_dir = _directory.path_join("gear")
	GearDb.rescan()
	GemDb.content_dir = _directory.path_join("gems")
	GemDb.rescan()


func _piece(name: String, item_id: StringName, slot: StringName) -> GearDefinition:
	var kind := GearType.new()
	kind.type_id = StringName("gear_type/" + name)
	kind.name_key = "ui.cancel"
	kind.slots = [slot]
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	return made


func _gem(name: String, item_id: StringName) -> GemDefinition:
	var made := GemDefinition.new()
	made.id = StringName(GemDb.ID_PREFIX + name)
	made.item_id = item_id
	return made
