class_name BarrageRun
extends PowerExecutor
## Runs an M1 barrage (C6.7) on one fighter. Its settings are a `BarrageMechanism`; read its
## header for the patterns, the shots and the beam.
##
## IN PLAIN WORDS, IN THE FIELD: using the power picks who to aim at (`aim_of`), fires the first
## shot at once, and fires the rest one every `interval` seconds as time passes (`tick`). Each
## shot is a `Projectile` added to the world where the pattern says (`spot`), flying the way the
## pattern says, homing on the target when the barrage turns. Using the power again starts a new
## volley; the kit coming off stops the volley, but shots already flying finish their flight.
##
## IN A BATTLE (the user is not `real_time`): nothing flies. The barrage lands its hits at once,
## each on a foe picked at random from the standing ones it was given, with the shot's numbers:
## its skill through `SkillUse.apply`, or else `hits` plain hits of its `power` and element, each
## landed one chipping a matching weakness, as a battle ATTACK does.
##
## The number of shots is `count` times the power's COUNT scaling (`PowerUse.multiplier`), so a
## barrage can grow with a gauge, the hour or the user's wounds.
##
## OWNS: one volley on one fighter, and where each shot of a pattern starts.
## MUST NOT: resolve a hit itself (`Hurtbox.take`, `Combatant.hit` and `SkillUse` do), or name a
## character.

## How high above a fighter's feet a shot aims: about the chest.
const CHEST: float = 1.0

var _user: Combatant
var _aim: Combatant
var _rng: RandomNumberGenerator
## The shots of this volley, how many have been fired, and the seconds until the next one.
var _total: int = 0
var _fired: int = 0
var _wait: float = 0.0
## A shot given an element of `elements`, made once: "<shot id>/<element>" -> its copy.
var _elemental: Dictionary[String, ActionMove] = {}


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var barrage: BarrageMechanism = mechanism as BarrageMechanism
	var first: Combatant = targets[0] if not targets.is_empty() else null
	var scaled: float = PowerUse.multiplier(user, power, PowerScaling.Affects.COUNT, first) \
			if power != null else 1.0
	var shots: int = maxi(1, roundi(barrage.count * scaled))
	_rng = rng
	if not user.real_time:
		_battle(user, targets, shots)
		return
	_user = user
	_aim = aim_of(user, targets)
	_total = shots
	_fired = 0
	_wait = 0.0
	_fire_due()


func tick(amount: float) -> void:
	if _user == null or _fired >= _total:
		return
	_wait -= amount
	_fire_due()


func end() -> void:
	_user = null
	_total = 0
	_fired = 0


## Who a field barrage aims at: the first standing one of `targets`, else the fighter the user's
## lock-on holds, else the nearest foe. Null when there is nobody to aim at.
static func aim_of(user: Combatant, targets: Array[Combatant]) -> Combatant:
	for target: Combatant in targets:
		if _standing(target):
			return target
	var body: Node3D = user.get_parent() as Node3D
	if body == null:
		return null
	for child: Node in body.get_children():
		var lock: LockOn = child as LockOn
		if lock != null and lock.target != null and _standing(lock.target.fighter()):
			return lock.target.fighter()
	var nearest: Hurtbox = Hurtbox.nearest_hostile(body)
	return nearest.fighter() if nearest != null else null


