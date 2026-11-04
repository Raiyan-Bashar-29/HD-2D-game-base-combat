extends TestCase
## Hero powers in the menus (C6.2c): a fighter's kit becomes one "Powers" row in the battle menu
## and in the hybrid's command overlay; a usable power shows the cost its kit makes cheaper; a
## refused one is greyed out with its `PowerUse` reason in words ("ready in 1 turns" in a battle,
## "ready in 3s" in the field, out of hours, a pool too low); a power that is all mechanism needs
## nobody to aim at; a field power shows no ATB bars and needs none; and the command key opens
## the overlay for a fighter whose loadout has no commands but whose kit has powers.
##
## OWNS: assertions about `PowerMenu` and how `BattleMenu`, `BattleScreen`, `CommandOverlay` and
## `CommandHost` use it.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const FAKE_KIND: StringName = &"fixture_menu_fake"


## A mechanism only this test runs.
class FakeMechanism:
	extends PowerMechanism

	func kind() -> StringName:
		return FAKE_KIND


## Does nothing: the menus are what is under test.
class FakeExecutor:
	extends PowerExecutor


var _stack: UiRoot
var _holder: Node


func run() -> void:
	plan(18)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	CombatClock.reset()
	PowerMechanisms.register(FAKE_KIND, FakeExecutor)
	_stack = UiRoot.new()
	attach(_stack)
	_holder = Node.new()
	attach(_holder)
	_words()
	_in_a_battle()
	_in_the_field()
	_stack.close_all()
	CombatClock.reset()
	PowerMechanisms.unregister(FAKE_KIND)
	_holder.free()
	_stack.free()
	Flags.clear_all()


func _words() -> void:
	var missing: Array[String] = []
	for key: String in [PowerMenu.CATEGORY_KEY, PowerMenu.COOLDOWN_TURNS_KEY, PowerMenu.COOLDOWN_SECONDS_KEY,
			PowerMenu.HOURS_KEY, PowerMenu.STATUS_KEY, PowerMenu.POOL_KEY, PowerMenu.NOT_EQUIPPED_KEY]:
		if tr(key) == key:
			missing.append(key)
	equal("every power reason has words a player reads", missing, [] as Array[String])


func _in_a_battle() -> void:
	var hero: CombatantDef = _def(&"fixture_hero", &"side_a", 9.0)
	hero.power_kit = _kit(2.0)
	var foe: CombatantDef = _def(&"fixture_foe", &"side_b", 1.0)
	foe.brain = BattleBrain.new()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_power_menu"
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	var fighter: Combatant = battle.party[0]
	var listed: Array[BattleCommand] = PowerMenu.commands(fighter)
	equal("each power but the passive becomes a POWER command under the Powers category",
		[listed.size(), listed[0].kind, listed[0].category], [4, BattleCommand.Kind.POWER, PowerMenu.CATEGORY_KEY])
	equal("a fighter with no kit has none", PowerMenu.commands(battle.enemies[0]).is_empty(), true)
	var screen := BattleScreen.for_battle(battle)
	_stack.open(screen)
	equal("the hero's first menu has one Powers row", screen.row_texts().count(tr(PowerMenu.CATEGORY_KEY)), 1)
	_press(screen, tr(PowerMenu.CATEGORY_KEY))
	var bolt: Button = _row(screen, "fixture.power.bolt")
	equal("a usable power is offered at the cost its kit halves",
		[bolt.disabled, bolt.text], [false, _costed("fixture.power.bolt", 4)])
	equal("a power that is all mechanism needs nobody to aim at", _row(screen, "fixture.power.gate").disabled, false)
	var dusk: Button = _row(screen, "fixture.power.dusk")
	equal("a power out of its hours is greyed out, saying so",
		[dusk.disabled, dusk.text.contains(tr(PowerMenu.HOURS_KEY))], [true, true])
	var sunlit: Button = _row(screen, "fixture.power.sunlit")
	equal("a power whose pool is too low names that pool",
		[sunlit.disabled, sunlit.text.contains(tr(PowerMenu.POOL_KEY).format({"pool": "SUN"}))], [true, true])
	bolt.pressed.emit()
	_press(screen, screen.name_of(battle.enemies[0]))
	equal("using it lands, and the menu is the hero's again a round later",
		[Vitals.of(battle.enemies[0].get_parent()).current(&"hp") < 99, battle.current() == fighter], [true, true])
	_press(screen, tr(PowerMenu.CATEGORY_KEY))
	bolt = _row(screen, "fixture.power.bolt")
	equal("then it is greyed out with the turns left",
		[bolt.disabled, bolt.text.contains(tr(PowerMenu.COOLDOWN_TURNS_KEY).format({"left": 1}))], [true, true])
	equal("and the battle menu gives the same reason",
		BattleMenu.refusal(battle, BattleCommand.for_power(_bolt_power(fighter)), 0), PowerMenu.COOLDOWN_TURNS_KEY)
	_stack.close_all()


