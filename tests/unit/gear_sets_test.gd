extends TestCase
## Gear sets (C7.4b): pieces sharing a `set_bonus` give each tier their worn count reaches (stat
## changes under `set/<set id>`, a kit under `set/<set id>/<pieces>`), and lose a tier when a
## piece comes off. A refresh does not give a bonus twice, and a set's kit reaches starting gear.
##
## OWNS: assertions about `GearSetBonus`, `GearSetTier`, `GearDefinition.set_bonus` and
## `lends_kit`, `GearDb.set_ids` and `GearSetBonuses.apply` through `GearSet`.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const BLADE: StringName = FixtureContent.STACK_ITEM
const HELM: StringName = FixtureContent.SPARE_ITEM
const RING: StringName = FixtureContent.HELD_ITEM
const OTHER: StringName = FixtureContent.UNIQUE_ITEM
const HERO: StringName = &"fixture_set_wearer"
const AURA: StringName = &"status/fixture_set_aura"

var _directory: String
var _made: Dictionary[String, GearDefinition] = {}


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_gear()
	_content()
	_tiers(_body(false))
	_kept()
	_starting()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var blade: GearDefinition = GearDb.for_item(BLADE)
	equal("a piece of a sound set has no problems", blade.problems().size(), 0)
	var broken := GearSetBonus.new()
	broken.tiers = [_tier(0, 1.0), _tier(2, 1.0), _tier(2, 1.0)]
	var piece := GearDefinition.new()
	piece.item_id = BLADE
	piece.type = blade.type
	piece.set_bonus = broken
	equal("no set_id, a tier below one piece and a repeated count, carried by the piece",
		[broken.problems("x").size(), piece.problems().size()], [3, 3])


func _tiers(body: Node) -> void:
	var gear: GearSet = GearSet.of(body)
	var sheet: StatSheet = Combatant.of(body).sheet
	gear.wear(BLADE)
	equal("one piece reaches no tier", sheet.value(&"strength"), 4.0)
	gear.wear(HELM)
	equal("two pieces give the first tier", sheet.value(&"strength"), 7.0)
	gear.wear(RING)
	equal("three pieces lend the second tier's kit, on a power set made for it", _aura(body), true)
	gear.refresh()
	equal("a refresh does not give the bonus twice", sheet.value(&"strength"), 7.0)
	gear.take_off(RING)
	equal("taking one off drops the kit and keeps the first tier",
		[_aura(body), sheet.value(&"strength")], [false, 7.0])
	gear.take_off(HELM)
	equal("one piece left is no tier again", sheet.value(&"strength"), 4.0)
	gear.wear(OTHER)
	equal("a piece of another set counts only for its own", sheet.value(&"strength"), 104.0)


# The saved path writes flags; the bonus is the same.
func _kept() -> void:
	Flags.clear_all()
	var body: Node = _body(true)
	GearSet.of(body).wear(BLADE)
	GearSet.of(body).wear(HELM)
	equal("a kept set gives the same bonus", Combatant.of(body).sheet.value(&"strength"), 7.0)
	Flags.clear_all()


# Starting pieces whose set lends a kit get a power set while the body is being built.
func _starting() -> void:
	var body: Node = _body(false, [BLADE, HELM, RING])
	equal("starting pieces reach the set's kit", _aura(body), true)


# Whether the body has a power set holding the set kit's passive.
func _aura(body: Node) -> bool:
	var powers: PowerSet = PowerSet.of(body)
	return powers != null and powers.status(AURA) != null


func _body(keep: bool, innate: Array[StringName] = []) -> Node:
	var body := Node.new()
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"strength": 4.0}
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.kept = keep
	gear.innate = innate
	body.add_child(gear)
	attach(body)
	for item_id: StringName in [BLADE, HELM, RING, OTHER]:
		bag.add(item_id)
	return body


func _write_gear() -> void:
	_directory = RunScratch.path("gear_sets")
	DirAccess.make_dir_recursive_absolute(_directory)
	var trio := GearSetBonus.new()
	trio.set_id = &"gear_set/fixture_trio"
	var second: GearSetTier = _tier(3, 0.0)
	second.modifiers.clear()
	second.kit = _kit()
	trio.tiers = [_tier(2, 3.0), second]
	var lone := GearSetBonus.new()
	lone.set_id = &"gear_set/fixture_lone"
	lone.tiers = [_tier(1, 100.0)]
	_save("fixture_set_blade", BLADE, _type("fixture_set_blade", &"weapon")).set_bonus = trio
	_save("fixture_set_helm", HELM, _type("fixture_set_helm", &"head")).set_bonus = trio
	_save("fixture_set_ring", RING, _type("fixture_set_ring", &"accessory_1")).set_bonus = trio
	_save("fixture_set_other", OTHER, _type("fixture_set_other", &"accessory_2")).set_bonus = lone
	for name: String in _made:
		ResourceSaver.save(_made[name], _directory.path_join(name + ".tres"))
	GearDb.content_dir = _directory
	GearDb.rescan()


func _tier(pieces: int, strength: float) -> GearSetTier:
	var made := GearSetTier.new()
	made.pieces = pieces
	made.modifiers = [StatModifier.of(&"strength", StatModifier.Op.ADD, strength, &"")]
	return made


func _kit() -> PowerKit:
	var made := PowerKit.new()
	made.kit_id = &"kit/fixture_set"
	made.name_key = "ui.cancel"
	var aura := StatusEffect.new()
	aura.id = AURA
	aura.name_key = "ui.cancel"
	aura.duration = 0.0
	made.passives = [aura]
	return made


func _type(name: String, slot: StringName) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = [slot]
	return made


func _save(name: String, item_id: StringName, kind: GearType) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	_made[name] = made
	return made
