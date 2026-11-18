extends TestCase
## Gear upkeep (C10.17): a piece's gems come back to the bag when the piece is used up, and its
## sockets are forgotten; awakening a worn, socketed piece wears the new one in its slot and gives
## the gems back; an UNCURSE effect takes cursed pieces off and leaves the rest on.
##
## OWNS: assertions about `GearSockets.empty_out`, the awaken swap and `SkillEffect.Kind.UNCURSE`.
## MUST NOT: name a game's gear, gems or fighters. The files go to this run's scratch directory.

const HERO: StringName = &"fixture_upkeep_hero"
const PIECE: StringName = FixtureContent.WORN_ITEM
const AWAKENED: StringName = FixtureContent.UNIQUE_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEM: StringName = FixtureContent.STACK_ITEM
const HEX: StringName = FixtureContent.HELD_ITEM


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	var def := CombatantDef.new()
	def.combatant_id = HERO
	def.name_key = "ui.pause.title"
	var body: Node3D = _wearer(def)
	var bag: Inventory = Inventory.of(body)
	var gear: GearSet = GearSet.of(body)
	GearSockets.socket(bag, PIECE, GEM)
	var back: Array[StringName] = GearSockets.empty_out(bag, PIECE)
	equal("emptying a piece gives its gems back and forgets its sockets",
		[back, bag.count_of(GEM), GearSockets.gems(PIECE)], [[GEM] as Array[StringName], 3, [&""] as Array[StringName]])
	GearSockets.socket(bag, PIECE, GEM)
	GearUpgrades.upgrade(bag, PIECE)
	GearUpgrades.awaken(bag, PIECE)
	equal("awakening a worn, socketed piece wears the new one in its slot and gives the gems back",
		[gear.worn(&"weapon"), bag.has(PIECE), bag.count_of(GEM), Flags.with_prefix("socket/%s/" % PIECE).size()],
		[AWAKENED, false, 3, 0])
	gear.wear(HEX, &"head")
	var lift := Skill.new()
	lift.id = &"skill/fixture_upkeep_lift"
	lift.target = FactionTable.Target.ANY
	var effect := SkillEffect.new()
	effect.kind = SkillEffect.Kind.UNCURSE
	lift.effects = [effect]
	SkillUse.apply(Combatant.of(body), lift, [Combatant.of(body)], RandomNumberGenerator.new())
	equal("an UNCURSE effect takes the cursed piece off and leaves the rest on",
		[gear.worn(&"head"), gear.worn(&"weapon")], [&"", AWAKENED])
	body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	Flags.clear_all()


func _write_content() -> void:
	var directory: String = RunScratch.path("gear_upkeep")
	for sub: String in ["gear", "gems"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var piece: GearDefinition = _piece("fixture_upkeep_coat", PIECE, &"weapon")
	piece.sockets = 1
	piece.upgrade = UpgradeTrack.new()
	var step := UpgradeLevel.new()
	step.items = {ORE: 1}
	piece.upgrade.levels = [step]
	piece.upgrade.awaken_into = AWAKENED
	piece.upgrade.awaken_items = {ORE: 1}
	ResourceSaver.save(piece, directory.path_join("gear/fixture_upkeep_coat.tres"))
	ResourceSaver.save(_piece("fixture_upkeep_crown", AWAKENED, &"weapon"), directory.path_join("gear/fixture_upkeep_crown.tres"))
	var hex: GearDefinition = _piece("fixture_upkeep_hex", HEX, &"head")
	hex.cursed = true
	ResourceSaver.save(hex, directory.path_join("gear/fixture_upkeep_hex.tres"))
	var gem := GemDefinition.new()
	gem.id = StringName(GemDb.ID_PREFIX + "fixture_upkeep_gem")
	gem.item_id = GEM
	ResourceSaver.save(gem, directory.path_join("gems/fixture_upkeep_gem.tres"))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	GemDb.content_dir = directory.path_join("gems")
	GemDb.rescan()


func _piece(name: String, item_id: StringName, slot: StringName) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.slot = slot
	return made


func _wearer(def: CombatantDef) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0}
	body.add_child(fighter)
	attach(body)
	bag.add(PIECE)
	bag.add(HEX)
	bag.add(GEM, 3)
	bag.add(ORE, 5)
	GearSet.fit(body, def, true)
	GearSet.of(body).wear(PIECE, &"weapon")
	return body
