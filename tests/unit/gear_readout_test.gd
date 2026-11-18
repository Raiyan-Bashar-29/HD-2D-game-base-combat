extends TestCase
## What the gear screens say (C10.18): a worn piece's row shows its level, its gems and its fights
## to the next level; a set worn in part lists its tiers with the reached ones marked; a
## multiplier compares as a share; a won fight's results name a piece it raised.
##
## OWNS: assertions about `PieceScreen.summary`, `GearScreen.sets_text`, the share in
## `GearScreen.compare` and `BattleReadout.raised`.
## MUST NOT: name a game's gear, sets or fighters. The files go to this run's scratch directory.

const HERO: StringName = &"fixture_gearread_hero"
const BLADE: StringName = FixtureContent.WORN_ITEM
const HELM: StringName = FixtureContent.UNIQUE_ITEM
const CHARM: StringName = FixtureContent.SPARE_ITEM
const GEM: StringName = FixtureContent.HELD_ITEM


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	var body: Node3D = _wearer()
	var bag: Inventory = Inventory.of(body)
	var gear: GearSet = GearSet.of(body)
	gear.wear(BLADE, &"weapon")
	gear.wear(HELM, &"head")
	Flags.set_flag(&"upgrade/" + String(BLADE), 2)
	Flags.set_flag(&"upgrade_fights/" + String(BLADE), 3)
	GearSockets.socket(bag, BLADE, GEM)
	equal("a worn piece's summary gives its level, its gems and its fights to the next level",
		PieceScreen.summary(BLADE), "  ".join(PackedStringArray([
			tr(PieceScreen.SUMMARY_LEVEL_KEY).format({"level": 2, "cap": 3}),
			tr(PieceScreen.SUMMARY_GEMS_KEY).format({"filled": 1, "total": 2}),
			tr(PieceScreen.SUMMARY_FIGHTS_KEY).format({"won": 3, "need": 5})])))
	equal("a set worn in part lists its tiers, the reached one marked", GearScreen.sets_text(gear),
		[tr(GearScreen.SET_KEY).format({"set": "fixture_gearread_set", "worn": 2,
			"tiers": tr(GearScreen.TIER_ON_KEY).format({"pieces": 2}) + " 3"})] as Array[String])
	equal("a multiplier compares as a share", GearScreen.compare(&"", CHARM).contains(
		tr(GearScreen.GAIN_PCT_KEY).format({"stat": tr("combat.stat.attack"), "amount": 20})), true)
	var rewards := Rewards.new()
	rewards.upgraded[HERO] = [BLADE]
	equal("a won fight's results name a piece it raised", BattleReadout.raised(rewards),
		[tr(BattleReadout.RAISED_KEY).format({"item": PieceScreen.item_name(BLADE), "level": 2})] as Array[String])
	body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	Flags.clear_all()


func _wearer() -> Node3D:
	var def := CombatantDef.new()
	def.combatant_id = HERO
	var body := Node3D.new()
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	body.add_child(fighter)
	attach(body)
	for item_id: StringName in [BLADE, HELM, GEM]:
		bag.add(item_id)
	GearSet.fit(body, def, true)
	return body


func _write_content() -> void:
	var directory: String = RunScratch.path("gear_readout")
	for sub: String in ["gear", "gems"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var bonus := GearSetBonus.new()
	bonus.set_id = &"fixture_gearread_set"
	for count: int in [2, 3]:
		var tier := GearSetTier.new()
		tier.pieces = count
		bonus.tiers.append(tier)
	ResourceSaver.save(bonus, directory.path_join("fixture_gearread_set.tres"))
	var shared: GearSetBonus = load(directory.path_join("fixture_gearread_set.tres")) as GearSetBonus
	var blade: GearDefinition = _piece("fixture_gearread_blade", BLADE, &"weapon")
	blade.sockets = 2
	blade.set_bonus = shared
	blade.upgrade = UpgradeTrack.new()
	for need: int in [0, 0, 5]:
		var step := UpgradeLevel.new()
		step.items = {CHARM: 1}
		step.fights = need
		blade.upgrade.levels.append(step)
	ResourceSaver.save(blade, directory.path_join("gear/fixture_gearread_blade.tres"))
	var helm: GearDefinition = _piece("fixture_gearread_helm", HELM, &"head")
	helm.set_bonus = shared
	ResourceSaver.save(helm, directory.path_join("gear/fixture_gearread_helm.tres"))
	var charm: GearDefinition = _piece("fixture_gearread_charm", CHARM, &"body")
	charm.modifiers = [StatModifier.of(&"attack", StatModifier.Op.MULTIPLY, 1.2, &"")]
	ResourceSaver.save(charm, directory.path_join("gear/fixture_gearread_charm.tres"))
	var gem := GemDefinition.new()
	gem.id = StringName(GemDb.ID_PREFIX + "fixture_gearread_gem")
	gem.item_id = GEM
	ResourceSaver.save(gem, directory.path_join("gems/fixture_gearread_gem.tres"))
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
