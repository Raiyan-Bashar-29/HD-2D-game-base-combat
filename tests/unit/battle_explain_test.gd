extends TestCase
## The battle menu explains a skill and the log says who acted with what (C10.5): a skill's
## description, hits and reach sit over its target list; a fallen fighter is marked in a list;
## the log reads "Hero attacks." and "Hero uses Spark." above the damage they do.
##
## OWNS: assertions about `BattleMenu.explain`, `target_text`, `Skill.desc_key` and the
## `battle_acted` line.
## MUST NOT: name a game's skills or fighters. Every name here is made up for the case.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	_the_menu_and_the_log()
	_stack.close_all()
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


func _spark() -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	command.skill.id = &"skill/fixture_flurry"
	command.skill.name_key = "fixture.flurry"
	command.skill.desc_key = "fixture.flurry.desc"
	command.skill.power = 2.0
	command.skill.hits = 3
	return command


func _the_menu_and_the_log() -> void:
	var hero := _def(&"fixture_hero", &"side_a", {&"max_hp": 50.0, &"speed": 9.0, &"attack": 20.0})
	var attack := BattleCommand.new()
	hero.commands = [attack, _spark()]
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_explain"
	var foe := _def(&"fixture_foe", &"side_b", {&"max_hp": 500.0, &"speed": 1.0, &"attack": 1.0})
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	var about: String = BattleMenu.explain(hero.commands[1])
	equal("a skill's description, hits and reach make one line", about, "   ".join(PackedStringArray([
		tr("fixture.flurry.desc"), tr(BattleMenu.HITS_KEY).format({"hits": 3}), tr(BattleMenu.REACH_PREFIX + "enemy")])))
	_press(screen, tr("fixture.flurry"))
	equal("choosing it shows the line over its target list", screen.row_texts().has(about), true)
	var one: Combatant = battle.enemies[0]
	Vitals.of(one.get_parent()).change(&"hp", -9999)
	equal("a fallen fighter is marked in a target list", BattleMenu.target_text(one, "x"),
		tr(BattleMenu.FALLEN_KEY).format({"name": "x"}))
	Vitals.of(one.get_parent()).revive(500)
	screen.battle_log.lines.clear()
	battle.act(hero.commands[1], [one])
	var lines: Array[String] = screen.battle_log.lines.duplicate()
	var uses: String = tr(BattleLog.USES_KEY).format({"name": screen.name_of(battle.party[0]), "what": tr("fixture.flurry")})
	equal("the log says who used what, above the damage it did",
		[lines.find(uses) == 0, lines.size() > 1], [true, true])
	var plain := BattleLog.new(battle, screen.name_of)
	plain.start()
	Events.battle_acted.emit(battle.party[0].combatant_id, BattleCommand.Kind.ATTACK, "")
	Events.battle_acted.emit(battle.party[0].combatant_id, BattleCommand.Kind.DEFEND, "")
	plain.stop()
	equal("a plain attack reads as one, and a guard adds nothing",
		plain.lines, [tr(BattleLog.ATTACKS_KEY).format({"name": screen.name_of(battle.party[0])})] as Array[String])


func _press(screen: BattleScreen, text: String) -> bool:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			button.pressed.emit()
			return true
	return false
