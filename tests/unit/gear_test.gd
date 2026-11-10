extends TestCase
## Gear as data, worn (C7.1a): a piece of gear is an item plus a gear file; wearing it puts its
## stat changes on the wearer and taking it off removes them; a slot holds one piece; the piece
## stays in the bag and comes off when the item is lost; and what is worn survives a save.
##
## OWNS: assertions about `GearType`, `GearRules`, `GearDefinition`, `GearDb` and `GearSet`.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const WHO: StringName = &"fixture_wearer"
const SLOT: int = 3
const BASE_ATTACK: float = 5.0
const BLADE: StringName = FixtureContent.STACK_ITEM
const SECOND_BLADE: StringName = FixtureContent.WORN_ITEM
const HELM: StringName = FixtureContent.SPARE_ITEM
const RING: StringName = FixtureContent.UNIQUE_ITEM
const SECOND_RING: StringName = FixtureContent.HELD_ITEM
const THIRD_RING: StringName = FixtureContent.OTHER_HELD_ITEM

var _directory: String
var _body: Node
var _gear: GearSet
var _sheet: StatSheet
var _bag: Inventory


func run() -> void:
	plan(28)
	SaveFixture.activate()
	Fixtures.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Flags.clear_all()
	_shapes()
	_write_gear()
	_build()
	_wearing()
	_slots()
	_refusals()
	_the_bag()
	_saves()
	_body.free()
	SaveSystem.delete_slot(SLOT)
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	equal("the real gear, or none in a stripped template, has no problems", GearDb.problems().size(), 0)
	Flags.clear_all()


func _shapes() -> void:
	var rules := GearRules.new()
	equal("the default rules have nine slots and no problems",
		[rules.slots.size(), rules.problems("fixture").size()], [9, 0])
	rules.slots = [&"weapon", &"weapon", &""]
	equal("a slot listed twice and an unnamed slot are problems", rules.problems("fixture").size(), 2)
	var kind := GearType.new()
	equal("a type with no id, name or slots has three problems", kind.problems("fixture").size(), 3)
	var piece := GearDefinition.new()
	equal("a piece with no item and no type has two problems", piece.problems().size(), 2)
	piece.item_id = BLADE
	piece.type = _type("fixture_blade", [&"weapon"], 0.0)
	piece.slot = &"head"
	equal("a slot its type does not allow is a problem", piece.problems().size(), 1)
	piece.slot = &""
	equal("with no slot of its own, a piece takes its type's", piece.slots(), [&"weapon"])


func _write_gear() -> void:
	_directory = RunScratch.path("gear")
	DirAccess.make_dir_recursive_absolute(_directory)
	var blade := _type("fixture_blade", [&"weapon"], 0.0)
	var plate := _type("fixture_plate", [&"head"], -1.0)
	var ring := _type("fixture_ring", [&"accessory_1", &"accessory_2"], 0.0)
	_save("fixture_blade", BLADE, blade, 4.0)
	_save("fixture_blade_two", SECOND_BLADE, blade, 7.0)
	_save("fixture_helm", HELM, plate, 0.0)
	_save("fixture_ring", RING, ring, 1.0)
	_save("fixture_ring_two", SECOND_RING, ring, 2.0)
	var owned := _piece("fixture_ring_three", THIRD_RING, ring, 3.0)
	owned.wearers = [&"fixture_someone_else"]
	ResourceSaver.save(owned, _directory.path_join("fixture_ring_three.tres"))
	GearDb.content_dir = _directory
	GearDb.rescan()
	equal("the scratch gear loads with no problems", GearDb.problems().size(), 0)
	equal("an item that is gear is found, and one that is not is not",
		[GearDb.for_item(BLADE) != null, GearDb.for_item(FixtureContent.ABSENT_ITEM)], [true, null])


func _build() -> void:
	_body = Node.new()
	_bag = Inventory.new()
	_body.add_child(_bag)
	var fighter := Combatant.new()
	fighter.combatant_id = WHO
	fighter.base_stats = {&"attack": BASE_ATTACK, &"speed": 3.0}
	_body.add_child(fighter)
	_gear = GearSet.new()
	_body.add_child(_gear)
	attach(_body)
	_sheet = fighter.sheet
	for item_id: StringName in [BLADE, SECOND_BLADE, HELM, RING, SECOND_RING, THIRD_RING]:
		_bag.add(item_id)
	equal("the worn set is found on the body", GearSet.of(_body), _gear)


