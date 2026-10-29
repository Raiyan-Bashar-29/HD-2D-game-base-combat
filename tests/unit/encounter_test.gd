extends TestCase
## `CombatantDef`, `Encounter`, `EncounterDb`, `BattleSetup` and `EncounterPoint`: what an author
## can get wrong, a group of two of one enemy told apart, enemies starting full while the party
## keeps its hp, the chosen turn order, brains handed over, release leaving no enemy flags, and
## the field point asking for its encounter.
##
## OWNS: assertions about turning an encounter into a battle and back.
## MUST NOT: name a game's encounters or fighters. Every name here is made up for the case.

var _requested: Array[StringName] = []


func run() -> void:
	plan(17)
	SaveFixture.activate()
	Flags.clear_all()
	_problems()
	_a_built_battle()
	_release_leaves_no_trace()
	_the_field_point()
	_a_scan()
	Flags.clear_all()


func _def(id: StringName, side: StringName, hp: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": hp, &"speed": 5.0}
	return def


func _encounter() -> Encounter:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_pack"
	var thinker := _def(&"fixture_bat", &"side_b", 8.0)
	thinker.brain = BattleBrain.new()
	encounter.enemies = [_def(&"fixture_blob", &"side_b", 10.0), _def(&"fixture_blob", &"side_b", 10.0), thinker]
	return encounter


func _says(found: PackedStringArray, text: String) -> bool:
	for problem: String in found:
		if problem.contains(text):
			return true
	return false


func _problems() -> void:
	equal("a sound encounter has no problems", _encounter().problems(), PackedStringArray())
	var empty := Encounter.new()
	empty.id = &"encounter/fixture_empty"
	equal("an encounter with no enemies is caught", _says(empty.problems(), "no enemies"), true)
	var frail := _encounter()
	frail.enemies[0].base_stats = {}
	equal("a fighter with no max_hp is caught", _says(frail.problems(), "no max_hp"), true)
	var broken := _encounter()
	var bad := BattleCommand.new()
	bad.kind = BattleCommand.Kind.SKILL
	broken.enemies[2].commands = [bad]
	equal("a fighter's broken command is caught", _says(broken.problems(), "names no skill"), true)


func _a_built_battle() -> void:
	Flags.clear_all()
	Flags.set_flag(&"vital/fixture_blob_1/hp", 1)
	Flags.set_flag(&"vital/fixture_lead/hp", 7)
	var holder := Node.new()
	attach(holder)
	var encounter := _encounter()
	encounter.turn_order = Encounter.TurnOrder.CTB
	encounter.can_flee = false
	var battle := BattleSetup.build(encounter, [_def(&"fixture_lead", &"side_a", 20.0)], holder)
	var ids: Array[StringName] = []
	for fighter: Combatant in battle.enemies:
		ids.append(fighter.combatant_id)
	equal("two of one enemy are told apart, a single one is not", ids, [&"fixture_blob_1", &"fixture_blob_2", &"fixture_bat"])
	equal("every fighter is a node under the holder", holder.get_child_count(), 4)
	equal("an enemy starts full, whatever an old flag said", Vitals.of(battle.enemies[0].get_parent()).current(&"hp"), 10)
	equal("the party keeps its hp from the field", Vitals.of(battle.party[0].get_parent()).current(&"hp"), 7)
	equal("the encounter's turn order is built", battle.scheduler is CtbScheduler, true)
	equal("and its flee rule copied", battle.can_flee, false)
	equal("a fighter with a brain is played by it", battle.brain_of(battle.enemies[2]) != null, true)
	equal("one without is not", battle.brain_of(battle.enemies[0]), null)
	holder.free()


func _release_leaves_no_trace() -> void:
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var battle := BattleSetup.build(_encounter(), [_def(&"fixture_lead", &"side_a", 20.0)], holder)
	Vitals.of(battle.enemies[0].get_parent()).change(&"hp", -3)
	Vitals.of(battle.party[0].get_parent()).change(&"hp", -3)
	BattleSetup.release(battle)
	equal("release erases the enemies' pool flags", Flags.has_flag(&"vital/fixture_blob_1/hp"), false)
	equal("but keeps the party's", Flags.get_int(&"vital/fixture_lead/hp"), 17)
	equal("and frees every fighter", battle.enemies[0].get_parent().is_queued_for_deletion(), true)
	holder.free()


func _the_field_point() -> void:
	_requested.clear()
	Events.encounter_requested.connect(_on_requested)
	var point := EncounterPoint.new()
	point.label_key = "fixture.label"
	point.encounter_id = &"encounter/fixture_pack"
	attach(point)
	var who := Node3D.new()
	attach(who)
	point.attempt(who)
	equal("interacting asks for its encounter by id", _requested, [&"encounter/fixture_pack"])
	Events.encounter_requested.disconnect(_on_requested)
	point.free()
	who.free()


func _a_scan() -> void:
	EncounterDb.content_dir = EncounterDb.ENCOUNTER_DIR
	EncounterDb.rescan()
	equal("every encounter under data/ is sound", EncounterDb.problems(), PackedStringArray())


func _on_requested(encounter_id: StringName) -> void:
	_requested.append(encounter_id)
