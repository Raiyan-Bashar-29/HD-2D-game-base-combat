extends TestCase
## `BattleScreen` and `BattleHost`: the screen opens over the world and will not cancel away, a
## command that needs a target asks for one, enemies play themselves between the player's turns,
## a refused command says so, and the end shows the outcome with one row that closes the screen
## and releases the fighters. The host refuses what it cannot build.
##
## OWNS: assertions about driving a battle through its screen.
## MUST NOT: name a game's fighters or encounters. Every name here is made up for the case.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(20)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	_a_battle_through_the_screen()
	_a_refusal_and_a_flight()
	_the_host_refuses()
	_holder.free()
	_stack.free()
	Flags.clear_all()


func _def(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = stats
	return def


func _encounter() -> Encounter:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_screen"
	var foe := _def(&"fixture_foe", &"side_b", {&"max_hp": 30.0, &"speed": 5.0, &"attack": 3.0})
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	return encounter


func _hero() -> CombatantDef:
	return _def(&"fixture_hero", &"side_a", {&"max_hp": 50.0, &"speed": 9.0, &"attack": 20.0})


func _press(screen: BattleScreen, text: String) -> bool:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text:
			button.pressed.emit()
			return true
	return false


func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return rng


func _a_battle_through_the_screen() -> void:
	Flags.clear_all()
	var battle := BattleSetup.build(_encounter(), [_hero()], _holder, _seeded())
	var screen := BattleScreen.for_battle(battle)
	equal("the screen opens", _stack.open(screen), true)
	equal("it stops the world", screen.pauses_world, true)
	equal("and cancel cannot leave it", screen.closes_on_cancel, false)
	equal("the player's turn offers the basic menu", screen.row_texts().has(tr(BattleScreen.ATTACK_KEY)), true)
	_press(screen, tr(BattleScreen.ATTACK_KEY))
	var foe: Combatant = battle.enemies[0]
	equal("an attack asks for its target", screen.row_texts().has(screen.name_of(foe)), true)
	equal("with a way back", screen.row_texts().has(tr(BattleScreen.BACK_KEY)), true)
	_press(screen, screen.name_of(foe))
	equal("the hit landed", Vitals.of(foe.get_parent()).current(&"hp") < 30, true)
	equal("the enemy then played its own turn", Vitals.of(battle.party[0].get_parent()).current(&"hp") < 50, true)
	equal("and the menu is the player's again", battle.current() == battle.party[0], true)
	# Bounded, so a screen that stops driving turns fails here instead of hanging the suite.
	for guard: int in 20:
		if battle.outcome() != Battle.Outcome.ONGOING:
			break
		_press(screen, tr(BattleScreen.ATTACK_KEY))
		_press(screen, screen.name_of(foe))
	equal("the end shows the outcome", screen.row_texts().has(tr(BattleScreen.WON_KEY)), true)
	var asked: Array[bool] = []
	screen.close_requested.connect(func() -> void: asked.append(true))
	_press(screen, tr(BattleScreen.CONTINUE_KEY))
	equal("its one row asks to close the screen", asked, [true])
	# UiRoot answers that request deferred, a frame this test never reaches, so close it the
	# way the deferred call would.
	_stack.close_top()
	equal("and closing released the fighters, erasing the enemy's flags", Flags.has_flag(&"vital/fixture_foe/hp"), false)


func _a_refusal_and_a_flight() -> void:
	Flags.clear_all()
	var dear := Skill.new()
	dear.id = &"skill/fixture_dear"
	dear.name_key = "fixture.dear"
	dear.power = 99.0
	dear.cost_pool = &"mp"
	dear.cost = 9
	dear.scope = Skill.Scope.ALL
	var spell := BattleCommand.new()
	spell.kind = BattleCommand.Kind.SKILL
	spell.skill = dear
	var run_away := BattleCommand.new()
	run_away.kind = BattleCommand.Kind.FLEE
	var hero := _hero()
	hero.commands = [spell, run_away]
	var battle := BattleSetup.build(_encounter(), [hero], _holder, _seeded())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	equal("a definition's own commands make the menu", screen.row_texts().has(tr("fixture.dear")), true)
	_press(screen, tr("fixture.dear"))
	equal("an unaffordable skill is refused, and says so", screen.row_texts().has(tr(BattleScreen.REFUSED_KEY)), true)
	_press(screen, tr(BattleScreen.FLEE_KEY))
	equal("fleeing ends the battle as FLED", screen.row_texts().has(tr(BattleScreen.FLED_KEY)), true)
	_stack.close_top()


func _the_host_refuses() -> void:
	var host := BattleHost.new()
	attach(host)
	equal("the host refuses an encounter that does not exist", host.open_encounter(&"encounter/fixture_missing"), false)
	host.free()
	equal("a roster path with no file is no party, not an error", BattleHost.roster_from("res://fixture/missing_roster.tres").size(), 0)
	var directory: String = RunScratch.path("roster")
	DirAccess.make_dir_recursive_absolute(directory)
	var written := PartyRoster.new()
	written.members = [_hero()]
	ResourceSaver.save(written, directory.path_join("fixture_roster.tres"))
	var read: Array[CombatantDef] = BattleHost.roster_from(directory.path_join("fixture_roster.tres"))
	equal("a roster file's members are read", read.size() == 1 and read[0].combatant_id == &"fixture_hero", true)
	# C2.12: the area's music is found under the root, so it can come back after a fight. The
	# tree here is built by hand and never enters the scene, so no area really loads.
	var root := Node.new()
	var world := Node.new()
	root.add_child(world)
	equal("with no area loaded there is no music to restore", BattleHost.area_music(root), null)
	var area := AreaRoot.new()
	area.music = AudioStreamGenerator.new()
	world.add_child(area)
	equal("the loaded area's music is found a level down", BattleHost.area_music(root), area.music)
	root.free()
