extends TestCase
## ATB time in a turn battle (C10.30): nobody acts until a gauge fills in real time; the faster foe
## acts first; a member's turn waits for the player; with wait mode on the clock stops while the
## member's menu is open, and with it off the foe's gauge keeps filling.
##
## OWNS: assertions about `AtbClock` and `Encounter.TurnOrder.ATB`.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

var _stack: UiRoot
var _holder: Node
var _acted: Array[StringName] = []


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	if Settings.default_of(CombatSettings.WAIT_MODE) == null:
		Settings.game.add(CombatSettings.WAIT_MODE, false)
	var wait_before: bool = Settings.get_bool(CombatSettings.WAIT_MODE)
	Settings.set_value(CombatSettings.WAIT_MODE, true)
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	Events.battle_acted.connect(_on_acted)
	var battle: Battle = _battle()
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	var clock: AtbClock = _clock(screen)
	var opening: Array = [battle.current(), _acted.size()]
	_steps(clock, 1.4)
	equal("nobody acts at once; after a second of time the faster foe has acted, and nobody waits",
		opening + [_acted.has(battle.enemies[0].combatant_id), battle.current()], [null, 0, true, null])
	_steps(clock, 0.65)
	equal("then the member's gauge fills and its turn waits for the player", battle.current(), battle.party[0])
	var before: int = _acted.size()
	_steps(clock, 3.0)
	equal("with wait mode on, the clock stops while the menu is open", _acted.size(), before)
	Settings.set_value(CombatSettings.WAIT_MODE, false)
	var queue: CtbScheduler = battle.scheduler as CtbScheduler
	var waiting: float = queue.wait_of(battle.enemies[0].combatant_id)
	_steps(clock, 0.5)
	equal("with it off, the foe's gauge keeps filling", queue.wait_of(battle.enemies[0].combatant_id) < waiting, true)
	Settings.set_value(CombatSettings.WAIT_MODE, wait_before)
	Events.battle_acted.disconnect(_on_acted)
	_stack.close_all()
	_holder.free()
	_stack.free()
	Flags.clear_all()


func _battle() -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_atb"
	encounter.turn_order = Encounter.TurnOrder.ATB
	var foe := _def(&"fixture_atb_foe", &"side_b", 1.5)
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	return BattleSetup.build(encounter, [_def(&"fixture_atb_hero", &"side_a", 1.0)], _holder, RandomNumberGenerator.new())


func _clock(screen: BattleScreen) -> AtbClock:
	for child: Node in screen.get_children():
		if child is AtbClock:
			return child as AtbClock
	return null


func _steps(clock: AtbClock, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		clock.step(0.05)
		left -= 0.05


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 400.0, &"speed": speed, &"attack": 3.0}
	return def


func _on_acted(who: StringName, _kind: int, _key: String) -> void:
	_acted.append(who)
