extends TestCase
## The weapon and its mode on the HUD and the battle screen (C7.7b). No weapon shows nothing;
## a worn weapon shows its name; a form from the weapon's own kit adds its name as the mode,
## and a form from elsewhere does not.
##
## OWNS: assertions about `WeaponLine`.
## MUST NOT: name a game's gear or fighters, or wait for frames. The gear file is written to
## this run's scratch directory, over a fixture item.

const HERO: StringName = &"fixture_weapon_line_hero"
const LANCE: StringName = FixtureContent.STACK_ITEM
const NOON: float = 12.0

var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	var mode: Power = _form("mode", "fixture.weapon.mode")
	var other: Power = _form("other", "fixture.weapon.other")
	_write_gear(mode)
	var body: Node3D = _wearer()
	equal("no weapon worn: nothing is shown", WeaponLine.text(body), "")
	GearSet.of(body).wear(LANCE, &"weapon")
	var shown: String = tr(ItemDb.definition(LANCE).name_key)
	equal("a worn weapon shows its name", WeaponLine.text(body),
		tr(WeaponLine.KEY).format({"weapon": shown}))
	# The gear file was saved and loaded, so its kit holds its own copy of the power.
	mode = _held(body, mode.power_id)
	PowerUse.use(Combatant.of(body), mode, [], _rng, NOON)
	equal("a form of the weapon's own kit is its mode", WeaponLine.text(body),
		tr(WeaponLine.MODE_KEY).format({"weapon": shown, "mode": tr("fixture.weapon.mode")}))
	PowerUse.use(Combatant.of(body), mode, [], _rng, NOON)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_weapon_line_own"
	kit.powers = [other]
	PowerSet.of(body).hold_kit(kit, &"fixture_own")
	PowerUse.use(Combatant.of(body), other, [], _rng, NOON)
	equal("a form from elsewhere is not the weapon's mode",
		WeaponLine.mode_key(body, GearDb.for_item(LANCE)), "")
	body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _held(body: Node, power_id: StringName) -> Power:
	for power: Power in PowerSet.of(body).powers():
		if power.power_id == power_id:
			return power
	return null


func _form(short: String, label: String) -> Power:
	var status := StatusEffect.new()
	status.id = StringName("fixture_weapon_line_" + short)
	status.name_key = "fixture.status"
	var form := FormMechanism.new()
	form.status = status
	form.name_key = label
	var power := Power.new()
	power.power_id = StringName("power/fixture_weapon_line_" + short)
	power.name_key = "fixture.power"
	power.mechanism = form
	return power


func _write_gear(mode: Power) -> void:
	var directory: String = RunScratch.path("weapon_line")
	DirAccess.make_dir_recursive_absolute(directory)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_weapon_line"
	kit.powers = [mode]
	var piece := GearDefinition.new()
	piece.id = StringName(GearDb.ID_PREFIX + "fixture_weapon_line_lance")
	piece.item_id = LANCE
	piece.slot = &"weapon"
	piece.kit = kit
	ResourceSaver.save(piece, directory.path_join("fixture_weapon_line_lance.tres"))
	GearDb.content_dir = directory
	GearDb.rescan()


func _wearer() -> Node3D:
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
	bag.add(LANCE)
	var def := CombatantDef.new()
	def.combatant_id = HERO
	GearSet.fit(body, def, true)
	return body
