extends TestCase
## The loadout from the battle menu (C10.29): the player's turn offers a Loadout row; pressing it
## opens the member's loadout over the battle for that battle fighter; closing it returns to the
## same turn, nothing spent; the loadout action has a pad button.
##
## OWNS: assertions about `BattleScreen`'s Loadout row and `CombatActions.LOADOUT`'s defaults.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_bload"
	var foe := _def(&"fixture_bload_foe", &"side_b", 1.0)
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var battle: Battle = BattleSetup.build(encounter, [_def(&"fixture_bload_hero", &"side_a", 9.0)], _holder, RandomNumberGenerator.new())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	var turn: Combatant = battle.current()
	var pressed: bool = _press(screen, tr(BattleScreen.LOADOUT_KEY))
	var opened: LoadoutScreen = _stack.top() as LoadoutScreen
	equal("the player's turn offers a Loadout row that opens the member's loadout over the battle",
		[pressed, opened != null, opened.bodies == [turn.get_parent()] if opened != null else false], [true, true, true])
	_stack.close_top()
	equal("closing it returns to the same turn, nothing spent", [_stack.top() == screen, battle.current() == turn], [true, true])
	var pad: bool = InputMap.action_get_events(CombatActions.LOADOUT).any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton)
	equal("the loadout action has a pad button", pad, true)
	_stack.close_all()
	_holder.free()
	_stack.free()
	Flags.clear_all()


func _press(screen: MenuScreen, text: String) -> bool:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text:
			button.pressed.emit()
			return true
	return false


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"speed": speed, &"attack": 3.0}
	return def