func _wearing() -> void:
	equal("wearing a piece changes something", _gear.wear(BLADE), true)
	equal("its stat change is on the wearer", _sheet.value(&"attack"), BASE_ATTACK + 4.0)
	equal("it is worn in its slot, and the flag an author can name says so",
		[_gear.worn(&"weapon"), Flags.get_string(_gear.key(BLADE))], [BLADE, "weapon"])
	equal("the piece is still in the bag", _bag.has(BLADE), true)
	equal("wearing it again changes nothing", [_gear.wear(BLADE), _sheet.value(&"attack")],
		[false, BASE_ATTACK + 4.0])
	_gear.wear(HELM)
	equal("a type's own stat change comes with every piece of it", _sheet.value(&"speed"), 2.0)
	equal("taking a piece off removes its changes",
		[_gear.take_off(HELM), _sheet.value(&"speed"), _gear.take_off(HELM)], [true, 3.0, false])


func _slots() -> void:
	_gear.wear(SECOND_BLADE)
	equal("a second piece in a full slot takes the first one off",
		[_gear.worn(&"weapon"), _gear.slot_of(BLADE), _sheet.value(&"attack")],
		[SECOND_BLADE, &"", BASE_ATTACK + 7.0])
	_gear.wear(RING)
	_gear.wear(SECOND_RING)
	equal("a piece that fits two slots takes the free one",
		[_gear.worn(&"accessory_1"), _gear.worn(&"accessory_2")], [RING, SECOND_RING])
	equal("and can be moved to a slot by name, taking off what was there",
		[_gear.wear(SECOND_RING, &"accessory_1"), _gear.worn_ids()], [true, [SECOND_RING, SECOND_BLADE]])
	equal("the stats follow", _sheet.value(&"attack"), BASE_ATTACK + 7.0 + 2.0)


func _refusals() -> void:
	equal("an item with no gear file is not gear",
		_gear.refusal(FixtureContent.ABSENT_ITEM), GearSet.Refusal.NOT_GEAR)
	equal("a piece listing other wearers is refused", _gear.refusal(THIRD_RING), GearSet.Refusal.WRONG_WEARER)
	equal("a slot named that the piece does not fit is refused", _gear.wear(RING, &"weapon"), false)
	_gear.rules.slots = [&"weapon"]
	equal("a piece none of whose slots this fighter has is refused",
		[_gear.refusal(RING), _gear.wear(RING)], [GearSet.Refusal.NO_SLOT, false])
	_gear.rules.slots = GearRules.DEFAULT_SLOTS.duplicate()


func _the_bag() -> void:
	_bag.remove(SECOND_RING)
	equal("losing the item takes the piece off, and it cannot be worn again",
		[_gear.slot_of(SECOND_RING), _sheet.value(&"attack"), _gear.refusal(SECOND_RING)],
		[&"", BASE_ATTACK + 7.0, GearSet.Refusal.NOT_CARRIED])


func _saves() -> void:
	SaveSystem.save_to_slot(SLOT)
	_gear.take_off(SECOND_BLADE)
	_gear.wear(BLADE)
	SaveSystem.load_from_slot(SLOT)
	equal("after a load the saved piece is worn again, with its changes on once",
		[_gear.worn(&"weapon"), _sheet.value(&"attack")], [SECOND_BLADE, BASE_ATTACK + 7.0])
	Flags.clear_all()
	Events.game_started.emit()
	equal("a new game starts with nothing worn", [_gear.worn_ids().size(), _sheet.value(&"attack")],
		[0, BASE_ATTACK])


func _type(name: String, slots: Array[StringName], speed: float) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = slots
	if speed != 0.0:
		made.modifiers = [StatModifier.of(&"speed", StatModifier.Op.ADD, speed, &"")]
	return made


func _piece(name: String, item_id: StringName, kind: GearType, attack: float) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	if attack != 0.0:
		made.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, attack, &"")]
	return made


func _save(name: String, item_id: StringName, kind: GearType, attack: float) -> void:
	ResourceSaver.save(_piece(name, item_id, kind, attack), _directory.path_join(name + ".tres"))
