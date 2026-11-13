extends TestCase
## Upgrading and awakening (C7.5): a piece goes up its track one paid level at a time, and while
## it is worn each reached level gives a share of its added amounts again, its own stat changes
## and sockets; a power in its kit can wait for a level; at the cap the piece awakens into
## another. A refresh does not give a level twice.
##
## OWNS: assertions about `UpgradeLevel`, `UpgradeTrack`, `GearDefinition.upgrade`,
## `max_upgrade` and `upgrade_cap`, `Rarity.max_upgrade`, `Power.requires_upgrade` and
## `GearUpgrades` through `GearSet` and `PowerUse`.
## MUST NOT: name a game's gear, items or powers, or wait for frames. The gear and rarity files
## are written to this run's scratch directory, over the fixture items.

const PIECE: StringName = FixtureContent.WORN_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const AWAKENED: StringName = FixtureContent.UNIQUE_ITEM
const HERO: StringName = &"fixture_upgrade_wearer"
const TIER: StringName = &"rarity/fixture_capped"

var _directory: String


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_content()
	_upgrading(_body())
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	RarityDb.content_dir = RarityDb.RARITY_DIR
	RarityDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var piece: GearDefinition = GearDb.for_item(PIECE)
	var stray := UpgradeTrack.new()
	stray.awaken_items = {ORE: 1}
	var greedy := Power.new()
	greedy.power_id = &"power/fixture_greedy"
	greedy.name_key = "ui.cancel"
	greedy.passive = true
	greedy.requires_upgrade = -1
	equal("a sound track has no problems; a free level, an empty track, a cost with nothing to "
			+ "awaken into, and a power needing a level below zero are each flagged",
		[piece.problems().size(), UpgradeLevel.new().problems("x").size(), stray.problems("x").size(),
		greedy.problems("x").size()], [0, 1, 2, 1])
	var capped := GearDefinition.new()
	capped.upgrade = piece.upgrade
	var caps: Array[int] = [piece.upgrade_cap()]
	capped.rarity = TIER
	caps.append(capped.upgrade_cap())
	capped.max_upgrade = 2
	caps.append(capped.upgrade_cap())
	equal("the cap is the track's length, else the piece's own, else its rarity's; no track is 0",
		caps + [GearDb.for_item(AWAKENED).upgrade_cap()], [3, 1, 2, 0])


func _upgrading(body: Node) -> void:
	var bag: Inventory = Inventory.of(body)
	var gear: GearSet = GearSet.of(body)
	var fighter: Combatant = Combatant.of(body)
	var gated: Power = GearDb.for_item(PIECE).kit.powers[0]
	equal("not gear, no track, no ore, and an awakening below the cap are each refused", [
		GearUpgrades.refusal(bag, ORE), GearUpgrades.refusal(bag, AWAKENED), GearUpgrades.refusal(bag, PIECE),
		GearUpgrades.awaken_refusal(bag, PIECE)], [GearUpgrades.Refusal.NOT_GEAR,
		GearUpgrades.Refusal.NO_TRACK, GearUpgrades.Refusal.COST, GearUpgrades.Refusal.NOT_READY])
	bag.add(ORE, 10)
	gear.wear(PIECE)
	equal("a level is paid for, and a worn piece gives half its added amount again",
		[GearUpgrades.upgrade(bag, PIECE), GearUpgrades.level(PIECE), bag.count_of(ORE),
		fighter.sheet.value(&"attack")], [true, 1, 9, 8.0])
	var key: String = PowerMenu.reason_key(fighter, gated)
	equal("a power waiting for level 2 is refused at level 1, and the menu has words for why",
		[PowerUse.refusal(fighter, gated), key, tr(key) != key],
		[PowerUse.Reason.UPGRADE, PowerMenu.UPGRADE_KEY, true])
	GearUpgrades.upgrade(bag, PIECE)
	equal("level 2 gives its own stat change and a socket, and lets the power be used",
		[fighter.sheet.value(&"defence"), GearSockets.gems(PIECE).size(), PowerUse.refusal(fighter, gated)],
		[4.0, 1, PowerUse.Reason.NONE])
	gear.refresh()
	equal("a refresh does not give a level twice",
		[fighter.sheet.value(&"attack"), fighter.sheet.value(&"defence")], [8.0, 4.0])
	GearUpgrades.upgrade(bag, PIECE)
	equal("the bonuses add up over the levels, and a multiplier is left alone",
		[fighter.sheet.value(&"attack"), is_equal_approx(fighter.sheet.value(&"speed"), 6.0)], [10.0, true])
	equal("at the cap no more levels are taken, and the level is a saved flag",
		[GearUpgrades.refusal(bag, PIECE), bag.count_of(ORE), Flags.get_int(StringName("upgrade/%s" % PIECE))],
		[GearUpgrades.Refusal.CAPPED, 6, 3])
	equal("a power that names the piece in requires_gear waits for its level too",
		_named_power_refusals(fighter), [PowerUse.Reason.NONE, PowerUse.Reason.UPGRADE])
	gear.take_off(PIECE)
	equal("taken off, the piece's levels give nothing",
		[fighter.sheet.value(&"attack"), fighter.sheet.value(&"defence")], [2.0, 1.0])
	equal("at the cap the piece awakens into another, paying the cost and starting it at level 0",
		[GearUpgrades.awaken(bag, PIECE), bag.count_of(PIECE), bag.count_of(AWAKENED), bag.count_of(ORE),
		GearUpgrades.level(PIECE)], [true, 0, 1, 5, 0])
	equal("an awakened piece cannot awaken again", GearUpgrades.awaken(bag, PIECE), false)


