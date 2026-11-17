extends TestCase
## The combat settings (C5.3b): installed into upstream's `Settings.game`, drawn on the settings
## screen, and each read where it acts: the difficulty, auto-battle, wait mode and lock-on assist.
##
## THE HEADLINE IS THE FLAG RULE. A save's own `combat/difficulty` or `combat/auto_battle` flag
## wins until the player changes the matching setting, and then it is dropped so the change counts.
##
## THE CASE NEVER TOUCHES THE REAL LIST, as upstream's `game_settings_test` does not: it swaps a
## fresh `GameSettings` into `Settings.game` and puts the old one back. The difficulties are fixture
## files in the run's scratch folder, so the case passes with the demo's deleted.
##
## OWNS: assertions about `CombatSettings` and the four readers' use of it.
## MUST NOT: name a demo difficulty.

const EASY: StringName = &"difficulty/fixture_settings_easy"
const EASY_NAME: String = "combat.difficulty.fixture_settings_easy.name"

var _real: GameSettings = null
var _stack: UiRoot = null
var _actors: Array[Node] = []


func run() -> void:
	plan(30)
	SaveFixture.activate()
	Flags.clear_all()
	_real = Settings.game
	Settings.game = GameSettings.new(Settings.DEFAULTS)
	Settings.reset_to_defaults()
	_fixture_difficulty()
	equal("before install every combat setting reads as off",
		[CombatSettings.is_on(CombatSettings.AUTO_BATTLE), CombatSettings.difficulty("kept")], [false, "kept"])
	CombatSettings.install()
	_they_are_added()
	_the_difficulty()
	_auto_battle()
	_wait_mode()
	_lock_on_assist()
	_hold_to_attack()
	_the_screen()
	_tear_down()


func _fixture_difficulty() -> void:
	var easy := Difficulty.new()
	easy.id = EASY
	easy.name_key = EASY_NAME
	easy.dealt = 0.5
	var directory: String = RunScratch.path("settings_difficulty")
	DirAccess.make_dir_recursive_absolute(directory)
	ResourceSaver.save(easy, directory.path_join("fixture_settings_easy.tres"))
	DifficultyDb.content_dir = directory
	DifficultyDb.rescan()


func _they_are_added() -> void:
	var every: Array[String] = Settings.game.every()
	equal("the four are added under their own section, after the built-ins", every.slice(every.size() - 4),
		[CombatSettings.DIFFICULTY, CombatSettings.AUTO_BATTLE, CombatSettings.WAIT_MODE, CombatSettings.LOCK_ON_ASSIST])
	equal("the difficulty's choices are none and every file", Settings.game.choices_of(CombatSettings.DIFFICULTY),
		["", String(EASY)])
	equal("each named by its own key", Settings.game.labels_of(CombatSettings.DIFFICULTY),
		[CombatSettings.NONE_KEY, EASY_NAME])
	# The project's default difficulty is a demo file, not one of the fixture's, so it falls to none.
	var fallback: String = str(ProjectSettings.get_setting(CombatDifficulty.SETTING, ""))
	var difficulty: String = fallback if Settings.game.choices_of(CombatSettings.DIFFICULTY).has(fallback) else ""
	equal("the defaults: the project's difficulty if it is a choice, auto-battle off, wait mode as the project",
		[Settings.get_string(CombatSettings.DIFFICULTY), Settings.get_bool(CombatSettings.AUTO_BATTLE),
			Settings.get_bool(CombatSettings.WAIT_MODE), Settings.get_bool(CombatSettings.LOCK_ON_ASSIST)],
		[difficulty, false, is_zero_approx(_project_slow()), false])
	equal("hold to attack joins the built-in Accessibility section, at its end (C5.3d)",
		every.find(CombatSettings.HOLD_TO_ATTACK), every.find("accessibility/hold_to_confirm") + 1)
	CombatSettings.install()
	equal("installing again adds nothing", Settings.game.every().size(), every.size())


func _the_difficulty() -> void:
	Settings.set_value(CombatSettings.DIFFICULTY, "")
	equal("with none chosen there is none", CombatDifficulty.current(), null)
	Settings.set_value(CombatSettings.DIFFICULTY, String(EASY))
	equal("the setting turns one on", CombatDifficulty.current(), DifficultyDb.of(EASY))
	CombatDifficulty.choose(&"")
	equal("a save's own flag wins", CombatDifficulty.current(), null)
	Settings.set_value(CombatSettings.DIFFICULTY, String(EASY))
	equal("until the player changes the setting, which drops the flag",
		[Flags.has_flag(CombatDifficulty.FLAG), CombatDifficulty.current()], [false, DifficultyDb.of(EASY)])


