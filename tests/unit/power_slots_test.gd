extends TestCase
## The quick slots (C6.3a): slot N holds the kit's Nth power that is not a passive, at most four;
## a press uses it in the field with no ATB and starts its cooldown; a cooling power, an empty
## slot and a slot past the last do nothing; and the fighter refuses a press while knocked back
## or while a menu holds the body.
##
## OWNS: assertions about `PowerSlots` and `ActionFighter.press_slot`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const FAKE_KIND: StringName = &"fixture_slots_fake"
const MENU_TOKEN: StringName = &"fixture_slots_menu"


## A mechanism only this test runs.
class FakeMechanism:
	extends PowerMechanism

	func kind() -> StringName:
		return FAKE_KIND


## Counts its uses and how many fighters each was aimed at.
class FakeExecutor:
	extends PowerExecutor
	var used: int = 0
	var last_targets: int = -1

	func use(_user: Combatant, aimed: Array[Combatant], _rng: RandomNumberGenerator) -> void:
		used += 1
		last_targets = aimed.size()


var _player: PlayerController
var _foe: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(11)
	_rng.seed = 5
	PowerMechanisms.register(FAKE_KIND, FakeExecutor)
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout(_kit()))
	_foe = _enemy()
	_slotting()
	_pressing()
	_through_the_fighter()
	_foe.free()
	_player.free()
	PowerMechanisms.unregister(FAKE_KIND)


func _slotting() -> void:
	var ids: Array[StringName] = []
	for power: Power in PowerSlots.powers(Combatant.of(_player)):
		ids.append(power.power_id)
	equal("the slots hold the kit's powers in order, skipping the passive, four at most", ids,
		[&"power/fixture_a", &"power/fixture_gate", &"power/fixture_c", &"power/fixture_d"] as Array[StringName])
	var bare := Combatant.new()
	equal("a fighter with no kit has empty slots", PowerSlots.powers(bare).size(), 0)
	bare.free()
	equal("there is one key for each slot", CombatActions.SLOTS.size(), PowerSlots.COUNT)


func _pressing() -> void:
	var user: Combatant = Combatant.of(_player)
	var powers: PowerSet = PowerSet.of(_player)
	equal("pressing slot 1 uses its power, with no ATB gauge needed",
		[AtbMeter.of(_player), PowerSlots.press(user, 0, _rng)], [null, true])
	equal("hurting the foe, paying the cost and cooling for 2 seconds",
		[Vitals.of(_foe).current(&"hp") < 60, Vitals.of(_player).current(&"mp"),
			powers.cooldown_left(&"power/fixture_a")], [true, 15, 2.0])
	var hp: int = Vitals.of(_foe).current(&"hp")
	equal("pressing it again while it cools does nothing",
		[PowerSlots.press(user, 0, _rng), Vitals.of(_foe).current(&"hp"), Vitals.of(_player).current(&"mp")],
		[false, hp, 15])
	var fake: FakeExecutor = powers.executor(&"power/fixture_gate") as FakeExecutor
	equal("slot 2's mechanism runs with nobody to aim at",
		[PowerSlots.press(user, 1, _rng), fake.used, fake.last_targets], [true, 1, 0])
	equal("a slot past the last, or before the first, does nothing",
		[PowerSlots.press(user, 9, _rng), PowerSlots.press(user, -1, _rng)], [false, false])
	powers.tick_seconds(2.0)


func _through_the_fighter() -> void:
	var fighter: ActionFighter = _fighter()
	var powers: PowerSet = PowerSet.of(_player)
	_player.lock_input(MENU_TOKEN)
	equal("while a menu holds the body, a slot key does nothing",
		[fighter.press_slot(0), powers.cooldown_left(&"power/fixture_a")], [false, 0.0])
	_player.release_input(MENU_TOKEN)
	Events.knockback_requested.emit(Combatant.of(_player).combatant_id, Vector3.BACK)
	equal("nor while knocked back", [fighter.stunned(), fighter.press_slot(2),
		powers.cooldown_left(&"power/fixture_c")], [true, false, 0.0])
	fighter.drive(1.0, false, false)
	equal("once free again, the fighter uses the slot",
		[fighter.press_slot(0), powers.cooldown_left(&"power/fixture_a")], [true, 2.0])


func _fighter() -> ActionFighter:
	for child: Node in _player.get_children():
		if child is ActionFighter:
			return child as ActionFighter
	return null


func _loadout(kit: PowerKit) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_slots_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0, &"attack": 6.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	return loadout


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_slots"
	kit.name_key = "fixture.kit"
	var held := Power.new()
	held.power_id = &"power/fixture_held"
	held.name_key = "fixture.power"
	held.passive = true
	var gate := Power.new()
	gate.power_id = &"power/fixture_gate"
	gate.name_key = "fixture.power"
	gate.mechanism = FakeMechanism.new()
	kit.powers = [held, _bolt(&"power/fixture_a"), gate, _bolt(&"power/fixture_c"),
		_bolt(&"power/fixture_d"), _bolt(&"power/fixture_e")]
	return kit


func _bolt(id: StringName) -> Power:
	var skill := Skill.new()
	skill.id = &"skill/fixture_slots_bolt"
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 5
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.skill = skill
	power.cooldown = 2.0
	return power


func _enemy() -> Node3D:
	var actor := Node3D.new()
	actor.position = _player.global_position + Vector3(0, 0, -2)
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_slots_foe"
	fighter.faction = &"enemy"
	fighter.base_stats = {&"max_hp": 60.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