# Two powers of the fighter's own kit that name the piece: one waiting for level 3 (reached) and
# one for level 4 (beyond the cap).
func _named_power_refusals(fighter: Combatant) -> Array[PowerUse.Reason]:
	var own := PowerKit.new()
	own.kit_id = &"kit/fixture_upgrade_own"
	own.name_key = "ui.cancel"
	for needed: int in [3, 4]:
		var power: Power = _power(StringName("power/fixture_needs_%d" % needed), needed)
		power.requires_gear = PIECE
		own.powers.append(power)
	PowerSet.of(fighter.get_parent()).equip(own)
	return [PowerUse.refusal(fighter, own.powers[0]), PowerUse.refusal(fighter, own.powers[1])]


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
	body.add_child(PowerSet.new())
	attach(body)
	body.add_child(GearSet.new())
	bag.add(PIECE)
	return body


func _power(id: StringName, needed: int) -> Power:
	var skill := Skill.new()
	skill.id = StringName(String(id).replace("power/", "skill/"))
	skill.name_key = "ui.cancel"
	skill.power = 4.0
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = "ui.cancel"
	power.skill = skill
	power.requires_upgrade = needed
	return power


func _write_content() -> void:
	_directory = RunScratch.path("gear_upgrades")
	for sub: String in ["gear", "rarities"]:
		DirAccess.make_dir_recursive_absolute(_directory.path_join(sub))
	var tier := Rarity.new()
	tier.id = TIER
	tier.name_key = "ui.cancel"
	tier.max_upgrade = 1
	ResourceSaver.save(tier, _directory.path_join("rarities/fixture_capped.tres"))
	ResourceSaver.save(_piece("fixture_upgrade_coat", PIECE, &"body"), _directory.path_join("gear/fixture_upgrade_coat.tres"))
	ResourceSaver.save(_piece("fixture_upgrade_crown", AWAKENED, &"head"),
		_directory.path_join("gear/fixture_upgrade_crown.tres"))
	RarityDb.content_dir = _directory.path_join("rarities")
	RarityDb.rescan()
	GearDb.content_dir = _directory.path_join("gear")
	GearDb.rescan()
	# The track and the kit go on the loaded piece, so the test holds the very objects.
	var piece: GearDefinition = GearDb.for_item(PIECE)
	piece.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 4.0, &""),
		StatModifier.of(&"speed", StatModifier.Op.MULTIPLY, 1.2, &"")]
	piece.upgrade = UpgradeTrack.new()
	piece.upgrade.levels = [_level(1, 0.5), _level(2, 0.0), _level(1, 0.5)]
	piece.upgrade.levels[1].modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 3.0, &"")]
	piece.upgrade.levels[1].sockets = 1
	piece.upgrade.awaken_into = AWAKENED
	piece.upgrade.awaken_items = {ORE: 1}
	piece.kit = PowerKit.new()
	piece.kit.kit_id = &"kit/fixture_upgrade_coat"
	piece.kit.name_key = "ui.cancel"
	piece.kit.powers = [_power(&"power/fixture_upgraded", 2)]


func _level(ore: int, bonus: float) -> UpgradeLevel:
	var made := UpgradeLevel.new()
	made.items = {ORE: ore}
	made.stat_bonus = bonus
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
