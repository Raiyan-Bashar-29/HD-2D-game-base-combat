extends TestCase
## Hero powers in a turn-based battle (C6.2a): a definition's kit is equipped when the battle
## builds the fighter, on either side; a POWER command is aimed like its skill, lands through
## `PowerUse`, pays its kit-cheapened cost and starts its cooldown; the cooldown counts down only
## at the start of the holder's own turns, asleep or not; a silence, a cooldown and a passive
## each refuse it without changing anything; and a power that is all mechanism needs no target.
##
## OWNS: assertions about `BattleCommand.Kind.POWER`, `CombatantDef.power_kit`, and how
## `Battle` and `BattleSetup` use them.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const FAKE_KIND: StringName = &"fixture_battle_fake"


## A mechanism only this test runs.
class FakeMechanism:
	extends PowerMechanism

	func kind() -> StringName:
		return FAKE_KIND


## Counts its uses.
class FakeExecutor:
	extends PowerExecutor
	var used: int = 0
	var last_targets: int = -1

	func use(_user: Combatant, aimed: Array[Combatant], _rng: RandomNumberGenerator) -> void:
		used += 1
		last_targets = aimed.size()


var _holder: Node
var _battle: Battle
var _hero: Combatant
var _plain: Combatant
var _foe: Combatant


func run() -> void:
	plan(24)
	SaveFixture.activate()
	Flags.clear_all()
	PowerMechanisms.register(FAKE_KIND, FakeExecutor)
	_holder = Node.new()
	attach(_holder)
	_content()
	_build()
	_first_turn()
	_second_turn()
	_asleep_and_back()
	BattleSetup.release(_battle)
	PowerMechanisms.unregister(FAKE_KIND)
	_holder.free()
	Flags.clear_all()


func _content() -> void:
	var bolt: Power = _power(&"power/fixture_bolt")
	var command := BattleCommand.for_power(bolt)
	equal("for_power makes a POWER command carrying the power, its skill and its name",
		[command.kind, command.power, command.skill, command.label_key],
		[BattleCommand.Kind.POWER, bolt, bolt.skill, bolt.name_key])
	var empty := BattleCommand.new()
	empty.kind = BattleCommand.Kind.POWER
	equal("a POWER command naming no power is a problem", empty.problems("fixture").size(), 1)
	var def: CombatantDef = _def(&"fixture_odd", &"side_a", 9.0)
	def.power_kit = PowerKit.new()
	equal("a fighter's broken kit is the fighter's problem", def.problems("fixture").is_empty(), false)


func _build() -> void:
	var hero: CombatantDef = _def(&"fixture_hero", &"side_a", 9.0)
	hero.power_kit = _hero_kit()
	var plain: CombatantDef = _def(&"fixture_plain", &"side_a", 5.0)
	var foe: CombatantDef = _def(&"fixture_foe", &"side_b", 1.0)
	var foe_kit := PowerKit.new()
	foe_kit.kit_id = &"kit/fixture_foe"
	foe_kit.name_key = "fixture.kit"
	foe_kit.powers = [_power(&"power/fixture_foe_bolt")]
	foe.power_kit = foe_kit
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_powers"
	encounter.enemies = [foe]
	_battle = BattleSetup.build(encounter, [hero, plain], _holder, RandomNumberGenerator.new())
	_hero = _battle.party[0]
	_plain = _battle.party[1]
	_foe = _battle.enemies[0]
	var powers: PowerSet = PowerSet.of(_hero.get_parent())
	equal("a fighter with a kit gets a PowerSet holding it",
		powers != null and powers.kit == hero.power_kit, true)
	equal("with its stat bonus on the sheet and its passive held",
		[_hero.sheet.value(&"cost_mult_mp"), StatusSet.of(_hero.get_parent()).stacks(&"status/fixture_aura")],
		[-0.5, 1])
	equal("a fighter without a kit gets none", PowerSet.of(_plain.get_parent()), null)
	var theirs: PowerSet = PowerSet.of(_foe.get_parent())
	equal("an enemy with a kit gets one too", theirs != null and theirs.kit == foe_kit, true)


