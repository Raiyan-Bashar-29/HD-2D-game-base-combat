extends TestCase
## Passives from kits and gear (C9.3): a kit, a worn piece, a reached set tier, a socketed gem
## and a reached upgrade level each hand their passives to the wearer under their own source,
## and take them back when they go.
##
## OWNS: assertions about `PassiveLending`, `PassiveSet.sources`, `PowerKit.passive_skills`,
## and the `passives` lists of `GearDefinition`, `GearSetTier`, `GemDefinition` and
## `UpgradeLevel`.
## MUST NOT: name a game's passives, gear or fighters, or wait for frames. The gear and gem
## files are written to this run's scratch directory, over the fixture items.

const COAT: StringName = FixtureContent.WORN_ITEM
const CROWN: StringName = FixtureContent.UNIQUE_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEM: StringName = FixtureContent.STACK_ITEM
const HERO: StringName = &"fixture_lending_wearer"
const MP: int = 900

var _directory: String
var _body: Node3D


func run() -> void:
	plan(12)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_body = _wearer()
	_pieces()
	_gems_and_levels()
	_tiers()
	_kits()
	_body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	Flags.clear_all()


func _pieces() -> void:
	var gear: GearSet = GearSet.of(_body)
	gear.wear(CROWN)
	equal("a wearer of pieces with no passive gets no passive set", PassiveSet.of(_body), null)
	gear.take_off(CROWN)
	gear.wear(COAT)
	var coat: PassiveSkill = GearDb.for_item(COAT).passives[0]
	equal("a worn piece's passive is held under the piece, and its held status is on the wearer",
		[_sources(), _stacks(coat)], [[StringName("gear/%s" % COAT)], 1])
	PassiveMoments.skill(Combatant.of(_body), [])
	gear.refresh()
	PassiveMoments.skill(Combatant.of(_body), [])
	equal("its trigger wakes, and a refresh starts neither its count nor its status again",
		[_spent(), _stacks(coat)], [1, 1])
	PassiveLending.own(_body, _def([coat]))
	gear.take_off(COAT)
	equal("the same passive from the character and a piece counts once, and stays when the "
			+ "piece comes off", [_sources(), PassiveSet.of(_body).passives().size(), _stacks(coat)],
		[[PassiveSet.OWN], 1, 1])
	PassiveLending.own(_body, _def([]))
	equal("with no source left the passive and its status are gone", [_sources(), _stacks(coat)], [[], 0])


func _gems_and_levels() -> void:
	var gear: GearSet = GearSet.of(_body)
	var bag: Inventory = Inventory.of(_body)
	var gem: PassiveSkill = GemDb.for_item(GEM).passives[0]
	var level: PassiveSkill = GearDb.for_item(COAT).upgrade.levels[0].passives[0]
	GearDb.for_item(COAT).passives = []
	gear.wear(COAT)
	GearSockets.socket(bag, COAT, GEM)
	equal("a gem in a worn piece gives its passive", [_sources(), _stacks(gem)], [[PassiveLending.GEMS], 1])
	GearUpgrades.upgrade(bag, COAT)
	equal("a reached upgrade level gives its passive too",
		[_sources(), _stacks(level)], [[PassiveLending.GEMS, PassiveLending.UPGRADES], 1])
	GearSockets.unsocket(bag, COAT, 0)
	equal("the gem taken out takes only its own", [_sources(), _stacks(gem), _stacks(level)],
		[[PassiveLending.UPGRADES], 0, 1])
	gear.take_off(COAT)
	equal("a piece taken off takes its levels' passives", [_sources(), _stacks(level)], [[], 0])
	Flags.clear_all()


func _tiers() -> void:
	var gear: GearSet = GearSet.of(_body)
	var tier: PassiveSkill = GearDb.for_item(COAT).set_bonus.tiers[0].passives[0]
	Inventory.of(_body).add(COAT)
	Inventory.of(_body).add(CROWN)
	gear.wear(COAT)
	var one: int = _stacks(tier)
	gear.wear(CROWN)
	var both: Array[StringName] = _sources()
	gear.take_off(CROWN)
	equal("a set tier gives its passive only while enough pieces are worn",
		[one, both, _sources()], [0, [&"set/fixture_lending/2"], []])
	gear.take_off(COAT)


