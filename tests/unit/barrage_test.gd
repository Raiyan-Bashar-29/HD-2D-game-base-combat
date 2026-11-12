extends TestCase
## Barrages (C6.7): the M1 shape and its problems; where each pattern puts a shot and which way
## it faces; in the field a volley fires one shot at once and the rest over time, each a
## `Projectile` that flies, strikes once, ends on its first strike unless it pierces, ends after
## its flight, homes, freezes with the fight clock, refuses an ally, carries a drawn element to a
## weakness, and grows with COUNT scaling; and a beam strikes a row of foes where it stands. The
## battle reading is `barrage_battle_test`.
##
## OWNS: assertions about `BarrageMechanism`, `BarrageRun` and `Projectile` in the field.
## MUST NOT: name a game's kits, powers or characters, or wait for physics frames.

const NOON: float = 12.0

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _foe: Combatant
var _far: Combatant
var _ally: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(20)
	Flags.clear_all()
	_rng.seed = 7
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_spots()
	_me = _fighter(&"fixture_barrage_me", &"player", Vector3.ZERO, _kit())
	_foe = _fighter(&"fixture_barrage_foe", &"enemy", Vector3(0.0, 0.0, -6.0), null)
	_far = _fighter(&"fixture_barrage_far", &"enemy", Vector3(0.0, 0.0, -9.0), null)
	_ally = _fighter(&"fixture_barrage_ally", &"player", Vector3(2.0, 0.0, 0.0), null)
	_volley()
	_flight()
	_homing_and_clock()
	_elements_and_count()
	_beam()
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var barrage: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 3, 0.5)
	equal("a barrage's kind is barrage, the base runs it, it aims at foes, and a clean one has no problems",
		[barrage.kind(), PowerMechanisms.make(barrage) is BarrageRun, barrage.aims_at_foes(),
			FormMechanism.new().aims_at_foes(), barrage.problems("fixture").size()],
		[&"barrage", true, true, false, 0])
	barrage.count = 0
	barrage.speed = -1.0
	barrage.shots = []
	equal("no shots, fewer than one, and a negative speed are problems", barrage.problems("fixture").size(), 3)
	var broken := ActionMove.new()
	broken.power = 3.0
	broken.active = 0.0
	barrage.count = 1
	barrage.speed = 1.0
	barrage.shots = [broken, null]
	equal("a shot's own problem and an empty shot are the barrage's", barrage.problems("fixture").size(), 2)


func _spots() -> void:
	var at := Vector3(0.0, 0.0, -10.0)
	var chest := Vector3.UP * BarrageRun.CHEST
	var behind: Transform3D = BarrageRun.spot(BarrageMechanism.Pattern.RING_BEHIND_USER, 1, 3,
		Vector3.ZERO, at, 1.5, 6.0, _rng)
	equal("behind the user: above it and behind, facing the target",
		[behind.origin.z > 0.0, behind.origin.y > BarrageRun.CHEST, _facing(behind).z < -0.9], [true, true, true])
	var ring: Transform3D = BarrageRun.spot(BarrageMechanism.Pattern.RING_AROUND_TARGET, 1, 4,
		Vector3.ZERO, at, 2.0, 6.0, _rng)
	equal("around the target: on the circle, facing in",
		[snappedf(ring.origin.distance_to(at + chest), 0.01),
			_facing(ring).dot((at + chest - ring.origin).normalized()) > 0.99], [2.0, true])
	var rain: Transform3D = BarrageRun.spot(BarrageMechanism.Pattern.RAIN, 0, 5, Vector3.ZERO, at, 2.0, 6.0, _rng)
	equal("rain: at height, within the radius, facing down",
		[rain.origin.y, Vector2(rain.origin.x, rain.origin.z + 10.0).length() <= 2.0, _facing(rain).y < -0.99],
		[6.0, true, true])
	var line: Transform3D = BarrageRun.spot(BarrageMechanism.Pattern.LINE, 0, 1, Vector3.ZERO, at, 2.0, 6.0, _rng)
	equal("a line: from the user's chest, facing the target",
		[line.origin, _facing(line).z < -0.99], [chest, true])
	var ground: Array[float] = []
	for i: int in 3:
		var spike: Transform3D = BarrageRun.spot(BarrageMechanism.Pattern.FROM_GROUND, i, 3,
			Vector3.ZERO, at, 4.0, 6.0, _rng)
		ground.append(snappedf(spike.origin.z, 0.01))
		ground.append(snappedf(spike.origin.y + _facing(spike).y, 0.01))
	equal("from the ground: along the line through the target, on the ground, facing up",
		ground, [-8.0, 1.0, -10.0, 1.0, -12.0, 1.0])


func _volley() -> void:
	equal("a field barrage is used, and its first shot flies at once",
		[_use("line"), _live().size()], [true, 1])
	PowerSet.of(_me.get_parent()).tick_seconds(0.5)
	var second: int = _live().size()
	PowerSet.of(_me.get_parent()).tick_seconds(2.0)
	equal("the rest follow one every interval, and no more than the count",
		[second, _live().size()], [2, 3])
	equal("with nobody given, it aims at the nearest foe", BarrageRun.aim_of(_me, []), _foe)
	_clear()


