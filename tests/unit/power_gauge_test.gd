extends TestCase
## Kit gauges (C6.4a): a kit's `GaugeRule`s move its gauge pools as time passes (seconds in the
## field, turns in a battle, standing or moving) and as its fighter lands a hit, takes one,
## dodges or misses; fractions wait for a whole point; a rule is paused by a status carrying one
## of its `blocked_by_tags`; a `regen_<pool>` stat fills a gauge by the second in the field; the
## status of the level a gauge has reached is held, whoever moved the pool; and a fallen fighter's
## gauges stand still.
##
## OWNS: assertions about `GaugeRule`, `KitGauges` and the gauges in `PowerSet`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const ME: StringName = &"fixture_gauge_hero"
const FOE: StringName = &"fixture_gauge_foe"
const LOW: StringName = &"status/fixture_gauge_low"
const HIGH: StringName = &"status/fixture_gauge_high"

var _body: CharacterBody3D
var _vitals: Vitals
var _statuses: StatusSet
var _powers: PowerSet


func run() -> void:
	plan(19)
	Flags.clear_all()
	_shapes()
	_build()
	_time()
	_events()
	_levels()
	_blocked_and_regen()
	_fallen_and_battle()
	_powers.equip(null)
	equal("taking the kit off drops its level status and its gauges",
		[_statuses.stacks(LOW) + _statuses.stacks(HIGH), _powers.gauges.pools().size()], [0, 0])
	_body.free()
	CombatClock.reset()
	Flags.clear_all()


func _shapes() -> void:
	equal("a clean kit with gauges has no problems", _kit().problems("fixture").size(), 0)
	var bad := _kit()
	var rule := GaugeRule.new()
	rule.levels = {-1: null}
	bad.gauges = [rule, null]
	equal("a gauge with no pool, a level below 0, an empty level, and an empty gauge are problems",
		bad.problems("fixture").size(), 4)
	var lone := GaugeRule.new()
	lone.levels = {30: _status(LOW, []), 60: _status(HIGH, [])}
	equal("the level reached is the highest at or below the points",
		[lone.level_at(29), lone.level_at(30).id, lone.level_at(99).id], [null, LOW, HIGH])


func _build() -> void:
	_body = CharacterBody3D.new()
	_vitals = Vitals.new()
	_body.add_child(_vitals)
	_statuses = StatusSet.new()
	_body.add_child(_statuses)
	var fighter := Combatant.new()
	fighter.combatant_id = ME
	fighter.faction = &"party"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 50.0, &"attack": 5.0, &"defence": 1.0}
	_body.add_child(fighter)
	_powers = PowerSet.new()
	_body.add_child(_powers)
	attach(_body)
	_powers.equip(_kit())
	equal("each gauge starts empty and moves no level", [_focus(), _arts(), _statuses.stacks(LOW)],
		[0, 0, 0])


func _time() -> void:
	_powers.tick_seconds(1.0)
	equal("a second standing still adds per_second and per_idle_second", [_focus(), _arts()], [7, 7])
	for _i: int in 10:
		_powers.tick_seconds(0.1)
	equal("ten tenths of a second add the same as one whole second", [_focus(), _arts()], [14, 14])
	_body.velocity = Vector3(3.0, 0.0, 0.0)
	_powers.tick_seconds(1.0)
	_body.velocity = Vector3.ZERO
	equal("a second moving adds per_second and per_moving_second (a drain)", _focus(), 13)
	CombatClock.set_scale(0.0)
	_powers._physics_process(1.0)
	CombatClock.reset()
	equal("a stopped fight moves no gauge", _focus(), 13)


func _events() -> void:
	Events.combatant_damaged.emit(FOE, ME, 5, false)
	equal("a hit landed adds on_hit_dealt", _focus(), 23)
	Events.combatant_damaged.emit(FOE, ME, -5, false)
	Events.combatant_damaged.emit(FOE, &"someone_else", 5, false)
	equal("a heal, and another fighter's hit, add nothing", _focus(), 23)
	Events.attack_dodged.emit(ME, FOE)
	equal("a dodge adds on_dodge, and reaching a level holds its status",
		[_focus(), _statuses.stacks(LOW), _statuses.stacks(HIGH)], [48, 1, 0])
	Events.combatant_damaged.emit(ME, FOE, 3, false)
	Events.attack_missed.emit(FOE, ME)
	equal("a hit taken and a miss of the holder's own drain", _focus(), 18)


func _levels() -> void:
	_vitals.change(&"focus", 42)
	equal("the next level replaces the one below", [_statuses.stacks(LOW), _statuses.stacks(HIGH)],
		[0, 1])
	_vitals.change(&"focus", -45)
	equal("spending the gauge by any path drops its level", [_focus(), _statuses.stacks(LOW),
		_statuses.stacks(HIGH)], [15, 0, 0])


func _blocked_and_regen() -> void:
	_statuses.apply(_status(&"status/fixture_gauge_ailment", [&"ailment"]))
	_powers.tick_seconds(1.0)
	equal("a status with a blocking tag pauses only the rule it blocks", [_focus(), _arts()], [22, 21])
	_statuses.cure(&"status/fixture_gauge_ailment")
	var fed := _status(&"status/fixture_gauge_fed", [])
	fed.modifiers = [StatModifier.of(&"regen_arts", StatModifier.Op.ADD, 10.0, &"fixture")]
	_statuses.apply(fed)
	_powers.tick_seconds(1.0)
	equal("a regen stat fills a gauge pool by the second, beside its rule", _arts(), 38)


func _fallen_and_battle() -> void:
	_vitals.set_to(&"hp", 0)
	_powers.tick_seconds(1.0)
	Events.attack_dodged.emit(ME, FOE)
	equal("a fallen fighter's gauges stand still", [_focus(), _arts()], [29, 38])
	_vitals.revive(10)
	_powers.tick_turn()
	equal("a battle turn adds per_turn only", [_focus(), _arts()], [36, 38])


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_gauges"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"max_focus", StatModifier.Op.ADD, 100.0, &"any"),
		StatModifier.of(&"start_focus", StatModifier.Op.ADD, 0.0, &"any"),
		StatModifier.of(&"max_arts", StatModifier.Op.ADD, 100.0, &"any"),
		StatModifier.of(&"start_arts", StatModifier.Op.ADD, 0.0, &"any")]
	var focus := GaugeRule.new()
	focus.pool = &"focus"
	focus.per_second = 2.0
	focus.per_idle_second = 5.0
	focus.per_moving_second = -3.0
	focus.per_turn = 7.0
	focus.on_hit_dealt = 10.0
	focus.on_hit_taken = -20.0
	focus.on_dodge = 25.0
	focus.on_miss = -10.0
	focus.levels = {30: _status(LOW, []), 60: _status(HIGH, [])}
	var arts := GaugeRule.new()
	arts.pool = &"arts"
	arts.per_second = 7.0
	arts.blocked_by_tags = [&"ailment"]
	kit.gauges = [focus, arts]
	return kit


func _status(id: StringName, tags: Array[StringName]) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = 0.0
	status.tags = tags
	return status


func _focus() -> int:
	return _vitals.current(&"focus")


func _arts() -> int:
	return _vitals.current(&"arts")
