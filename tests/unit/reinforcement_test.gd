extends TestCase
## The reserve steps in, and foes arrive in waves (C8.22a). When a party member falls, the first
## standing reserve member takes its slot and the fight goes on; with nobody left it is lost.
## When every foe is down, the encounter's next wave of held-back foes joins, named apart, and
## the fight is won only when the last has fallen.
##
## OWNS: assertions about `BattleReserve.refill`, `BattleSetup.reinforce` and
## `Encounter.reinforcements`.
## MUST NOT: name a game's fighters or encounters, or wait for frames.

const HERO: StringName = &"fixture_wave_hero"
const BENCH: StringName = &"fixture_wave_bench"
const FOE: StringName = &"fixture_wave_foe"
const LATE: StringName = &"fixture_wave_late"

var _arrived: Array = []
var _swaps: Array = []


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	_stepping_in(holder)
	_waves(holder)
	holder.free()
	Flags.clear_all()


func _stepping_in(holder: Node) -> void:
	var battle: Battle = BattleSetup.build(_encounter([]), [_def(HERO, &"side_a")], holder,
			RandomNumberGenerator.new(), [], [_def(BENCH, &"side_a")])
	var hero: Combatant = battle.party[0]
	Events.party_swapped.connect(_on_swapped)
	_fell(hero)
	_spend_turn(battle)
	Events.party_swapped.disconnect(_on_swapped)
	equal("a fallen member's slot goes to the standing reserve, and the fight goes on",
		[battle.party[0].combatant_id, battle.reserve.has(hero), battle.outcome(), _swaps],
		[BENCH, true, Battle.Outcome.ONGOING, [[HERO, BENCH]]])
	_fell(battle.party[0])
	_spend_turn(battle)
	equal("with nobody left to step in, the fight is lost", battle.outcome(), Battle.Outcome.LOST)
	Battle.running = null
	BattleSetup.release(battle)


func _waves(holder: Node) -> void:
	var battle: Battle = BattleSetup.build(_encounter([_def(LATE, &"side_b"), _def(LATE, &"side_b")]),
			[_def(HERO, &"side_a")], holder, RandomNumberGenerator.new())
	Events.reinforcements_arrived.connect(_on_arrived)
	_fell(battle.enemies[0])
	_spend_turn(battle)
	equal("with every foe down, the next wave arrives, named apart, and the fight goes on",
		[battle.enemies.size(), _arrived, battle.outcome()],
		[2, [[StringName(String(LATE) + "_r1")]], Battle.Outcome.ONGOING])
	_fell(battle.enemies[1])
	_spend_turn(battle)
	equal("the waves keep coming until none are left", battle.enemies.size(), 3)
	_fell(battle.enemies[2])
	_spend_turn(battle)
	Events.reinforcements_arrived.disconnect(_on_arrived)
	equal("the fight is won when the last has fallen", battle.outcome(), Battle.Outcome.WON)
	equal("each foe that arrived adds the encounter's reinforcement experience (C8.23)",
		Rewards.grant(battle, battle.encounter, null).experience, 10 + 2 * 4)
	BattleSetup.release(battle)


func _spend_turn(battle: Battle) -> void:
	if battle.current() == null:
		battle.next_turn()
	var defend := BattleCommand.new()
	defend.kind = BattleCommand.Kind.DEFEND
	battle.act(defend, [])


func _fell(fighter: Combatant) -> void:
	Vitals.of(fighter.get_parent()).change(&"hp", -9999)


func _on_swapped(out: StringName, coming: StringName) -> void:
	_swaps.append([out, coming])


func _on_arrived(who: Array[StringName]) -> void:
	_arrived.append(who)


func _encounter(late: Array[CombatantDef]) -> Encounter:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_waves"
	encounter.enemies = [_def(FOE, &"side_b")]
	encounter.reinforcements = late
	encounter.experience = 10
	encounter.reinforcement_experience = 4
	return encounter


func _def(id: StringName, side: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"attack": 1.0, &"speed": 5.0 if side == &"side_a" else 1.0}
	def.level_curve = LevelCurve.new()
	if side == &"side_b":
		def.brain = BattleBrain.new()
	return def
