extends TestCase
## Upgrade levels won by fights (C9.5d): a level with `fights` cannot be bought; each won fight
## with the piece worn counts towards it, and at the number the piece goes up and the wearer
## has the level's gain. A bought level and a won level can share one track.
##
## OWNS: assertions about `UpgradeLevel.fights`, `GearUpgrades.practise`, `fights_won`,
## `Refusal.EARNED` and `Rewards.upgraded`.
## MUST NOT: name a game's gear or items, or wait for frames. The gear files are written to this
## run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.WORN_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const AWAKENED: StringName = FixtureContent.UNIQUE_ITEM
const HERO: StringName = &"fixture_fights_wearer"

var _def: CombatantDef


func run() -> void:
	plan(9)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_def = CombatantDef.new()
	_def.combatant_id = HERO
	_shapes()
	_winning(_body())
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _shapes() -> void:
	var both := UpgradeLevel.new()
	both.items = {ORE: 1}
	both.fights = 2
	var below := UpgradeLevel.new()
	below.fights = -1
	equal("a won level is sound; one bought and won, one with neither, and one below zero are flagged",
		[GearDb.for_item(PIECE).problems().size(), both.problems("x").size(),
		UpgradeLevel.new().problems("x").size(), below.problems("x").size()], [0, 1, 1, 2])


func _winning(body: Node) -> void:
	var bag: Inventory = Inventory.of(body)
	var fighter: Combatant = Combatant.of(body)
	bag.add(ORE, 5)
	equal("a won level cannot be bought, and the bag is left alone",
		[GearUpgrades.refusal(bag, PIECE), GearUpgrades.upgrade(bag, PIECE), bag.count_of(ORE)],
		[GearUpgrades.Refusal.EARNED, false, 5])
	var off: Rewards = Rewards.give(0, [], [_def], null)
	equal("a win with the piece off counts nothing",
		[off.upgraded.size(), GearUpgrades.fights_won(PIECE)], [0, 0])
	GearSet.of(body).wear(PIECE)
	var first: Rewards = Rewards.give(0, [], [_def], null)
	equal("the first win with it on is counted, and the level waits",
		[first.upgraded.size(), GearUpgrades.fights_won(PIECE), GearUpgrades.level(PIECE),
		fighter.sheet.value(&"attack")], [0, 1, 0, 6.0])
	var second: Rewards = Rewards.give(0, [], [_def], null)
	equal("the second win raises the piece, the count starts again, and the wearer has the gain",
		[second.upgraded, GearUpgrades.fights_won(PIECE), GearUpgrades.level(PIECE),
		fighter.sheet.value(&"attack")], [{HERO: [PIECE]}, 0, 1, 8.0])
	equal("a win does not count towards a bought level, which is still bought",
		[GearUpgrades.practise(HERO), GearUpgrades.fights_won(PIECE), GearUpgrades.upgrade(bag, PIECE),
		GearUpgrades.level(PIECE), bag.count_of(ORE)], [[], 0, true, 2, 4])
	equal("a one-fight level after it is won by the next win",
		[GearUpgrades.practise(HERO), GearUpgrades.level(PIECE), fighter.sheet.value(&"defence")],
		[[PIECE], 3, 4.0])
	equal("at the cap a win counts nothing",
		[GearUpgrades.practise(HERO), GearUpgrades.fights_won(PIECE), GearUpgrades.level(PIECE)], [[], 0, 3])
	Flags.set_flag(StringName("upgrade_fights/%s" % PIECE), 1)
	equal("awakening forgets the count with the level",
		[GearUpgrades.awaken(bag, PIECE), GearUpgrades.fights_won(PIECE), GearUpgrades.level(PIECE)],
		[true, 0, 0])


func _body() -> Node:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 40.0, &"attack": 2.0, &"defence": 1.0, &"speed": 5.0}
	body.add_child(fighter)
	attach(body)
	body.add_child(GearSet.new())
	bag.add(PIECE)
	return body


func _write_content() -> void:
	var directory: String = RunScratch.path("gear_fights")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(_piece("fixture_fights_coat", PIECE, &"body"), directory.path_join("fixture_fights_coat.tres"))
	ResourceSaver.save(_piece("fixture_fights_crown", AWAKENED, &"head"),
		directory.path_join("fixture_fights_crown.tres"))
	GearDb.content_dir = directory
	GearDb.rescan()
	# The track goes on the loaded piece, so the test holds the very objects.
	var piece: GearDefinition = GearDb.for_item(PIECE)
	piece.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 4.0, &"")]
	piece.upgrade = UpgradeTrack.new()
	piece.upgrade.levels = [_won(2), UpgradeLevel.new(), _won(1)]
	piece.upgrade.levels[0].stat_bonus = 0.5
	piece.upgrade.levels[1].items = {ORE: 1}
	piece.upgrade.levels[2].modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 3.0, &"")]
	piece.upgrade.awaken_into = AWAKENED


func _won(fights: int) -> UpgradeLevel:
	var made := UpgradeLevel.new()
	made.fights = fights
	return made


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
