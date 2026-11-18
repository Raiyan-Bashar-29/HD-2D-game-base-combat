extends TestCase
## Finishers in a battle (C6.8): a finisher is offered every standing foe; with no charge it
## lands at once on the one picked (the battle menu asks which, C10.1), or on all; a charge of turns holds its status and lands at
## the start of the user's turn once the turns have passed; and a hit breaks a fragile charge.
##
## OWNS: assertions about `FinisherRun`'s battle reading.
## MUST NOT: name a game's kits, powers or characters.

const CHARGING: StringName = &"status/fixture_finisher_battle_charging"

var _powers: Dictionary[String, Power] = {}
var _holder: Node
var _battle: Battle
var _stack: UiRoot


func run() -> void:
	plan(7)
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_stack = UiRoot.new()
	attach(_stack)
	_at_once()
	_charge()
	_stack.free()
	_holder.free()
	Flags.clear_all()


func _at_once() -> void:
	_start()
	var single := BattleCommand.for_power(_powers["single"])
	equal("in a battle a finisher aims at the standing foes", _battle.targets_for(single), _battle.enemies)
	equal("one that strikes one foe asks which; one that strikes all does not (C10.1)",
		[single.one_target(), BattleCommand.for_power(_powers["all"]).one_target()], [true, false])
	var screen := BattleScreen.for_battle(_battle)
	_stack.open(screen)
	_row(screen, PowerMenu.CATEGORY_KEY).pressed.emit()
	_row(screen, "fixture.power.single").pressed.emit()
	equal("the battle menu lists the foes to pick from", [_row(screen, screen.name_of(_battle.enemies[0])) != null,
		_row(screen, screen.name_of(_battle.enemies[1])) != null, _hp(0), _hp(1)], [true, true, 99, 99])
	_row(screen, screen.name_of(_battle.enemies[1])).pressed.emit()
	equal("with no charge it lands at once on the foe picked alone", [_hp(0), _hp(1) < 99], [99, true])
	_stack.close_all()
	_start()
	_battle.act(BattleCommand.for_power(_powers["all"]), [])
	equal("striking every foe lands on each", [_hp(0) < 99, _hp(1) < 99], [true, true])
	_end()


func _charge() -> void:
	_start()
	_battle.act(BattleCommand.for_power(_powers["charged"]), [_battle.enemies[0]])
	var held: int = _stacks()
	var waiting: int = _hp(0)
	_hero_turn()
	equal("a charge of one turn holds its status, then lands at the start of the user's next turn",
		[held, waiting, _stacks(), _hp(0) < 99], [1, 99, 0, true])
	_end()
	_start()
	_battle.act(BattleCommand.for_power(_powers["fragile"]), [_battle.enemies[0]])
	_battle.enemies[1].hit(_battle.party[0], 3.0, &"", _battle.rng)
	_hero_turn()
	equal("a hit breaks a fragile charge, and nothing lands", [_stacks(), _hp(0), _hp(1)], [0, 99, 99])
	_end()


func _start() -> void:
	var hero: CombatantDef = _def(&"fixture_finisher_hero", &"side_a", 9.0)
	hero.power_kit = _kit()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_finisher"
	encounter.enemies = [_def(&"fixture_finisher_one", &"side_b", 1.0),
		_def(&"fixture_finisher_two", &"side_b", 1.0)]
	_battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	_battle.rng.seed = 4
	_battle.next_turn()


func _end() -> void:
	BattleSetup.release(_battle)
	for child: Node in _holder.get_children():
		child.free()


# Plays turns until it is the hero's again, the foes waiting.
func _hero_turn() -> void:
	for turn: int in 6:
		if _battle.next_turn() == _battle.party[0]:
			return
		_battle.act(BattleCommand.new(), [_battle.party[0]])


func _hp(foe: int) -> int:
	return Vitals.of(_battle.enemies[foe].get_parent()).current(&"hp")


func _stacks() -> int:
	return StatusSet.of(_battle.party[0].get_parent()).stacks(CHARGING)


func _kit() -> PowerKit:
	var all: FinisherMechanism = _finisher(0)
	all.all_foes = true
	var charged: FinisherMechanism = _finisher(1)
	charged.charging = _charging(false)
	var fragile: FinisherMechanism = _finisher(1)
	fragile.charging = _charging(true)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_finisher_battle"
	kit.name_key = "fixture.kit"
	kit.powers = [_power("single", _finisher(0)), _power("all", all), _power("charged", charged),
		_power("fragile", fragile)]
	return kit


func _finisher(turns: int) -> FinisherMechanism:
	var finisher := FinisherMechanism.new()
	finisher.charge_turns = turns
	finisher.strike = ActionMove.new()
	finisher.strike.startup = 0.0
	finisher.strike.active = 0.2
	finisher.strike.recovery = 0.0
	finisher.strike.power = 5.0
	finisher.strike.hitbox_size = Vector3(0.5, 0.5, 0.5)
	return finisher


func _charging(fragile: bool) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = CHARGING
	status.name_key = "fixture.status"
	status.breaks_on_hit = fragile
	return status


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_finisher_battle_" + short)
	power.name_key = "fixture.power." + short
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0,
		&"defence": 1.0, &"evasion": 0.0}
	return def


func _row(screen: MenuScreen, prefix: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(tr(prefix)):
			return button
	return null