func _in_the_field() -> void:
	var player: PlayerController = build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	var loadout := ActionLoadout.new()
	loadout.fighter = _def(&"fixture_field_hero", &"player", 9.0)
	loadout.fighter.power_kit = _kit(3.0)
	loadout.moves = MoveSet.new()
	loadout.moves.attack_chain = [ActionMove.new()]
	loadout.atb = AtbRules.new()
	ActionHost.equip(player, loadout)
	var foe: Node3D = _field_foe(player)
	var host := CommandHost.new()
	host.loadout = loadout
	attach(host)
	equal("the command key opens the menu for a kit with no loadout commands",
		[host.can_open(player), host.toggle(_stack, player)], [true, true])
	var screen: CommandOverlay = _stack.top() as CommandOverlay
	_row(screen, PowerMenu.CATEGORY_KEY).pressed.emit()
	var bolt: Button = _row(screen, "fixture.power.bolt")
	equal("a field power shows no ATB bars and is usable with an empty gauge",
		[bolt.disabled, bolt.text], [false, _costed("fixture.power.bolt", 4)])
	var asked: Array[bool] = [false]
	screen.close_requested.connect(func() -> void: asked[0] = true)
	bolt.pressed.emit()
	equal("choosing it lands on the foe and asks to close", [Vitals.of(foe).current(&"hp") < 99, asked[0]], [true, true])
	_stack.close_top()
	host.toggle(_stack, player)
	screen = _stack.top() as CommandOverlay
	_row(screen, PowerMenu.CATEGORY_KEY).pressed.emit()
	bolt = _row(screen, "fixture.power.bolt")
	equal("then it is greyed out with the seconds left",
		[bolt.disabled, bolt.text.contains(tr(PowerMenu.COOLDOWN_SECONDS_KEY).format({"left": 3}))], [true, true])
	equal("and the overlay's own reason words leave a power reason to the power menu",
		CommandOverlay.reason_key(FieldCommands.Reason.POWER), "")
	var args: Dictionary = PowerMenu.reason_args(Combatant.of(player), BattleCommand.for_power(_bolt_power(Combatant.of(player))))
	equal("its blanks are the pool its skill costs and the seconds left", args, {"pool": "MP", "left": 3})
	_stack.close_all()
	equal("closing put the fight back to full speed", CombatClock.scale, 1.0)
	host.free()
	foe.free()
	player.free()


func _bolt_power(fighter: Combatant) -> Power:
	return PowerSet.of(fighter.get_parent()).kit.power(&"power/fixture_bolt")


func _costed(name_key: String, cost: int) -> String:
	return tr(BattleScreen.COST_KEY).format({"label": tr(name_key), "cost": cost, "pool": "MP"})


func _press(screen: MenuScreen, text: String) -> void:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text == text:
			button.pressed.emit()
			return


func _row(screen: MenuScreen, prefix: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(tr(prefix)):
			return button
	return null


# A kit: a bolt (cooling for `cooldown`), a passive, a power that is all mechanism, one that is
# never in its hours now, and one that needs a pool the fighter does not have. Costs halved.
func _kit(cooldown: float) -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_menu"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, -0.5, &"anything")]
	var bolt: Power = _power(&"power/fixture_bolt", "fixture.power.bolt")
	bolt.cooldown = cooldown
	var held: Power = _power(&"power/fixture_held", "fixture.power.held")
	held.skill = null
	held.passive = true
	var gate: Power = _power(&"power/fixture_gate", "fixture.power.gate")
	gate.skill = null
	gate.mechanism = FakeMechanism.new()
	var dusk: Power = _power(&"power/fixture_dusk", "fixture.power.dusk")
	var now: float = floorf(Clock.minutes_today() / 60.0)
	dusk.active_hours = Vector2(fmod(now + 2.0, 24.0), fmod(now + 3.0, 24.0))
	var sunlit: Power = _power(&"power/fixture_sunlit", "fixture.power.sunlit")
	sunlit.requires_pool = &"sun"
	sunlit.requires_fraction = 0.5
	kit.powers = [bolt, held, gate, dusk, sunlit]
	return kit


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 2.0, &"defence": 1.0}
	return def


func _power(id: StringName, name_key: String) -> Power:
	var skill := Skill.new()
	skill.id = StringName(String(id).replace("power/", "skill/"))
	skill.name_key = name_key
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 8
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = name_key
	power.skill = skill
	return power


func _field_foe(player: Node3D) -> Node3D:
	var actor := Node3D.new()
	actor.position = player.global_position + Vector3(0, 0, -2)
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = &"fixture_field_foe"
	combatant.faction = &"enemy"
	combatant.base_stats = {&"max_hp": 99.0, &"defence": 1.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