func _flight() -> void:
	_use("line")
	var shot: Projectile = _live()[0]
	var start: float = shot.global_position.z
	shot.fly(0.1)
	equal("a shot flies toward its target", snappedf(start - shot.global_position.z, 0.01), 1.0)
	equal("an ally in its way is not struck", [shot.strike(_hurtbox(_ally)), _hp(_ally)], [false, 100])
	equal("it strikes the foe, hurting it, and is gone after its first strike",
		[shot.strike(_hurtbox(_foe)), _hp(_foe) < 100, shot.gone()], [true, true, true])
	_clear()
	_use("line")
	var long: Projectile = _live()[0]
	long.fly(3.0)
	equal("a shot that strikes nothing is gone after its flight", long.gone(), true)
	_clear()


func _homing_and_clock() -> void:
	_use("homing")
	var shot: Projectile = _live()[0]
	(_foe.get_parent() as Node3D).position = Vector3(6.0, 0.0, -6.0)
	var before: float = shot.direction.x
	shot.fly(0.2)
	equal("a homing shot turns toward a target that moved", shot.direction.x > before + 0.1, true)
	(_foe.get_parent() as Node3D).position = Vector3(0.0, 0.0, -6.0)
	var where: Vector3 = shot.global_position
	CombatClock.set_scale(0.0)
	shot._physics_process(0.5)
	equal("a stopped fight freezes a shot in the air", shot.global_position, where)
	CombatClock.reset()
	_clear()


func _elements_and_count() -> void:
	_foe.weak_to = [&"fixture_barrage_fire"]
	_pool(_foe, &"shield", 2)
	_use("fire")
	_live()[0].fly(0.01)
	_live()[0].strike(_hurtbox(_foe))
	equal("a drawn element finds the foe's weakness", Vitals.of(_foe.get_parent()).current(&"shield"), 1)
	_foe.weak_to = []
	_clear()
	_pool(_me, &"mp", 20)
	_use("grows")
	equal("COUNT scaling at a full pool doubles the shots", _live().size(), 6)
	_clear()


func _beam() -> void:
	_use("beam")
	var beam: Projectile = _live()[0]
	var where: Vector3 = beam.global_position
	beam.fly(0.01)
	equal("a beam does not move, and strikes every foe along its line",
		[beam.global_position, beam.strike(_hurtbox(_foe)), beam.strike(_hurtbox(_far)),
			_hp(_foe) < 100, _hp(_far) < 100, beam.gone()],
		[where, true, true, true, true, false])
	_clear()


func _kit() -> PowerKit:
	var line: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 3, 0.5)
	var homing: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 1, 0.0)
	homing.turn_rate = 4.0
	var fire: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 1, 0.0)
	fire.elements = [&"fixture_barrage_fire"]
	var grows: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 3, 0.0)
	var beam: BarrageMechanism = _barrage(BarrageMechanism.Pattern.LINE, 1, 0.0)
	beam.speed = 0.0
	beam.pierce = true
	var ray: ActionMove = _shot(4.0)
	ray.active = 0.1
	ray.hitbox_size = Vector3(0.5, 0.5, 12.0)
	ray.hitbox_offset = Vector3(0.0, 0.0, -6.0)
	beam.shots = [ray]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_barrage"
	kit.name_key = "fixture.kit"
	var growing: Power = _power("grows", grows)
	var rule := PowerScaling.new()
	rule.source = PowerScaling.Source.POOL_FRACTION
	rule.affects = PowerScaling.Affects.COUNT
	rule.pool = &"mp"
	growing.scaling = [rule]
	kit.powers = [_power("line", line), _power("homing", homing), _power("fire", fire), growing,
		_power("beam", beam)]
	return kit


func _barrage(pattern: BarrageMechanism.Pattern, count: int, interval: float) -> BarrageMechanism:
	var barrage := BarrageMechanism.new()
	barrage.pattern = pattern
	barrage.count = count
	barrage.interval = interval
	barrage.speed = 10.0
	barrage.shots = [_shot(5.0)]
	return barrage


func _shot(power: float) -> ActionMove:
	var shot := ActionMove.new()
	shot.startup = 0.0
	shot.active = 2.0
	shot.recovery = 0.0
	shot.power = power
	shot.hitbox_size = Vector3(0.5, 0.5, 0.5)
	shot.hitbox_offset = Vector3.ZERO
	return shot


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_barrage_" + short)
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
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 20.0, &"max_shield": 2.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	_pool(fighter, &"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


# The shots still flying.
func _live() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for node: Node in _world.get_children():
		var shot: Projectile = node as Projectile
		if shot != null and not shot.gone():
			out.append(shot)
	return out


# Removes every shot, puts every fighter's hp back, and lets every power be used again.
func _clear() -> void:
	for node: Node in _world.get_children():
		if node is Projectile:
			node.free()
	for fighter: Combatant in [_me, _foe, _far, _ally]:
		_pool(fighter, &"hp", 100)
	var powers: PowerSet = PowerSet.of(_me.get_parent())
	var kit: PowerKit = powers.kit
	powers.unequip()
	powers.equip(kit)


func _facing(at: Transform3D) -> Vector3:
	return -at.basis.z


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _pool(fighter: Combatant, pool: StringName, value: int) -> void:
	Vitals.of(fighter.get_parent()).set_to(pool, value)
