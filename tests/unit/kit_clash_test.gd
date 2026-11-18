extends TestCase
## Kits and sets that cannot clash (C10.11): two kits listing one power id, or holding one
## passive status id, clash and say so; disjoint kits do not; putting a clashing kit on a
## fighter beside another logs a warning; two pieces of one set naming different bonus files
## are a problem of the gear catalogue.
##
## OWNS: assertions about `PowerKit.clashes`, the warning in `PowerSet`, and `GearDb`'s set check.
## MUST NOT: name a game's kits, gear or sets. The gear files go to this run's scratch directory.

func run() -> void:
	plan(4)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	var shared := _power(&"power/fixture_clash_shared")
	var aura := StatusEffect.new()
	aura.id = &"status/fixture_clash_aura"
	var one: PowerKit = _kit(&"kit/fixture_clash_one", [shared, _power(&"power/fixture_clash_a")], [aura])
	var two: PowerKit = _kit(&"kit/fixture_clash_two", [shared], [aura])
	var three: PowerKit = _kit(&"kit/fixture_clash_three", [_power(&"power/fixture_clash_b")], [])
	equal("a shared power id and a shared passive id each clash; a kit never clashes with itself",
		one.clashes([one, two]).size(), 2)
	equal("disjoint kits do not clash", one.clashes([three]).size(), 0)
	var body := Node.new()
	body.add_child(Combatant.new())
	var powers := PowerSet.new()
	body.add_child(powers)
	attach(body)
	powers.equip(one)
	var before: int = Log.tally().x
	powers.lend({&"fixture_clash_gear": two} as Dictionary[StringName, PowerKit])
	equal("lending a clashing kit beside the fighter's own logs a warning for each clash", Log.tally().x - before, 2)
	body.free()
	_sets()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _sets() -> void:
	var directory: String = RunScratch.path("kit_clash")
	DirAccess.make_dir_recursive_absolute(directory)
	_save_piece(directory, "fixture_clash_helm", FixtureContent.WORN_ITEM)
	_save_piece(directory, "fixture_clash_boots", FixtureContent.STACK_ITEM)
	GearDb.content_dir = directory
	GearDb.rescan()
	equal("two pieces of one set naming different bonus files are a problem",
		Array(GearDb.problems()).any(func(line: String) -> bool: return line.contains("fixture_clash_set")), true)


func _save_piece(directory: String, name: String, item_id: StringName) -> void:
	var bonus := GearSetBonus.new()
	bonus.set_id = &"fixture_clash_set"
	var piece := GearDefinition.new()
	piece.id = StringName(GearDb.ID_PREFIX + name)
	piece.item_id = item_id
	piece.slot = &"head"
	piece.set_bonus = bonus
	ResourceSaver.save(piece, directory.path_join(name + ".tres"))


func _power(id: StringName) -> Power:
	var made := Power.new()
	made.power_id = id
	made.name_key = "fixture.power"
	made.passive = true
	return made


func _kit(id: StringName, list: Array[Power], held: Array[StatusEffect]) -> PowerKit:
	var made := PowerKit.new()
	made.kit_id = id
	made.name_key = "fixture.kit"
	made.powers = list
	made.passives = held
	return made
