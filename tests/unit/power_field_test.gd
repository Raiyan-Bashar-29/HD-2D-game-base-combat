extends TestCase
## Hero powers in the field (C6.2b): the player and each follower wear their fighter's kit; a
## power is used through `FieldCommands` with no ATB and counts its cooldown in seconds; a party
## switch carries each member's powers to the other body without stopping their mechanisms; the
## mechanisms stop only when the body is freed; and a kit's passive is held again, once, after a
## new game and after a load.
##
## OWNS: assertions about powers in `ActionHost`, `FieldParty`, `FieldCommands` and `PowerSet`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const FAKE_KIND: StringName = &"fixture_field_fake"
const SLOT: int = 3
const AURA: StringName = &"status/fixture_field_aura"
const BASE_ATTACK: float = 6.0


## A mechanism only this test runs.
class FakeMechanism:
	extends PowerMechanism

	func kind() -> StringName:
		return FAKE_KIND


## Counts what it was asked to do.
class FakeExecutor:
	extends PowerExecutor
	var used: int = 0
	var ended: int = 0
	var last_targets: int = -1

	func use(_user: Combatant, aimed: Array[Combatant], _rng: RandomNumberGenerator) -> void:
		used += 1
		last_targets = aimed.size()

	func end() -> void:
		ended += 1


var _player: PlayerController
var _foe: Node3D
var _lead: ActionLoadout
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(18)
	SaveFixture.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Flags.clear_all()
	_rng.seed = 11
	PowerMechanisms.register(FAKE_KIND, FakeExecutor)
	_lead = _loadout(&"fixture_field_lead", _kit(&"kit/fixture_lead", -0.5))
	var mate := _loadout(&"fixture_field_mate", _kit(&"kit/fixture_mate", -0.25))
	_lead.companions = [mate, _loadout(&"fixture_field_plain", null)]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _lead)
	var line: Array[PartyFollower] = FieldParty.spawn(_player, _lead)
	_foe = _enemy()
	_equipping(line)
	_using()
	_passives_survive()
	_switching(line)
	_foe.free()
	for follower: PartyFollower in FieldParty.followers(_player):
		follower.free()
	_player.free()
	PowerMechanisms.unregister(FAKE_KIND)
	SaveSystem.delete_slot(SLOT)
	Flags.clear_all()


func _equipping(line: Array[PartyFollower]) -> void:
	var powers: PowerSet = PowerSet.of(_player)
	var sheet: StatSheet = Combatant.of(_player).sheet
	equal("the player wears the fighter's kit, with its bonus and passive",
		[powers != null and powers.kit == _lead.fighter.power_kit, sheet.value(&"cost_mult_mp"),
			StatusSet.of(_player).stacks(AURA)], [true, -0.5, 1])
	equal("a follower wears its own kit", PowerSet.of(line[0]).kit.kit_id, &"kit/fixture_mate")
	equal("a fighter with no kit has no powers", PowerSet.of(line[1]), null)


func _using() -> void:
	var user: Combatant = Combatant.of(_player)
	var powers: PowerSet = PowerSet.of(_player)
	var bolt := BattleCommand.for_power(powers.kit.power(&"power/fixture_bolt"))
	equal("a power needs no ATB: this fighter has no gauge at all, and may use it",
		[AtbMeter.of(_player), FieldCommands.refusal(user, bolt)], [null, FieldCommands.Reason.NONE])
	equal("using it lands on the foe", FieldCommands.use(user, bolt, _rng), true)
	equal("hurting it and paying the kit-halved cost, cooling for 3 seconds",
		[Vitals.of(_foe).current(&"hp") < 60, Vitals.of(_player).current(&"mp"),
			powers.cooldown_left(&"power/fixture_bolt")], [true, 16, 3.0])
	equal("while it cools it is refused, and using it does nothing",
		[FieldCommands.refusal(user, bolt), FieldCommands.use(user, bolt, _rng)],
		[FieldCommands.Reason.POWER, false])
	powers.tick_seconds(3.0)
	equal("three seconds later it is ready", FieldCommands.refusal(user, bolt), FieldCommands.Reason.NONE)
	var gate := BattleCommand.for_power(powers.kit.power(&"power/fixture_gate"))
	var fake: FakeExecutor = powers.executor(&"power/fixture_gate") as FakeExecutor
	equal("a mechanism-only power is used with nobody to aim at",
		[FieldCommands.use(user, gate, _rng), fake.used, fake.last_targets], [true, 1, 0])


func _passives_survive() -> void:
	var statuses: StatusSet = StatusSet.of(_player)
	var sheet: StatSheet = Combatant.of(_player).sheet
	Events.game_started.emit()
	equal("after a new game clears the statuses, the passive is held again, counted once",
		[statuses.stacks(AURA), sheet.value(&"attack")], [1, BASE_ATTACK + 2.0])
	equal("the save works", SaveSystem.save_to_slot(SLOT), OK)
	statuses.cure(AURA)
	equal("the load works", SaveSystem.load_from_slot(SLOT), OK)
	equal("a kit's passive, which no status file holds, is back after a load, counted once",
		[statuses.stacks(AURA), sheet.value(&"attack")], [1, BASE_ATTACK + 2.0])


func _switching(line: Array[PartyFollower]) -> void:
	var mine: PowerSet = PowerSet.of(_player)
	var fake: FakeExecutor = mine.executor(&"power/fixture_gate") as FakeExecutor
	mine.start_cooldown(mine.kit.power(&"power/fixture_bolt"))
	var follower: PartyFollower = line[0]
	equal("a switch happens", FieldParty.switch(_player), true)
	equal("each member's powers went with them",
		[PowerSet.of(_player).kit.kit_id, PowerSet.of(follower) == mine,
			mine.cooldown_left(&"power/fixture_bolt")], [&"kit/fixture_mate", true, 3.0])
	equal("and so did each kit's bonus",
		[Combatant.of(_player).sheet.value(&"cost_mult_mp"), Combatant.of(follower).sheet.value(&"cost_mult_mp")],
		[-0.25, -0.5])
	equal("moving to another body did not stop a mechanism", fake.ended, 0)
	follower.free()
	equal("freeing the body does", fake.ended, 1)


func _loadout(id: StringName, kit: PowerKit) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0, &"attack": BASE_ATTACK}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	return loadout


func _kit(id: StringName, cheaper: float) -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = id
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, cheaper, &"anything")]
	var aura := StatusEffect.new()
	aura.id = AURA
	aura.name_key = "fixture.status"
	aura.duration = 0.0
	aura.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 2.0, AURA)]
	kit.passives = [aura]
	var skill := Skill.new()
	skill.id = &"skill/fixture_field_bolt"
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 8
	skill.sure_hit = true
	var bolt := Power.new()
	bolt.power_id = &"power/fixture_bolt"
	bolt.name_key = "fixture.power"
	bolt.skill = skill
	bolt.cooldown = 3.0
	var gate := Power.new()
	gate.power_id = &"power/fixture_gate"
	gate.name_key = "fixture.power"
	gate.mechanism = FakeMechanism.new()
	kit.powers = [bolt, gate]
	return kit


func _enemy() -> Node3D:
	var actor := Node3D.new()
	actor.position = _player.global_position + Vector3(0, 0, -2)
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_field_foe"
	fighter.faction = &"enemy"
	fighter.base_stats = {&"max_hp": 60.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
