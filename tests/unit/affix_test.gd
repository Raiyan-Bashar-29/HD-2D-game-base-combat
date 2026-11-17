extends TestCase
## Affixes (C7.2b). A unique piece whose rarity gives affixes rolls that many, once, from those
## that fit its slot, each at most once and within its range; a stacked item rolls none. Loot
## given by `Rewards.give` rolls; the wearer gets the rolled changes; the gear screen counts them;
## forgetting (which `Crafting.dismantle` calls) clears them.
##
## OWNS: assertions about `Affix`, `AffixDb` and `GearAffixes`.
## MUST NOT: name a game's gear, rarities or affixes, or wait for frames. The files are written
## to this run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.WORN_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const TIER: StringName = &"rarity/fixture_affixed"
const STRONG: StringName = &"affix/fixture_strong"
const QUICK: StringName = &"affix/fixture_quick"
const CROWNED: StringName = &"affix/fixture_crowned"


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	equal("the scratch affixes are sound; one with no stat and high below low is flagged twice",
		[AffixDb.problems().size(), AffixDb.fitting([&"body"]).size(), _broken().problems().size()], [0, 2, 2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rolled: int = GearAffixes.roll(PIECE, rng)
	var mods: Array[StatModifier] = GearAffixes.of(PIECE)
	var stats: Array[StringName] = []
	for one: StatModifier in mods:
		stats.append(one.stat)
	stats.sort()
	equal("a unique piece rolls its rarity's two, each once, only those fitting its slot",
		[rolled, stats, GearAffixes.names(PIECE).size()], [2, [&"attack", &"speed"], 2])
	var in_range: bool = true
	for one: StatModifier in mods:
		in_range = in_range and one.value >= 2.0 and one.value <= 4.0
	equal("each value lies in its range; a second roll and a stacked item roll nothing",
		[in_range, GearAffixes.roll(PIECE, rng), GearAffixes.roll(ORE, rng)], [true, 0, 0])
	var body: Node = _wearing()
	GearAffixes.forget(PIECE)
	equal("forgetting (as taking the piece apart does) clears what it rolled",
		Flags.has_flag(&"affix/" + String(PIECE)), false)
	var fresh := Inventory.new()
	Rewards.give(0, [PIECE], [], fresh)
	fresh.free()
	equal("loot given rolls the piece afresh", GearAffixes.of(PIECE).size(), 2)
	GearDb.content_dir = GearDb.GEAR_DIR
	RarityDb.content_dir = RarityDb.RARITY_DIR
	AffixDb.content_dir = AffixDb.AFFIX_DIR
	for scan: Callable in [GearDb.rescan, RarityDb.rescan, AffixDb.rescan]:
		scan.call()
	body.free()
	Flags.clear_all()


func _wearing() -> Node:
	var body: Node = _wearer()
	var base: float = Combatant.of(body).sheet.value(&"attack")
	Inventory.of(body).add(PIECE)
	GearSet.of(body).wear(PIECE)
	equal("the wearer gets the rolled changes, and the gear screen counts them",
		[Combatant.of(body).sheet.value(&"attack") > base, GearScreen.compare(&"", PIECE).contains("+")], [true, true])
	return body


func _wearer() -> Node:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	body.add_child(Inventory.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_affix_wearer"
	fighter.base_stats = {&"max_hp": 40.0, &"attack": 2.0, &"speed": 5.0}
	body.add_child(fighter)
	attach(body)
	body.add_child(GearSet.new())
	return body


func _broken() -> Affix:
	var made := Affix.new()
	made.name_key = "ui.cancel"
	made.low = 2.0
	made.high = 1.0
	return made


func _affix(id: StringName, stat: StringName, slots: Array[StringName]) -> Affix:
	var made := Affix.new()
	made.id = id
	made.name_key = "ui.cancel"
	made.stat = stat
	made.low = 2.0
	made.high = 4.0
	made.slots = slots
	return made


func _write_content() -> void:
	var directory: String = RunScratch.path("affixes")
	for sub: String in ["gear", "rarities", "affixes"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var tier := Rarity.new()
	tier.id = TIER
	tier.name_key = "ui.cancel"
	tier.affixes = 2
	ResourceSaver.save(tier, directory.path_join("rarities/fixture_affixed.tres"))
	var kind := GearType.new()
	kind.type_id = &"gear_type/fixture_affix_coat"
	kind.name_key = "ui.cancel"
	kind.slots = [&"body"]
	var coat := GearDefinition.new()
	coat.id = StringName(GearDb.ID_PREFIX + "fixture_affix_coat")
	coat.item_id = PIECE
	coat.type = kind
	coat.rarity = TIER
	ResourceSaver.save(coat, directory.path_join("gear/fixture_affix_coat.tres"))
	for made: Affix in [_affix(STRONG, &"attack", []), _affix(QUICK, &"speed", [&"body"]),
			_affix(CROWNED, &"defence", [&"head"])]:
		ResourceSaver.save(made, directory.path_join("affixes/%s.tres" % String(made.id).get_file()))
	GearDb.content_dir = directory.path_join("gear")
	RarityDb.content_dir = directory.path_join("rarities")
	AffixDb.content_dir = directory.path_join("affixes")
	for scan: Callable in [GearDb.rescan, RarityDb.rescan, AffixDb.rescan]:
		scan.call()