func _auto_battle() -> void:
	equal("auto-battle is off by default", AutoBattle.on(), false)
	Settings.set_value(CombatSettings.AUTO_BATTLE, true)
	equal("the setting turns it on", AutoBattle.on(), true)
	equal("the battle's Auto row turns it off for this save", [AutoBattle.toggle(), AutoBattle.on()], [false, false])
	Settings.set_value(CombatSettings.AUTO_BATTLE, true)
	equal("changing the setting drops the save's flag", [Flags.has_flag(AutoBattle.FLAG), AutoBattle.on()],
		[false, true])
	Settings.set_value(CombatSettings.AUTO_BATTLE, false)


func _wait_mode() -> void:
	Settings.set_value(CombatSettings.WAIT_MODE, false)
	var expected: float = _project_slow() if _project_slow() > 0.0 else CommandOverlay.SLOW_DEFAULT
	equal("off, the command menu slows the fight as the project says", CommandOverlay.slow(), expected)
	Settings.set_value(CombatSettings.WAIT_MODE, true)
	equal("on, it stops it", CommandOverlay.slow(), 0.0)
	Settings.set_value(CombatSettings.WAIT_MODE, false)


func _lock_on_assist() -> void:
	var me := _actor(&"fixture_set_me", &"side_a", Vector3.ZERO)
	var lock := LockOn.new()
	me.add_child(lock)
	var first := _actor(&"fixture_set_first", &"side_b", Vector3(0, 0, -3))
	var second := _actor(&"fixture_set_second", &"side_b", Vector3(0, 0, -6))
	var third := _actor(&"fixture_set_third", &"side_b", Vector3(0, 0, -8))
	_actor(&"fixture_set_behind", &"side_b", Vector3(0, 0, 9))
	lock.toggle(Vector3.FORWARD)
	Vitals.of(first).change(&"hp", -10)
	lock.refresh()
	equal("with assist off, a target that falls is let go", lock.target, null)
	Settings.set_value(CombatSettings.LOCK_ON_ASSIST, true)
	lock.toggle(Vector3.FORWARD)
	equal("the next lock is the nearest standing one", _id(lock), &"fixture_set_second")
	Vitals.of(second).change(&"hp", -10)
	lock.refresh()
	equal("with assist on, it moves to the nearest other in reach", _id(lock), &"fixture_set_third")
	third.position = Vector3(0, 0, -20)
	lock.refresh()
	equal("but one that only went out of reach is let go", lock.target, null)
	Settings.set_value(CombatSettings.LOCK_ON_ASSIST, false)


## C5.3d: the same flag rule as auto-battle, read by `ActionFighter` through `flag_or_setting`.
func _hold_to_attack() -> void:
	var on: Callable = func() -> bool:
		return CombatSettings.flag_or_setting(ActionFighter.HOLD_FLAG, CombatSettings.HOLD_TO_ATTACK)
	equal("hold to attack is off by default", on.call(), false)
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, true)
	equal("the setting turns it on", on.call(), true)
	Flags.set_flag(ActionFighter.HOLD_FLAG, false)
	equal("a save's own flag wins", on.call(), false)
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, true)
	equal("until the setting changes, which drops it", [Flags.has_flag(ActionFighter.HOLD_FLAG), on.call()],
		[false, true])
	Settings.set_value(CombatSettings.HOLD_TO_ATTACK, false)


func _the_screen() -> void:
	_stack = UiRoot.new()
	attach(_stack)
	var screen := SettingsScreen.new()
	equal("the settings screen opens", _stack.open(screen), true)
	var rows: Array[String] = screen.row_texts()
	equal("with a Combat heading", rows.has(tr("%scombat" % SettingsScreen.SECTION_PREFIX)), true)
	Settings.set_value(CombatSettings.DIFFICULTY, "")
	equal("the difficulty reads None", screen.value_text(CombatSettings.DIFFICULTY), tr(CombatSettings.NONE_KEY))
	screen.step(CombatSettings.DIFFICULTY, 1)
	equal("a press picks the next difficulty, by its own name",
		[Settings.get_string(CombatSettings.DIFFICULTY), screen.value_text(CombatSettings.DIFFICULTY)],
		[String(EASY), tr(EASY_NAME)])
	equal("cleanup", _stack.close_top(), true)


func _project_slow() -> float:
	var slow: float = ProjectSettings.get_setting(CombatSettings.SLOW_SETTING, CommandOverlay.SLOW_DEFAULT)
	return maxf(0.0, slow)


func _actor(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 10.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _id(lock: LockOn) -> StringName:
	return lock.target.fighter().combatant_id if lock.target != null else &""


func _tear_down() -> void:
	if _stack != null:
		_stack.close_all()
		_stack = null
	get_tree().paused = false
	for actor: Node in _actors:
		actor.free()
	Settings.game = _real
	Settings.reset_to_defaults()
	Flags.clear_all()
	DifficultyDb.content_dir = DifficultyDb.DIFFICULTY_DIR
	DifficultyDb.rescan()
