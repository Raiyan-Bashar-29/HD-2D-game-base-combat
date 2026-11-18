extends TestCase
## The hybrid's command menu (C4.4): the command key opens it over the running world for a
## fighter with an ATB gauge and nobody else; it slows the fight to the setting while open and
## restores it when closed; its rows come in the battle menu's categories, greyed out with the
## reason while they cannot be used and usable again once a bar fills; choosing one uses it and
## asks to close; and each refusal reason has the words a player reads. A one-target command with
## more than one fighter it could land on asks which, nearest first, and Back spends nothing
## (C10.1): an ally's heal reaches the ally, not only the user.
##
## OWNS: assertions about `CommandOverlay` and `CommandHost`.
## MUST NOT: name a game's skills or fighters, or wait for frames.

const CATEGORY: String = "fixture.category.field"

var _stack: UiRoot
var _host: CommandHost
var _player: PlayerController
var _other: PlayerController
var _foe: Node3D
var _second: Node3D
var _ally: Node3D


func run() -> void:
	plan(17)
	_set_up()
	_opening()
	_rows()
	_choosing()
	_refusing()
	_picking()
	_tear_down()


func _set_up() -> void:
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	CombatClock.reset()
	_stack = UiRoot.new()
	attach(_stack)
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	var loadout := _loadout(true)
	ActionHost.equip(_player, loadout)
	_other = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_other)
	_other.global_position = Vector3(0, 0, 60)
	ActionHost.equip(_other, _loadout(false))
	_foe = _make_foe(&"fixture_target", &"enemy", Vector3(0, 0, -2))
	_host = CommandHost.new()
	_host.loadout = loadout
	attach(_host)


func _tear_down() -> void:
	_stack.close_all()
	CombatClock.reset()
	_host.free()
	_stack.free()
	_player.free()
	_other.free()
	_foe.free()
	_second.free()
	_ally.free()
	Flags.clear_all()


func _opening() -> void:
	equal("the host will not open for a fighter with no ATB gauge", _host.can_open(_other), false)
	var opened: bool = _host.toggle(_stack, _player)
	var top: UiScreen = _stack.top()
	equal("the command key opens the menu over the running world",
		[opened, top.screen_id if top != null else &"", top.pauses_world if top != null else true],
		[true, CommandOverlay.SCREEN_ID, false])
	equal("the fight slows to the setting while it is open", [CombatClock.scale, CommandOverlay.slow()], [0.1, 0.1])


func _rows() -> void:
	var screen: CommandOverlay = _stack.top() as CommandOverlay
	equal("the first menu shows the gauge, the category and the loose command",
		[screen.row_texts()[0], screen.row_texts().has(tr(CATEGORY)), _row(screen, "fixture.field_mend") != null],
		[CombatHud.atb_text(AtbMeter.of(_player).gauge), true, true])
	var mend: Button = _row(screen, "fixture.field_mend")
	equal("with an empty gauge, a row is greyed out with the reason",
		[mend.disabled, mend.text.contains(tr(CommandOverlay.ATB_REASON_KEY))], [true, true])
	_row(screen, CATEGORY).pressed.emit()
	equal("a category opens its commands, with a way back",
		[_row(screen, "fixture.field_bolt") != null, screen.row_texts().has(tr(CommandOverlay.BACK_KEY))], [true, true])
	AtbMeter.of(_player).gauge.gain(100.0)
	Events.atb_changed.emit(Combatant.of(_player).combatant_id, 100.0, 1)
	equal("a bar filling makes the row usable", _row(screen, "fixture.field_bolt").disabled, false)


func _choosing() -> void:
	var screen: CommandOverlay = _stack.top() as CommandOverlay
	var asked: Array[bool] = [false]
	screen.close_requested.connect(func() -> void: asked[0] = true)
	var gauge: AtbGauge = AtbMeter.of(_player).gauge
	_row(screen, "fixture.field_bolt").pressed.emit()
	# The bar is spent, then the bolt landing earns the hit reward, as any landed hit does.
	equal("choosing a usable row uses it, spends the bar and asks to close",
		[Vitals.of(_foe).current(&"hp") < 50, gauge.value, asked[0]], [true, gauge.rules.on_hit_dealt, true])
	_stack.close_top()
	equal("closing puts the fight back to full speed", CombatClock.scale, 1.0)
	_host.toggle(_stack, _player)
	equal("a second press of the command key closes the menu", [_host.toggle(_stack, _player), _stack.depth()], [true, 0])


