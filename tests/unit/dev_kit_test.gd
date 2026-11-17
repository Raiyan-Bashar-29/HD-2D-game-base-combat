extends TestCase
## The `power_kit` development verb (C6.23). Alone it lists the kits; with a name it equips
## `kit/<name>` (or the full id) on the player, adding a `PowerSet` when there is none; `none` takes
## the kit off; an unknown kit or no player is refused, never a crash. The console reaches it
## through `DevCommands.run`.
##
## OWNS: assertions about `DevKit` and its verb in `DevCommands`.
## MUST NOT: name a game's kits or fighters, or wait for frames.

const KIT: StringName = &"kit/fixture_dev_kit"


func run() -> void:
	plan(6)
	var directory: String = RunScratch.path("dev_kits")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(_kit(), directory.path_join("fixture_dev_kit.tres"))
	PowerKitDb.content_dir = directory
	PowerKitDb.rescan()
	var before: Node3D = Director.player
	Director.player = null
	equal("with no player a kit is refused, and alone the verb lists the kits",
		[DevKit.power_kit("fixture_dev_kit").begins_with("power_kit found no fighter"),
			DevCommands.run("power_kit")], [true, "power_kit kits: %s" % KIT])
	var body := Node3D.new()
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_dev_kit_hero"
	body.add_child(fighter)
	attach(body)
	Director.player = body
	var said: String = DevCommands.run("power_kit fixture_dev_kit")
	var powers: PowerSet = PowerSet.of(body)
	equal("a name equips its kit on a player that had no PowerSet",
		[said, powers != null and powers.kit != null and powers.kit.kit_id == KIT],
		["power_kit put %s on the player" % KIT, true])
	equal("the full id works the same", DevKit.power_kit(String(KIT)).ends_with("on the player"), true)
	equal("an unknown kit is refused", DevKit.power_kit("fixture_missing"),
		"power_kit has no kit 'kit/fixture_missing'")
	DevKit.power_kit(DevKit.NONE)
	equal("none takes the kit off", powers.kit, null)
	equal("the verb is in the console's vocabulary", DevCommands.VERBS.has(DevKit.VERB), true)
	Director.player = before
	body.free()
	PowerKitDb.content_dir = PowerKitDb.KIT_DIR
	PowerKitDb.rescan()


func _kit() -> PowerKit:
	var step := BlinkMechanism.new()
	var entry := Power.new()
	entry.power_id = &"power/fixture_dev_kit_step"
	entry.name_key = "fixture.dev_kit.power"
	entry.mechanism = step
	var kit := PowerKit.new()
	kit.kit_id = KIT
	kit.name_key = "fixture.dev_kit.name"
	kit.powers = [entry]
	return kit
