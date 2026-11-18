extends TestCase
## Bars and pop-ups on the battle screen (C10.23): each fighter's line has a bar for its damage
## pool that a redraw brings up to date; a hit floats its amount beside the fighter's line, and the
## amount goes after its life.
##
## OWNS: assertions about `BattleReadout.bar` and `BattlePopups`.
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
	encounter.id = &"encounter/fixture_bars"
	encounter.enemies = [_def(&"fixture_bars_foe", &"side_b", 1.0)]
	var battle: Battle = BattleSetup.build(encounter, [_def(&"fixture_bars_hero", &"side_a", 9.0)], _holder, RandomNumberGenerator.new())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	var foe: Combatant = battle.enemies[0]
	Vitals.of(foe.get_parent()).change(&"hp", -10)
	screen.refresh()
	equal("each fighter's line has a bar for its damage pool, brought up to date by a redraw",
		_bars(screen), [[40.0, 40.0], [30.0, 40.0]])
	var popups: BattlePopups = null
	for child: Node in screen.get_children():
		if child is BattlePopups:
			popups = child as BattlePopups
	Events.combatant_damaged.emit(foe.combatant_id, battle.party[0].combatant_id, 7, false)
	var pop: Label = popups.shown.keys()[0] if popups != null and not popups.shown.is_empty() else null
	equal("a hit floats its amount on the screen", pop.text if pop != null else "", tr(BattlePopups.AMOUNT_KEY).format({"amount": 7}))
	popups._process(BattlePopups.LIFE + 0.1)
	equal("and the amount goes after its life", [pop.is_queued_for_deletion(), popups.shown.size()], [true, 0])
	_stack.close_all()
	_holder.free()
	_stack.free()
	Flags.clear_all()


func _bars(screen: BattleScreen) -> Array:
	var out: Array = []
	for child: Node in screen.rows.get_children():
		var bar: ProgressBar = child as ProgressBar
		if bar != null and not bar.is_queued_for_deletion():
			out.append([bar.value, bar.max_value])
	return out


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"speed": speed, &"attack": 3.0}
	return def
