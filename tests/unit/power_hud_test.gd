extends TestCase
## Live cooldowns (C6.3b): a `PowerSet` says when the whole seconds or turns left on a power
## change, and only then; the HUD's slot line shows each quick slot's key, name and cost, and
## "ready in Ns" while it cools, redrawn by that signal alone; and the command menu draws its rows
## again when a power comes off cooldown, so the greyed row can be picked.
##
## OWNS: assertions about `Events.power_cooldown_changed`, `CombatHud.slot_text` and the
## `CommandOverlay`'s redraw on it.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const BOLT: StringName = &"power/fixture_hud_bolt"

var _player: PlayerController
var _foe: Node3D
var _heard: Array = []


func run() -> void:
	plan(14)
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout())
	_foe = _enemy()
	Events.power_cooldown_changed.connect(_on_heard)
	_the_signal()
	_the_hud()
	_the_menu()
	Events.power_cooldown_changed.disconnect(_on_heard)
	_foe.free()
	_player.free()


func _the_signal() -> void:
	var powers: PowerSet = PowerSet.of(_player)
	var bolt: Power = powers.kit.power(BOLT)
	var hero: StringName = Combatant.of(_player).combatant_id
	powers.start_cooldown(bolt)
	equal("starting a 2.5 second cooldown says 3 whole seconds are left, and whose",
		_heard, [[hero, BOLT, 3]])
	powers.tick_seconds(0.3)
	equal("a fraction of a second passing says nothing", _heard.size(), 1)
	powers.tick_seconds(0.5)
	equal("the next whole second says 2", _heard.back(), [hero, BOLT, 2])
	powers.tick_seconds(5.0)
	equal("running out says 0, once", [_heard.back(), _heard.size(), powers.cooldown_left(BOLT)],
		[[hero, BOLT, 0], 3, 0.0])
	powers.tick_turn()
	equal("a power not cooling says nothing", _heard.size(), 3)
	powers.start_cooldown(bolt)
	var kit: PowerKit = powers.kit
	powers.unequip()
	equal("taking the kit off ends its cooldowns, and says so", _heard.back(), [hero, BOLT, 0])
	powers.equip(kit)


func _the_hud() -> void:
	var hud := CombatHud.new()
	attach(hud)
	hud.subject = _player
	hud.refresh()
	var fighter: Combatant = Combatant.of(_player)
	var key: String = KeyBindings.text_for(CombatActions.POWER_1, false)
	var costed: String = tr(CombatHud.COST_KEY).format({"label": tr("fixture.power"), "cost": 5, "pool": "MP"})
	equal("the HUD's second line is slot 1: its key, its power and its cost",
		[key != "", hud.text.get_slice("\n", 1)],
		[true, tr(CombatHud.SLOT_KEY).format({"key": key, "label": costed})])
	PowerSet.of(_player).start_cooldown(PowerSet.of(_player).kit.power(BOLT))
	equal("using it shows the seconds left, with nothing but the signal to redraw it",
		hud.text.contains(tr(PowerMenu.COOLDOWN_SECONDS_KEY).format({"left": 3})), true)
	PowerSet.of(_player).tick_seconds(1.0)
	equal("and counts them down", hud.text.contains(tr(PowerMenu.COOLDOWN_SECONDS_KEY).format({"left": 2})), true)
	PowerSet.of(_player).tick_seconds(2.0)
	equal("until it is ready again", hud.text.get_slice("\n", 1), tr(CombatHud.SLOT_KEY).format({"key": key, "label": costed}))
	equal("a fighter with no powers has no slot line", hud.slot_text(Combatant.of(_foe)), "")
	equal("and the line is the fighter's own, not the foe's", hud.slot_text(fighter) != "", true)
	hud.free()


func _the_menu() -> void:
	var stack := UiRoot.new()
	attach(stack)
	var powers: PowerSet = PowerSet.of(_player)
	powers.start_cooldown(powers.kit.power(BOLT))
	var empty: Array[BattleCommand] = []
	var screen := CommandOverlay.for_fighter(Combatant.of(_player), empty)
	stack.open(screen)
	_row(screen, PowerMenu.CATEGORY_KEY).pressed.emit()
	powers.tick_seconds(1.0)
	equal("while it cools, the menu's power row stays greyed", _row(screen, "fixture.power").disabled, true)
	powers.tick_seconds(2.0)
	equal("WHEN IT IS READY, THE MENU DRAWS IT AGAIN, usable, still among the powers",
		[_row(screen, "fixture.power").disabled, _row(screen, CommandOverlay.BACK_KEY) != null], [false, true])
	stack.close_all()
	stack.free()


func _on_heard(who: StringName, power_id: StringName, left: int) -> void:
	_heard.append([who, power_id, left])


func _row(screen: MenuScreen, prefix: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(tr(prefix)):
			return button
	return null


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hud_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0, &"attack": 6.0}
	def.level_curve = LevelCurve.new()
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_hud"
	kit.name_key = "fixture.kit"
	var skill := Skill.new()
	skill.id = &"skill/fixture_hud_bolt"
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 5
	var bolt := Power.new()
	bolt.power_id = BOLT
	bolt.name_key = "fixture.power"
	bolt.skill = skill
	bolt.cooldown = 2.5
	kit.powers = [bolt]
	def.power_kit = kit
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	return loadout


func _enemy() -> Node3D:
	var actor := Node3D.new()
	actor.position = _player.global_position + Vector3(0, 0, -2)
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_hud_foe"
	fighter.faction = &"enemy"
	fighter.base_stats = {&"max_hp": 60.0, &"attack": 6.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
