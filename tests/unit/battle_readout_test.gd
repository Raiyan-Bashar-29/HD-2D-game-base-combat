extends TestCase
## The battle readout (C2.19): each fighter's line shows its other pools, its shield, its
## statuses by name and only the weaknesses already revealed, and a short battle log turns the
## bus's combat signals into lines a player reads, keeping only the newest few.
##
## OWNS: assertions about what the battle screen tells the player about the fight.
## MUST NOT: name a game's skills, statuses or fighters. Every name here is made up.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	var screen: BattleScreen = _open_screen()
	_fighter_lines(screen)
	_the_log(screen)
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


func _open_screen() -> BattleScreen:
	var hero := _def(&"fixture_hero", &"side_a", {&"max_hp": 40.0, &"speed": 9.0, &"max_mp": 12.0})
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_readout"
	var foe := _def(&"fixture_foe", &"side_b", {&"max_hp": 30.0, &"speed": 1.0, &"max_shield": 2.0})
	foe.weak_to = [&"fixture_fire", &"fixture_ice"]
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	return screen


## The note line that starts with `name`, or "".
func _line_of(screen: BattleScreen, name: String) -> String:
	for text: String in screen.row_texts():
		if text.begins_with(name):
			return text
	return ""


func _fighter_lines(screen: BattleScreen) -> void:
	var hero: Combatant = screen.battle.party[0]
	var foe: Combatant = screen.battle.enemies[0]
	var dazed := StatusEffect.new()
	dazed.id = &"status/fixture_dazed"
	dazed.name_key = "fixture.status.dazed"
	StatusSet.of(foe.get_parent()).apply(dazed)
	equal("held() lists what a fighter carries", StatusSet.of(foe.get_parent()).held(), [dazed])
	Weakness.strike(foe, [&"fixture_fire"])
	screen.refresh()
	var line: String = _line_of(screen, screen.name_of(foe))
	equal("a fighter's line names its statuses", line.contains(tr("fixture.status.dazed")), true)
	equal("and shows its shield", line.contains(tr(BattleScreen.POOL_KEY).format(
		{"pool": "SHIELD", "current": 1, "max": 2})), true)
	equal("and the weaknesses already revealed", line.contains("fixture_fire"), true)
	equal("but not the ones still hidden", line.contains("fixture_ice"), false)
	equal("a hero's line shows its other pools, such as MP",
		_line_of(screen, screen.name_of(hero)).contains(tr(BattleScreen.POOL_KEY).format(
			{"pool": "MP", "current": 12, "max": 12})), true)


func _the_log(screen: BattleScreen) -> void:
	var journal: BattleLog = screen.battle_log
	var foe_name: String = screen.name_of(screen.battle.enemies[0])
	Events.combatant_damaged.emit(&"fixture_foe", &"fixture_hero", 7, false)
	equal("damage becomes a line", journal.lines.back(), tr(BattleLog.DAMAGE_KEY).format({"name": foe_name, "amount": 7}))
	Events.attack_missed.emit(&"fixture_foe", &"fixture_hero")
	equal("a miss becomes a line", journal.lines.back(), tr(BattleLog.MISSED_KEY).format({"name": foe_name}))
	Events.combatant_broken.emit(&"fixture_foe")
	equal("a break becomes a line", journal.lines.back(), tr(BattleLog.BROKEN_KEY).format({"name": foe_name}))
	Events.turn_skipped.emit(&"fixture_foe", &"status/fixture_dazed")
	equal("a lost turn names the status", journal.lines.back(), tr(BattleLog.SKIPPED_KEY).format(
		{"name": foe_name, "status": tr("fixture.status.dazed")}))
	for i: int in 10:
		Events.attack_missed.emit(&"fixture_foe", &"fixture_hero")
	equal("only the newest lines are kept", journal.lines.size(), BattleLog.MAX_LINES)
	screen.refresh()
	equal("and the screen shows them", screen.row_texts().has(journal.lines.back()), true)
	_stack.close_top()
	journal.lines.clear()
	Events.attack_missed.emit(&"fixture_foe", &"fixture_hero")
	equal("a closed screen's log stops listening", journal.lines.size(), 0)
