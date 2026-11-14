extends TestCase
## The kit catalogue (C9.6b): `PowerKitDb` finds every kit file by id and reports a broken one.
##
## It also reads whatever kits and gear the game has (none in a stripped template) and checks
## what no single file can: each loads sound, and every passive a piece or a form lends is a
## file in the passive library.
##
## OWNS: assertions about `PowerKitDb`.
## MUST NOT: name a game's kits, forms, gear or passives.

const SOUND: StringName = &"kit/fixture_kd_sound"


func run() -> void:
	plan(5)
	_real()
	_scratch()
	PowerKitDb.content_dir = PowerKitDb.KIT_DIR
	PowerKitDb.rescan()


func _real() -> void:
	PowerKitDb.rescan()
	equal("the real kits, or none in a stripped template, have no problems",
		PowerKitDb.problems(), PackedStringArray())
	var strays: Array[StringName] = []
	for kit_id: StringName in PowerKitDb.ids():
		for entry: Power in PowerKitDb.kit(kit_id).powers:
			var form: FormMechanism = entry.mechanism as FormMechanism
			if form == null:
				continue
			strays.append_array(_strays(form.passive_skills))
			for stage: FormMechanism in form.cycle:
				strays.append_array(_strays(stage.passive_skills))
	if DirAccess.dir_exists_absolute(GearDb.GEAR_DIR):
		for path: String in ContentScan.resource_paths(GearDb.GEAR_DIR):
			var piece: GearDefinition = load(path) as GearDefinition
			if piece != null:
				strays.append_array(_strays(piece.passives))
	equal("every passive a real form or piece lends is in the passive library", strays, [])


func _scratch() -> void:
	var directory: String = RunScratch.path("kits")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(_kit(SOUND, true), directory.path_join("fixture_kd_sound.tres"))
	ResourceSaver.save(_kit(&"kit/fixture_kd_dry", false), directory.path_join("fixture_kd_dry.tres"))
	ResourceSaver.save(_kit(&"kit/fixture_kd_other", true), directory.path_join("fixture_kd_named.tres"))
	PowerKitDb.content_dir = directory
	PowerKitDb.rescan()
	equal("a kit file is found by its id, and an unknown id is null",
		[PowerKitDb.kit(SOUND) != null, PowerKitDb.kit(&"kit/none")], [true, null])
	equal("a form draining a pool its kit does not give, and an id unlike its file name, are each a problem",
		[PowerKitDb.problems().size(), PowerKitDb.kit(&"kit/fixture_kd_other")], [2, null])
	equal("a kit with a problem of that kind is still listed, a misnamed one is not",
		PowerKitDb.ids().size(), 2)


# The ids in `lent` that the passive library does not hold.
func _strays(lent: Array[PassiveSkill]) -> Array[StringName]:
	var out: Array[StringName] = []
	for passive: PassiveSkill in lent:
		if passive == null or PassiveDb.passive(passive.id) == null:
			out.append(passive.id if passive != null else &"")
	return out


func _kit(kit_id: StringName, gives_pool: bool) -> PowerKit:
	var held := StatusEffect.new()
	held.id = &"status/fixture_kd_form"
	held.duration = 0.0
	var form := FormMechanism.new()
	form.status = held
	form.drain_pool = &"fixture_kd_pool"
	form.drain_per_turn = 5.0
	var entry := Power.new()
	entry.power_id = &"power/fixture_kd_form"
	entry.name_key = "fixture.kd.power"
	entry.mechanism = form
	var kit := PowerKit.new()
	kit.kit_id = kit_id
	kit.name_key = "fixture.kd.kit"
	kit.powers = [entry]
	if gives_pool:
		kit.stat_bonuses = [StatModifier.of(&"max_fixture_kd_pool", StatModifier.Op.ADD, 50.0, kit_id)]
	return kit
