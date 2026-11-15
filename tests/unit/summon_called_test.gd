extends TestCase
## A summon used during a turn-based battle (C8.10e). The power brings one fighter per entry
## onto its user's side of the running battle: guests beside a party member, one more foe
## beside an enemy. They take turns from the next ordering, play themselves, hold the owner
## status while out, leave after `turns` of the user's turns or when the user falls, and leave
## no pool flags behind.
##
## OWNS: assertions about `SummonRun` in a battle, `SummonMechanism.turns`, `Battle.admit`,
## `BattleSetup.summon`, `BattleSetup.dismiss` and the `SUMMONED` pools on `release`.
## MUST NOT: name a game's kits, powers or characters.

var _holder: Node
var _rng := RandomNumberGenerator.new()
var _summon: SummonMechanism
var _call: Power


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_summon = _mechanism()
	_call = _power(_summon)
	_party_side()
	_enemy_side()
	_holder.free()
	Flags.clear_all()


func _party_side() -> void:
	var battle: Battle = _build(true)
	var hero: Combatant = battle.party[0]
	_until(battle, hero)
	battle.act(BattleCommand.for_power(_call), [])
	var called: Combatant = battle.party[battle.party.size() - 1]
	var screen: BattleScreen = BattleScreen.for_battle(battle)
	var shown: String = screen.name_of(called)
	screen.free()
	equal("a use in a battle brings two guests onto the user's side, in the turn order, named plainly",
		[battle.party.size(), battle.guests.size(), called.side(), battle.scheduler.has(called.combatant_id),
			_held(hero), shown],
		[3, 2, hero.side(), true, 1, "fixture.name.fixture_called"])
	var foe: Combatant = battle.enemies[0]
	var before: int = Vitals.of(foe.get_parent()).current(&"hp")
	_until(battle, called)
	BattleAi.take_turn(battle, battle.brain_of(called))
	Vitals.of(called.get_parent()).change(&"hp", -1)
	var id: StringName = called.combatant_id
	equal("a called guest's own turn hurts a foe",
		Vitals.of(foe.get_parent()).current(&"hp") < before, true)
	# Two more of the user's own turns: each one's count runs out on the second.
	_until(battle, hero)
	battle.act(_guard(), [])
	_until(battle, hero)
	equal("after `turns` of the user's turns they are gone from the side and the order, and the status drops",
		[battle.party.size(), battle.guests.size(), battle.scheduler.has(id), _held(hero)], [1, 0, false, 0])
	battle.act(BattleCommand.for_power(_call), [])
	var flag: StringName = StringName("vital/%s/hp" % battle.party[1].combatant_id)
	Vitals.of(battle.party[1].get_parent()).change(&"hp", -1)
	Vitals.of(hero.get_parent()).set_to(&"hp", 1)
	_finish(battle, hero)
	var lost: bool = battle.outcome() == Battle.Outcome.LOST
	BattleSetup.release(battle)
	equal("the user down is a loss, its called guests leave with it, and no pool flag is left for them",
		[lost, Flags.has_flag(flag), Flags.has_flag(StringName("vital/%s/hp" % id))], [true, false, false])


func _enemy_side() -> void:
	var battle: Battle = _build(false)
	var foe: Combatant = battle.enemies[0]
	_until(battle, foe)
	battle.act(BattleCommand.for_power(_call), [])
	var count: int = battle.enemies.size()
	var side: StringName = battle.enemies[count - 1].side()
	Vitals.of(foe.get_parent()).change(&"hp", -999)
	_until(battle, battle.party[0])
	battle.act(_guard(), [])
	equal("an enemy's summon joins its side; when the enemy falls they leave and the fight is won",
		[count, side, battle.enemies.size(), battle.outcome()], [3, foe.side(), 1, Battle.Outcome.WON])
	BattleSetup.release(battle)


# How many stacks of the owner status `who` holds.
func _held(who: Combatant) -> int:
	return StatusSet.of(who.get_parent()).stacks(_summon.owner_status.id)


# Plays turns, everyone guarding, until it is `who`'s.
func _until(battle: Battle, who: Combatant) -> void:
	for turn: int in 16:
		var actor: Combatant = battle.next_turn()
		if actor == null or actor == who:
			return
		battle.act(_guard(), [])


# Plays turns, guarding, until one of `victim`'s foes strikes it down.
func _finish(battle: Battle, victim: Combatant) -> void:
	for turn: int in 16:
		var actor: Combatant = battle.next_turn()
		if actor == null:
			return
		if actor.can_target(victim, FactionTable.Target.ENEMY):
			battle.act(BattleCommand.new(), [victim])
			return
		battle.act(_guard(), [])


func _build(hero_calls: bool) -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_called"
	var foe: CombatantDef = _def(&"fixture_called_foe", &"side_foe", 1.0)
	var hero: CombatantDef = _def(&"fixture_called_hero", &"side_party", 9.0)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_called"
	kit.powers = [_call]
	if hero_calls:
		hero.power_kit = kit
	else:
		foe.power_kit = kit
	encounter.enemies = [foe]
	var battle: Battle = BattleSetup.build(encounter, [hero], _holder, _rng)
	battle.rng.seed = 7
	return battle


func _mechanism() -> SummonMechanism:
	var made := SummonMechanism.new()
	var def: CombatantDef = _def(&"fixture_called", &"side_z", 5.0)
	made.fighters = [def, def]
	made.brains = [ActionBrain.new(), ActionBrain.new()]
	made.turns = 2
	made.cap = 2
	var status := StatusEffect.new()
	status.id = &"status/fixture_called_out"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 9999.0
	made.owner_status = status
	return made


func _power(mechanism: SummonMechanism) -> Power:
	var power := Power.new()
	power.power_id = &"power/fixture_called"
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _guard() -> BattleCommand:
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	return guard


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 30.0, &"speed": speed, &"attack": 6.0, &"defence": 1.0}
	def.level_curve = LevelCurve.new()
	return def