## Where shot `i` of `n` starts, and which way it faces (its -z), for a barrage fired from the
## feet at `from` toward the feet at `at`. See `BarrageMechanism` for each pattern.
static func spot(pattern: BarrageMechanism.Pattern, i: int, n: int, from: Vector3, at: Vector3,
		radius: float, height: float, rng: RandomNumberGenerator) -> Transform3D:
	var forward: Vector3 = Vector3(at.x - from.x, 0.0, at.z - from.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	# Where along the pattern this shot sits, from -1 to 1; 0 for a single shot.
	var across: float = 0.0 if n <= 1 else float(i) / float(n - 1) * 2.0 - 1.0
	var target: Vector3 = at + Vector3.UP * CHEST
	var origin: Vector3 = from + Vector3.UP * CHEST
	var way: Vector3 = Vector3.ZERO
	match pattern:
		BarrageMechanism.Pattern.RING_BEHIND_USER:
			var angle: float = across * PI * 0.4
			origin = from - forward * 0.5 + right * radius * sin(angle) \
					+ Vector3.UP * (CHEST + 0.5 + radius * cos(angle))
			way = target - origin
		BarrageMechanism.Pattern.RING_AROUND_TARGET:
			var round_angle: float = TAU * float(i) / float(maxi(1, n))
			origin = target + (right * cos(round_angle) + forward * sin(round_angle)) * radius
			way = target - origin
		BarrageMechanism.Pattern.RAIN:
			var turn: float = rng.randf() * TAU
			var reach: float = sqrt(rng.randf()) * radius
			origin = at + (right * cos(turn) + forward * sin(turn)) * reach + Vector3.UP * height
			way = Vector3.DOWN
		BarrageMechanism.Pattern.LINE:
			way = target - origin
		BarrageMechanism.Pattern.FROM_GROUND:
			origin = at + forward * across * radius * 0.5
			way = Vector3.UP
	if way.length_squared() < 0.0001:
		way = forward
	way = way.normalized()
	var up: Vector3 = Vector3.FORWARD if absf(way.y) > 0.99 else Vector3.UP
	return Transform3D(Basis.looking_at(way, up), origin)


# Fires every shot whose time has come.
func _fire_due() -> void:
	var barrage: BarrageMechanism = mechanism as BarrageMechanism
	while _fired < _total and _wait <= 0.0:
		_fire(_fired)
		_fired += 1
		_wait += barrage.interval


# Fires shot `i` of the volley into the world.
func _fire(i: int) -> void:
	var barrage: BarrageMechanism = mechanism as BarrageMechanism
	var body: Node3D = _user.get_parent() as Node3D if is_instance_valid(_user) else null
	if body == null or not body.is_inside_tree() or body.get_parent() == null:
		return
	if _aim != null and (not is_instance_valid(_aim) or not _standing(_aim)):
		_aim = null
	var aimed: Node3D = _aim.get_parent() as Node3D if _aim != null else null
	var at: Vector3 = aimed.global_position if aimed != null \
			else body.global_position + _forward(body) * 6.0
	var start: Transform3D = spot(barrage.pattern, i, _total, body.global_position, at,
			barrage.radius, barrage.height, _rng)
	var shot := Projectile.new()
	shot.attacker = _user
	shot.rng = _rng
	shot.speed = barrage.speed
	shot.turn_rate = barrage.turn_rate
	shot.homing_at = aimed
	shot.pierce = barrage.pierce
	shot.launch(_shot(i))
	body.get_parent().add_child(shot)
	shot.global_transform = start
	shot.direction = -start.basis.z


# A battle barrage: `count` hits at once, each on a standing foe from `targets` at random.
func _battle(user: Combatant, targets: Array[Combatant], count: int) -> void:
	for i: int in count:
		var foes: Array[Combatant] = []
		for target: Combatant in targets:
			if target != user and _standing(target):
				foes.append(target)
		if foes.is_empty():
			return
		var shot: ActionMove = _shot(i)
		var foe: Combatant = foes[_rng.randi() % foes.size()]
		if shot.skill != null:
			SkillUse.apply(user, shot.skill, [foe], _rng)
			continue
		var element: StringName = user.strike_element(shot.element)
		var keys: Array[StringName] = [element]
		keys.append_array(user.strike_tags())
		for hit: int in maxi(1, shot.hits):
			var result: DamageResult = user.hit(foe, shot.power, element, _rng)
			if result != null and not result.missed and not result.blocked:
				Weakness.strike(foe, keys)


# Shot `i` of the volley: the shots in turn, each given a random element of `elements` when
# there are any. A shot that is a skill keeps the skill's own element.
func _shot(i: int) -> ActionMove:
	var barrage: BarrageMechanism = mechanism as BarrageMechanism
	var shot: ActionMove = barrage.shots[i % barrage.shots.size()]
	if barrage.elements.is_empty() or shot.skill != null:
		return shot
	var element: StringName = barrage.elements[_rng.randi() % barrage.elements.size()]
	var key: String = "%d/%s" % [shot.get_instance_id(), element]
	if not _elemental.has(key):
		var copy: ActionMove = shot.duplicate() as ActionMove
		copy.element = element
		_elemental[key] = copy
	return _elemental[key]


# Which way the user faces: its fighter's `facing`, else its body's -z.
static func _forward(body: Node3D) -> Vector3:
	for child: Node in body.get_children():
		var fighter: ActionFighter = child as ActionFighter
		if fighter != null:
			return fighter.facing
	return -body.global_basis.z


static func _standing(fighter: Combatant) -> bool:
	if fighter == null:
		return false
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	return vitals != null and not vitals.is_defeated()