func _first_turn() -> void:
	equal("the fastest goes first", _battle.next_turn(), _hero)
	var bolt := BattleCommand.for_power(_kit_power(&"power/fixture_bolt"))
	var as_skill := BattleCommand.new()
	as_skill.kind = BattleCommand.Kind.SKILL
	as_skill.skill = bolt.skill
	equal("a power is aimed exactly like its skill", _battle.targets_for(bolt), _battle.targets_for(as_skill))
	equal("using it is accepted", _battle.act(bolt, [_foe]), true)
	equal("it lands on the foe", Vitals.of(_foe.get_parent()).current(&"hp") < 99, true)
	equal("and costs the kit-halved 4 mp", Vitals.of(_hero.get_parent()).current(&"mp"), 16)
	equal("and starts its 2-turn cooldown", _cooldown(), 2.0)
	equal("another fighter's turn does not count it down", [_battle.next_turn(), _cooldown()], [_plain, 2.0])
	_pass()
	_battle.next_turn()
	_pass()


func _second_turn() -> void:
	equal("the holder's own turn does", [_battle.next_turn(), _cooldown()], [_hero, 1.0])
	var bolt := BattleCommand.for_power(_kit_power(&"power/fixture_bolt"))
	var hp: int = Vitals.of(_foe.get_parent()).current(&"hp")
	equal("a cooling power is refused, changing nothing",
		[_battle.act(bolt, [_foe]), Vitals.of(_foe.get_parent()).current(&"hp"), _battle.current()],
		[false, hp, _hero])
	var statuses: StatusSet = StatusSet.of(_hero.get_parent())
	statuses.apply(_status(&"status/fixture_hush", [StatusEffect.Block.NO_SKILLS]))
	equal("a silence blocks a power", _battle.allows(bolt), false)
	statuses.cure(&"status/fixture_hush")
	var held := BattleCommand.for_power(_kit_power(&"power/fixture_held"))
	equal("a passive power is never used", _battle.act(held, []), false)
	var gate := BattleCommand.for_power(_kit_power(&"power/fixture_gate"))
	var fake: FakeExecutor = PowerSet.of(_hero.get_parent()).executor(&"power/fixture_gate") as FakeExecutor
	equal("a power that is all mechanism needs no target", _battle.act(gate, []), true)
	equal("and its executor runs once, with no targets", [fake.used, fake.last_targets], [1, 0])
	# Asleep for the hero's next turn.
	var sleep := _status(&"status/fixture_sleep", [StatusEffect.Block.SKIP_TURN])
	sleep.duration = 1.0
	statuses.apply(sleep)
	_battle.next_turn()
	_pass()
	_battle.next_turn()
	_pass()


func _asleep_and_back() -> void:
	equal("asleep, the hero loses the turn", _battle.next_turn(), _plain)
	equal("but its cooldown still ran out", _cooldown(), 0.0)
	_pass()
	_battle.next_turn()
	_pass()
	equal("two turns after its use, the power is back", _battle.next_turn(), _hero)
	var bolt := BattleCommand.for_power(_kit_power(&"power/fixture_bolt"))
	equal("and accepted again", _battle.act(bolt, [_foe]), true)


## The current fighter does nothing much.
func _pass() -> void:
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	_battle.act(guard, [])


func _cooldown() -> float:
	return PowerSet.of(_hero.get_parent()).cooldown_left(&"power/fixture_bolt")


func _kit_power(id: StringName) -> Power:
	return PowerSet.of(_hero.get_parent()).kit.power(id)


func _hero_kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_hero"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"cost_mult_mp", StatModifier.Op.ADD, -0.5, &"anything")]
	var aura := _status(&"status/fixture_aura", [])
	aura.duration = 0.0
	kit.passives = [aura]
	var bolt: Power = _power(&"power/fixture_bolt")
	bolt.cooldown = 2.0
	var held: Power = _power(&"power/fixture_held")
	held.skill = null
	held.passive = true
	var gate: Power = _power(&"power/fixture_gate")
	gate.skill = null
	gate.mechanism = FakeMechanism.new()
	kit.powers = [bolt, held, gate]
	return kit


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 2.0, &"defence": 1.0}
	return def


func _power(id: StringName) -> Power:
	var skill := Skill.new()
	skill.id = StringName(String(id).replace("power/", "skill/"))
	skill.name_key = "fixture.skill"
	skill.power = 4.0
	skill.cost_pool = &"mp"
	skill.cost = 8
	skill.sure_hit = true
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.skill = skill
	return power


func _status(id: StringName, blocks: Array[StatusEffect.Block]) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = 3.0
	status.blocks = blocks
	return status
