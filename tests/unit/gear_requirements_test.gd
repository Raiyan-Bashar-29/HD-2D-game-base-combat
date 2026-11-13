extends TestCase
## Who may wear what (C7.4a): a piece's `needs_level` and `needs_stats` refuse a wearer below them,
## a starting piece skips both, and a `cursed` piece stays on: it cannot be taken off in the
## ordinary way, and a piece that would push it out is refused. Losing the item still takes it off.
##
## OWNS: assertions about `GearDefinition.needs_level`, `needs_stats`, `cursed` and their checks,
## and `GearSet.refusal`, `wear` and `take_off` obeying them.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const HEAVY: StringName = FixtureContent.STACK_ITEM
const MIGHTY: StringName = FixtureContent.SPARE_ITEM
const CURSED_RING: StringName = FixtureContent.UNIQUE_ITEM
const RING: StringName = FixtureContent.HELD_ITEM
const GREAT: StringName = FixtureContent.WORN_ITEM
const HERO: StringName = &"fixture_requirer"

var _directory: String
# The pieces built for this run, by file name; saved once they are all set.
var _made: Dictionary[String, GearDefinition] = {}


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_content()
	_write_gear()
	var body: Node = _body()
	_level_and_stats(GearSet.of(body))
	_curse(GearSet.of(body), Inventory.of(body))
	_starting()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var piece := GearDefinition.new()
	piece.item_id = HEAVY
	piece.type = _type("fixture_blade", [&"weapon"])
	equal("a plain piece has no problems", piece.problems().size(), 0)
	piece.needs_level = -1
	piece.needs_stats = {&"": 2.0}
	equal("a level below zero and an unnamed stat are two problems", piece.problems().size(), 2)


func _level_and_stats(gear: GearSet) -> void:
	equal("level 1 is below the piece's level 3", [gear.refusal(HEAVY), gear.wear(HEAVY)],
		[GearSet.Refusal.LEVEL_TOO_LOW, false])
	Flags.set_flag(StringName(Party.LEVEL_PREFIX + String(HERO)), 3)
	equal("at level 3 it goes on", gear.wear(HEAVY), true)
	equal("strength 4 is below the 10 the piece needs", [gear.refusal(MIGHTY), gear.wear(MIGHTY)],
		[GearSet.Refusal.STATS_TOO_LOW, false])


func _curse(gear: GearSet, bag: Inventory) -> void:
	gear.wear(CURSED_RING, &"accessory_1")
	equal("a cursed piece cannot be taken off", [gear.take_off(CURSED_RING), gear.worn(&"accessory_1")],
		[false, CURSED_RING])
	equal("another piece may not push it out of its slot",
		[gear.refusal(RING, &"accessory_1"), gear.wear(RING, &"accessory_1")], [GearSet.Refusal.CURSED, false])
	equal("but a free slot is still free", gear.wear(RING, &"accessory_2"), true)
	equal("a piece that blocks the cursed piece's slot is refused", gear.refusal(GREAT), GearSet.Refusal.CURSED)
	gear.take_off(RING)
	equal("the cursed piece may still move between its own slots",
		[gear.wear(CURSED_RING, &"accessory_2"), gear.worn(&"accessory_2")], [true, CURSED_RING])
	equal("forcing it takes it off", [gear.take_off(CURSED_RING, true), gear.worn(&"accessory_2")], [true, &""])
	gear.wear(CURSED_RING)
	bag.remove(CURSED_RING)
	equal("losing the item takes the cursed piece off", gear.slot_of(CURSED_RING), &"")


# A starting piece is the fighter's own: it skips the level and stat checks.
func _starting() -> void:
	Flags.clear_all()
	var gear: GearSet = GearSet.of(_body([HEAVY, MIGHTY]))
	equal("starting pieces go on below their level and stats",
		[gear.worn(&"weapon"), gear.worn(&"head")], [HEAVY, MIGHTY])


func _body(innate: Array[StringName] = []) -> Node:
	var body := Node.new()
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"strength": 4.0}
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.kept = false
	gear.innate = innate
	body.add_child(gear)
	attach(body)
	for item_id: StringName in [HEAVY, MIGHTY, CURSED_RING, RING, GREAT]:
		bag.add(item_id)
	return body


func _write_gear() -> void:
	_directory = RunScratch.path("gear_requirements")
	DirAccess.make_dir_recursive_absolute(_directory)
	var blade := _type("fixture_blade", [&"weapon"])
	var ring := _type("fixture_ring", [&"accessory_1", &"accessory_2"])
	_save("fixture_heavy", HEAVY, blade).needs_level = 3
	var mighty := _save("fixture_mighty", MIGHTY, _type("fixture_helm", [&"head"]))
	mighty.needs_stats = {&"strength": 10.0}
	_save("fixture_cursed_ring", CURSED_RING, ring).cursed = true
	_save("fixture_ring", RING, ring)
	_save("fixture_great", GREAT, blade).blocks = [&"accessory_1"]
	for name: String in _made:
		ResourceSaver.save(_made[name], _directory.path_join(name + ".tres"))
	GearDb.content_dir = _directory
	GearDb.rescan()


func _type(name: String, slots: Array[StringName]) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = slots
	return made


# Builds a piece; `_write_gear` saves it once every field is set.
func _save(name: String, item_id: StringName, kind: GearType) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	_made[name] = made
	return made
