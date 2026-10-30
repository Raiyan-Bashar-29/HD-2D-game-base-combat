extends TestCase
## The battle menu with depth (C2.18), driven through `BattleScreen`: commands grouped into
## categories that open a submenu, costs on every row, a row that cannot be used greyed out
## with its reason, a stance that reads On or Off, and a Boost selector whose level the next
## action spends.
##
## OWNS: assertions about what the battle menu offers and how it reads.
## MUST NOT: name a game's skills, fighters or encounters. Every name here is made up.

var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(15)
	SaveFixture.activate()
	Flags.clear_all()
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	var screen: BattleScreen = _open_screen()
	_categories_and_costs(screen)
	_stance_and_boost(screen)
	_greyed_by_rules(screen)
	_stack.close_top()
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


func _skill(name: String, cost: int) -> Skill:
	var made := Skill.new()
	made.id = StringName("skill/" + name)
	made.name_key = "fixture." + name
	made.power = 2.0
	made.cost_pool = &"mp"
	made.cost = cost
	return made


func _command(kind: BattleCommand.Kind, skill: Skill = null, category: String = "") -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	command.skill = skill
	command.category = category
	return command


## The first live row whose text starts with `prefix`, or null.
func _row(screen: BattleScreen, prefix: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(prefix):
			return button
	return null


func _press(screen: BattleScreen, prefix: String) -> void:
	var button: Button = _row(screen, prefix)
	if button != null:
		button.pressed.emit()


const MAGIC: String = "fixture.category.magic"


## One fighter with a basic attack, two skills filed under MAGIC (one it can never afford), a
## stance and Flee, against one harmless foe.
func _open_screen() -> BattleScreen:
	Flags.clear_all()
	var magic: String = MAGIC
	var spark: Skill = _skill("spark", 3)
	var bolt: Skill = _skill("bolt", 99)
	var calm := StatusEffect.new()
	calm.id = &"status/fixture_calm"
	calm.duration = 0.0
	var stance: Skill = _skill("stance", 0)
	stance.power = 0.0
	stance.target = FactionTable.Target.SELF
	stance.toggle_status = calm
	var hero := _def(&"fixture_hero", &"side_a", {&"max_hp": 99.0, &"speed": 9.0, &"attack": 2.0,
		&"max_mp": 10.0, &"max_bp": 3.0})
	hero.commands = [_command(BattleCommand.Kind.ATTACK), _command(BattleCommand.Kind.SKILL, spark, magic),
		_command(BattleCommand.Kind.SKILL, bolt, magic), _command(BattleCommand.Kind.SKILL, stance),
		_command(BattleCommand.Kind.FLEE)]
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_menu"
	var foe := _def(&"fixture_foe", &"side_b", {&"max_hp": 99.0, &"speed": 1.0, &"attack": 1.0})
	foe.brain = BattleBrain.new()
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	return screen


func _categories_and_costs(screen: BattleScreen) -> void:
	var magic: String = MAGIC
	var texts: Array[String] = screen.row_texts()
	equal("a category is one row at the top level", texts.has(tr(magic)), true)
	equal("and its skills are not", _row(screen, tr("fixture.spark")) == null, true)
	_press(screen, tr(magic))
	equal("opening it lists its skills with their cost", _row(screen, tr("fixture.spark")).text,
		tr(BattleScreen.COST_KEY).format({"label": tr("fixture.spark"), "cost": 3, "pool": "MP"}))
	equal("with a way back", screen.row_texts().has(tr(BattleScreen.BACK_KEY)), true)
	var dear: Button = _row(screen, tr("fixture.bolt"))
	equal("a skill it cannot afford is greyed out", dear.disabled, true)
	equal("and says why", dear.text.contains(tr(BattleMenu.COST_REASON_KEY).format({"pool": "MP"})), true)
	_press(screen, tr(BattleScreen.BACK_KEY))
	equal("Back returns to the top level", _row(screen, tr(BattleScreen.ATTACK_KEY)) != null, true)


func _stance_and_boost(screen: BattleScreen) -> void:
	var battle: Battle = screen.battle
	equal("a stance reads Off", _row(screen, tr("fixture.stance")).text,
		tr(BattleScreen.STANCE_OFF_KEY).format({"label": tr("fixture.stance")}))
	_press(screen, tr("fixture.stance"))
	equal("and, used, reads On on the next turn", _row(screen, tr("fixture.stance")).text,
		tr(BattleScreen.STANCE_ON_KEY).format({"label": tr("fixture.stance")}))
	var boost_prefix: String = tr(BattleScreen.BOOST_KEY).get_slice("{", 0)
	equal("a fighter with Boost points has a Boost row", _row(screen, boost_prefix) != null, true)
	_press(screen, boost_prefix)
	equal("pressing it raises the level", _row(screen, boost_prefix).text,
		tr(BattleScreen.BOOST_KEY).format({"level": 1, "max": 3}))
	_press(screen, tr(BattleScreen.ATTACK_KEY))
	_press(screen, screen.name_of(battle.enemies[0]))
	equal("the next action spends the chosen level", Vitals.of(battle.party[0].get_parent()).current(&"bp"), 2)
	equal("and the selector starts again at zero", _row(screen, boost_prefix).text,
		tr(BattleScreen.BOOST_KEY).format({"level": 0, "max": 3}))


func _greyed_by_rules(screen: BattleScreen) -> void:
	var battle: Battle = screen.battle
	var hush := StatusEffect.new()
	hush.id = &"status/fixture_hush"
	hush.blocks = [StatusEffect.Block.NO_SKILLS]
	StatusSet.of(battle.party[0].get_parent()).apply(hush)
	battle.can_flee = false
	screen.refresh()
	equal("a status that forbids skills greys them out", _row(screen, tr("fixture.stance")).disabled, true)
	equal("and a battle with no escape greys out Flee", _row(screen, tr(BattleScreen.FLEE_KEY)).disabled, true)