func _kits() -> void:
	var own: PowerKit = _kit("fixture_lending_own")
	var lent: PowerKit = _kit("fixture_lending_coat")
	GearDb.for_item(COAT).kit = lent
	var powers := PowerSet.new()
	_body.add_child(powers)
	powers.equip(own)
	GearSet.of(_body).wear(COAT)
	var on: Array[StringName] = _sources()
	powers.unequip()
	GearSet.of(_body).take_off(COAT)
	equal("a kit gives its passive skills while it is on, the fighter's own and one a piece lends",
		[on, _sources(), _stacks(own.passive_skills[0])],
		[[&"kit/kit/fixture_lending_own", StringName("kit/gear_kit/%s" % COAT)], [], 0])


func _sources() -> Array[StringName]:
	var passives: PassiveSet = PassiveSet.of(_body)
	return passives.sources() if passives != null else ([] as Array[StringName])


func _stacks(passive: PassiveSkill) -> int:
	return StatusSet.of(_body).stacks(passive.held.id)


func _spent() -> int:
	return MP - Vitals.of(_body).current(&"mp")


func _def(passives: Array[PassiveSkill]) -> CombatantDef:
	var def := CombatantDef.new()
	def.passives = passives
	return def


func _wearer() -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": float(MP), &"attack": 2.0}
	body.add_child(fighter)
	attach(body)
	Vitals.of(body).set_to(&"mp", MP)
	body.add_child(GearSet.new())
	bag.add(COAT)
	bag.add(CROWN)
	bag.add(ORE, 5)
	bag.add(GEM)
	return body


# A passive with a held status of its own, and a trigger that takes 1 MP once per fight when
# the holder uses a skill.
func _passive(name: String) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + name)
	made.name_key = "ui.cancel"
	made.held = StatusEffect.new()
	made.held.id = StringName(StatusDb.ID_PREFIX + name)
	var costs := PassiveEffect.new()
	costs.kind = PassiveEffect.Kind.POOL_FLAT
	costs.pool = &"mp"
	costs.amount = -1.0
	var waits := PassiveTrigger.new()
	waits.event = PassiveTrigger.Event.SKILL_USED
	waits.limit = 1
	waits.effects = [costs]
	made.triggers = [waits]
	return made


func _kit(name: String) -> PowerKit:
	var made := PowerKit.new()
	made.kit_id = StringName("kit/" + name)
	made.name_key = "ui.cancel"
	made.passive_skills = [_passive(name)]
	return made


func _write_content() -> void:
	_directory = RunScratch.path("passive_lending")
	for sub: String in ["gear", "gems"]:
		DirAccess.make_dir_recursive_absolute(_directory.path_join(sub))
	ResourceSaver.save(_piece("fixture_lending_coat", COAT, &"body"),
		_directory.path_join("gear/fixture_lending_coat.tres"))
	ResourceSaver.save(_piece("fixture_lending_crown", CROWN, &"head"),
		_directory.path_join("gear/fixture_lending_crown.tres"))
	var gem := GemDefinition.new()
	gem.id = StringName(GemDb.ID_PREFIX + "fixture_lending_gem")
	gem.item_id = GEM
	gem.passives = [_passive("fixture_lending_gem")]
	equal("a gem that gives only a passive is sound", gem.problems().size(), 0)
	ResourceSaver.save(gem, _directory.path_join("gems/fixture_lending_gem.tres"))
	GearDb.content_dir = _directory.path_join("gear")
	GearDb.rescan()
	GemDb.content_dir = _directory.path_join("gems")
	GemDb.rescan()
	# The lists go on the loaded pieces, so the test holds the very objects.
	var coat: GearDefinition = GearDb.for_item(COAT)
	coat.passives = [_passive("fixture_lending_piece")]
	coat.sockets = 1
	coat.upgrade = UpgradeTrack.new()
	coat.upgrade.levels = [UpgradeLevel.new()]
	coat.upgrade.levels[0].items = {ORE: 1}
	coat.upgrade.levels[0].passives = [_passive("fixture_lending_level")]
	coat.set_bonus = GearSetBonus.new()
	coat.set_bonus.set_id = &"fixture_lending"
	coat.set_bonus.tiers = [GearSetTier.new()]
	coat.set_bonus.tiers[0].passives = [_passive("fixture_lending_tier")]
	GearDb.for_item(CROWN).set_bonus = coat.set_bonus


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
