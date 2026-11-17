extends TestCase
## Sacrifice and refresh (C6.12b): the M11 and M14 shapes and their problems; a sacrifice takes
## a share of each near ally's HP (never the last point) and their buffs, and puts its gain on
## the user; a refresh cuts the user's cooldowns, or its allies' too, rounded down to whole
## turns in a battle, fills a pool and puts a speed status on; and a `cooldown_rate` stat makes
## `PowerSet` count cooldowns down faster.
##
## OWNS: assertions about `SacrificeMechanism`, `SacrificeRun`, `RefreshMechanism`, `RefreshRun`
## and the `cooldown_rate` read in `PowerSet`.
## MUST NOT: name a game's kits, powers or characters.

const BUFF: StringName = &"status/fixture_sacrifice_buff"
const OTHER: StringName = &"status/fixture_sacrifice_other"
const GAIN: StringName = &"status/fixture_sacrifice_gain"
const SPEED: StringName = &"status/fixture_refresh_speed"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _near: Combatant
var _far: Combatant
var _foe: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(10)
	Flags.clear_all()
	_rng.seed = 3
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_sacrifice_me", &"player", Vector3.ZERO, _kit())
	_near = _fighter(&"fixture_sacrifice_near", &"player", Vector3(2.0, 0.0, 0.0), _other_kit())
	_far = _fighter(&"fixture_sacrifice_far", &"player", Vector3(40.0, 0.0, 0.0), _other_kit())
	_foe = _fighter(&"fixture_sacrifice_foe", &"enemy", Vector3(1.0, 0.0, 0.0), null)
	_sacrifice()
	_refresh()
	_rate_and_turns()
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var sacrifice := SacrificeMechanism.new()
	var refresh := RefreshMechanism.new()
	equal("the kinds are sacrifice and refresh, the base runs both, and clean ones have no problems",
		[sacrifice.kind(), refresh.kind(), PowerMechanisms.make(sacrifice) is SacrificeRun,
			PowerMechanisms.make(refresh) is RefreshRun, sacrifice.problems("f").size(), refresh.problems("f").size()],
		[&"sacrifice", &"refresh", true, true, 0, 0])
	sacrifice.fraction = 0.0
	sacrifice.radius = -1.0
	refresh.fraction = 0.0
	refresh.pool_gain = 2
	equal("taking nothing, a negative radius, and points with no pool are problems",
		[sacrifice.problems("f").size(), refresh.problems("f").size()], [2, 1])


func _sacrifice() -> void:
	_hp_to(_me, 50)
	_hp_to(_near, 1)
	_use("give")
	equal("an ally at its last point gives nothing", [_hp(_near), _hp(_me)], [1, 50])
	_hp_to(_near, 100)
	var near_statuses: StatusSet = StatusSet.of(_near.get_parent())
	near_statuses.apply(_status(BUFF, [&"buff"], null))
	near_statuses.apply(_status(OTHER, [], null))
	_use("give")
	equal("a sacrifice takes its share of each near ally's HP, and none from far allies or foes",
		[_hp(_near), _hp(_far), _hp(_foe), _hp(_me)], [70, 100, 100, 80])
	var mine: StatusSet = StatusSet.of(_me.get_parent())
	equal("the near ally's buffs go to the user, its other statuses stay, and the gain goes on",
		[near_statuses.stacks(BUFF), near_statuses.stacks(OTHER), mine.stacks(BUFF), mine.stacks(GAIN)],
		[0, 1, 1, 1])


func _refresh() -> void:
	var mine: PowerSet = PowerSet.of(_me.get_parent())
	var theirs: PowerSet = PowerSet.of(_near.get_parent())
	mine.start_cooldown(_powers["slow"])
	theirs.start_cooldown(_powers["slow_other"])
	_use("self")
	equal("a refresh of the user halves its cooldowns and leaves its allies'",
		[mine.cooldown_left(&"power/fixture_refresh_slow"), theirs.cooldown_left(&"power/fixture_refresh_slow_other")],
		[5.0, 10.0])
	var far: PowerSet = PowerSet.of(_far.get_parent())
	far.start_cooldown(_powers["slow_other"])
	Vitals.of(_me.get_parent()).set_to(&"mp", 0)
	_use("allies")
	equal("a refresh of the side cuts each near ally's cooldowns and puts speed on them, not on far ones",
		[theirs.cooldown_left(&"power/fixture_refresh_slow_other"), far.cooldown_left(&"power/fixture_refresh_slow_other"),
			StatusSet.of(_near.get_parent()).stacks(SPEED), StatusSet.of(_far.get_parent()).stacks(SPEED)],
		[5.0, 10.0, 1, 0])
	equal("a refresh fills the user's pool", Vitals.of(_me.get_parent()).current(&"mp"), 4)


func _rate_and_turns() -> void:
	var theirs: PowerSet = PowerSet.of(_near.get_parent())
	var before: float = theirs.cooldown_left(&"power/fixture_refresh_slow_other")
	theirs.tick_seconds(1.0)
	var none: PowerSet = PowerSet.of(_far.get_parent())
	none.tick_seconds(1.0)
	equal("a cooldown_rate of +1 counts cooldowns down twice as fast; without it, at the normal pace",
		[before - theirs.cooldown_left(&"power/fixture_refresh_slow_other"),
			10.0 - none.cooldown_left(&"power/fixture_refresh_slow_other"), RefreshRun.rate(_far)],
		[2.0, 1.0, 1.0])
	var mine: PowerSet = PowerSet.of(_me.get_parent())
	mine.cut_cooldowns(0.0, 1.0)
	_powers["slow"].cooldown = 3.0
	mine.start_cooldown(_powers["slow"])
	_me.real_time = false
	mine.executor(&"power/fixture_refresh_self").use(_me, [], _rng)
	_me.real_time = true
	equal("in a battle a cut cooldown is rounded down to whole turns",
		mine.cooldown_left(&"power/fixture_refresh_slow"), 1.0)


func _kit() -> PowerKit:
	var give := SacrificeMechanism.new()
	give.fraction = 0.3
	give.take_buffs = true
	give.radius = 10.0
	give.gain = _status(GAIN, [], null)
	var mine := RefreshMechanism.new()
	var side := RefreshMechanism.new()
	side.scope = RefreshMechanism.Scope.ALLIES
	side.radius = 10.0
	side.pool = &"mp"
	side.pool_gain = 4
	side.speed = _status(SPEED, [], StatModifier.of(RefreshRun.RATE, StatModifier.Op.ADD, 1.0, &""))
	var slow: Power = _power("slow", null)
	slow.cooldown = 10.0
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_sacrifice"
	kit.powers = [_power("give", give), _power("self", mine), _power("allies", side), slow]
	return kit


func _other_kit() -> PowerKit:
	var slow: Power = _powers["slow_other"] if _powers.has("slow_other") else _power("slow_other", null)
	slow.cooldown = 10.0
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_sacrifice_other"
	kit.powers = [slow]
	return kit


func _status(id: StringName, tags: Array[StringName], modifier: StatModifier) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 30.0
	status.tags = tags
	if modifier != null:
		status.modifiers = [modifier]
	return status


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_refresh_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 20.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, 12.0)


func _hp_to(fighter: Combatant, amount: int) -> void:
	Vitals.of(fighter.get_parent()).set_to(&"hp", amount)


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")
