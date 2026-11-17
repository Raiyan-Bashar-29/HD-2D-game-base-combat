extends TestCase
## Auto-battle (C5.4b). Off, a party member has no brain and waits for the player. The screen's
## Auto row turns it on: each party member of its own is then played by its definition's brain,
## or a plain one that attacks; a guest is not touched. The screen stops at that turn and
## `tick_auto` plays it once `AUTO_DELAY` has passed, so a whole fight plays itself to the end.
##
## OWNS: assertions about `AutoBattle`, `Battle.brain_of` under it, and the screen's Auto row.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

const HERO: StringName = &"fixture_auto_hero"
const FOE: StringName = &"fixture_auto_foe"


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var stack := UiRoot.new()
	attach(stack)
	var battle: Battle = BattleSetup.build(_encounter(), [_def(HERO, &"side_a", 9.0)], holder,
			RandomNumberGenerator.new())
	battle.start()
	var hero: Combatant = battle.party[0]
	equal("off, a party member has no brain", [AutoBattle.on(), battle.brain_of(hero)], [false, null])
	var screen := BattleScreen.for_battle(battle)
	stack.open(screen)
	var pressed: bool = _press(screen, tr(BattleScreen.AUTO_OFF_KEY))
	equal("the Auto row turns it on and says so",
		[pressed, AutoBattle.on(), screen.row_texts().has(tr(BattleScreen.AUTO_ON_KEY))], [true, true, true])
	equal("on, the party member is played by a plain brain", battle.brain_of(hero) != null, true)
	var first: bool = screen.tick_auto(BattleScreen.AUTO_DELAY * 0.5)
	var foe_hp: int = Vitals.of(battle.enemies[0].get_parent()).current(&"hp")
	var played: bool = screen.tick_auto(BattleScreen.AUTO_DELAY)
	equal("its turn waits for the delay, then plays an attack",
		[first, played, Vitals.of(battle.enemies[0].get_parent()).current(&"hp") < foe_hp], [false, true, true])
	for i: int in 50:
		if battle.outcome() != Battle.Outcome.ONGOING:
			break
		screen.tick_auto(BattleScreen.AUTO_DELAY)
	equal("the fight plays itself to the end", battle.outcome(), Battle.Outcome.WON)
	AutoBattle.toggle()
	equal("off again, the party member waits for the player", battle.brain_of(hero), null)
	stack.close_all()
	Battle.running = null
	holder.free()
	stack.free()
	Flags.clear_all()


func _press(screen: BattleScreen, text: String) -> bool:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text:
			button.pressed.emit()
			return true
	return false


func _encounter() -> Encounter:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_auto"
	var foe: CombatantDef = _def(FOE, &"side_b", 1.0)
	foe.base_stats[&"max_hp"] = 30.0
	foe.base_stats[&"attack"] = 1.0
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	return encounter


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 60.0, &"attack": 12.0, &"speed": speed}
	def.level_curve = LevelCurve.new()
	return def