func _refusing() -> void:
	var other := UiScreen.new()
	other.screen_id = &"fixture_other"
	_stack.open(other)
	equal("the host will not open over another screen", [_host.toggle(_stack, _player), _stack.top().screen_id],
		[false, &"fixture_other"])
	_stack.close_all()
	var keys: Array[String] = []
	for reason: FieldCommands.Reason in [FieldCommands.Reason.NONE, FieldCommands.Reason.ATB,
			FieldCommands.Reason.BLOCKED, FieldCommands.Reason.COST, FieldCommands.Reason.ITEM, FieldCommands.Reason.TARGET]:
		keys.append(CommandOverlay.reason_key(reason))
	equal("every refusal has the words a player reads", keys, ["", CommandOverlay.ATB_REASON_KEY,
		BattleMenu.BLOCKED_REASON_KEY, BattleMenu.COST_REASON_KEY, BattleMenu.ITEM_REASON_KEY, BattleMenu.TARGET_REASON_KEY])


func _picking() -> void:
	_second = _make_foe(&"fixture_second", &"enemy", Vector3(0, 0, -5))
	_ally = _make_foe(&"fixture_ally", &"player", Vector3(1, 0, 0))
	var near: Combatant = Combatant.of(_foe)
	var far: Combatant = Combatant.of(_second)
	var gauge: AtbGauge = AtbMeter.of(_player).gauge
	gauge.gain(300.0)
	_host.toggle(_stack, _player)
	var screen: CommandOverlay = _stack.top() as CommandOverlay
	var asked: Array[bool] = [false]
	screen.close_requested.connect(func() -> void: asked[0] = true)
	_row(screen, CATEGORY).pressed.emit()
	var bars: float = gauge.value
	var hp: int = Vitals.of(_foe).current(&"hp")
	_row(screen, "fixture.field_bolt").pressed.emit()
	var texts: Array[String] = screen.row_texts()
	equal("two foes in reach: the bolt asks which, nearest first, with a way back",
		[texts.find(screen.target_text(near)) < texts.find(screen.target_text(far)),
		texts.find(screen.target_text(near)) >= 0, texts.has(tr(CommandOverlay.BACK_KEY))], [true, true, true])
	equal("asking spends nothing and keeps the menu up", [gauge.value, asked[0]], [bars, false])
	_row(screen, CommandOverlay.BACK_KEY).pressed.emit()
	equal("Back returns to the commands, nothing spent", [_row(screen, "fixture.field_bolt") != null,
		gauge.value, Vitals.of(_foe).current(&"hp")], [true, bars, hp])
	_row(screen, "fixture.field_bolt").pressed.emit()
	_row(screen, screen.target_text(far)).pressed.emit()
	equal("picking the far foe strikes it alone and asks to close",
		[Vitals.of(_second).current(&"hp") < 50, Vitals.of(_foe).current(&"hp"), asked[0]], [true, hp, true])
	_stack.close_all()
	Vitals.of(_ally).change(&"hp", -20)
	_host.toggle(_stack, _player)
	screen = _stack.top() as CommandOverlay
	var mine: int = Vitals.of(_player).current(&"hp")
	_row(screen, "fixture.field_salve").pressed.emit()
	_row(screen, screen.target_text(Combatant.of(_ally))).pressed.emit()
	equal("an ally's heal reaches the ally picked, not the user", [Vitals.of(_ally).current(&"hp") > 30,
		Vitals.of(_player).current(&"hp")], [true, mine])
	_stack.close_all()


## The first row whose text starts with `prefix` translated, or null.
func _row(screen: CommandOverlay, prefix: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(tr(prefix)):
			return button
	return null


func _loadout(with_atb: bool) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero" if with_atb else &"fixture_plain"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0, &"attack": 5.0}
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [ActionMove.new()]
	if with_atb:
		made.atb = AtbRules.new()
	var bolt := _command("fixture.field_bolt", FactionTable.Target.ENEMY, 4.0)
	bolt.category = CATEGORY
	made.commands = [_command("fixture.field_mend", FactionTable.Target.SELF, -4.0), bolt,
		_command("fixture.field_salve", FactionTable.Target.ALLY, -6.0)]
	return made


func _command(name_key: String, target: FactionTable.Target, power: float) -> BattleCommand:
	var skill := Skill.new()
	skill.id = StringName("skill/" + name_key)
	skill.name_key = name_key
	skill.target = target
	skill.power = power
	skill.cost_pool = &"mp"
	skill.sure_hit = true
	var made := BattleCommand.new()
	made.kind = BattleCommand.Kind.SKILL
	made.skill = skill
	return made


func _make_foe(id: StringName, faction: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = faction
	combatant.base_stats = {&"max_hp": 50.0, &"defence": 1.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
