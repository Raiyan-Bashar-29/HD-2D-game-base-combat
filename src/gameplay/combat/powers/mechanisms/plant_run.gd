class_name PlantRun
extends PowerExecutor
## Runs an M15 plant (C6.26) on one fighter. Its settings are a `PlantMechanism`; read its header
## for where plants go, the four triggers and the battle's marks.
##
## IN PLAIN WORDS, IN THE FIELD: using the power puts `count` `Planted` nodes in the world (or,
## for a REMOTE plant with plants already standing, sets them all off instead, one after another
## `chain_delay` apart). A plant that waits for WHERE_PROJECTILES_LAND is put down each time a
## shot of this fighter's barrage ends its flight without striking (`projectile_landed`). The
## standing plants are kept in planting order; past `max_standing` the oldest is lost. The kit
## coming off removes the plants still waiting; an eruption already going finishes.
##
## IN A BATTLE (the user is not `real_time`): a plant is the `mark` status on a foe. Using the
## power marks foes at random, or sets every mark off for REMOTE. TIMER counts the user's turns;
## PROXIMITY and ON_HIT listen for the marked foe dealing or taking damage. Going off, a foe
## takes the eruption once per mark (`BarrageRun.strike_with`) and loses its marks.
##
## OWNS: one fighter's standing plants and marked foes.
## MUST NOT: resolve a hit itself, or name a character.

var _user: Combatant
var _rng: RandomNumberGenerator
## The field plants, oldest first.
var _plants: Array[Planted] = []
## The battle's marked foes, and the user's turns left before a TIMER mark goes off.
var _marked: Array[Combatant] = []
var _turns_left: int = 0


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	_user = user
	_rng = rng
	var remote: bool = plant.trigger == PlantMechanism.Trigger.REMOTE
	if not user.real_time:
		if remote and not _marked.is_empty():
			_burst_all()
		elif plant.where != PlantMechanism.Where.WHERE_PROJECTILES_LAND:
			_mark_among(targets, _count(targets))
		return
	if remote and not standing().is_empty():
		set_off_all()
	elif plant.where != PlantMechanism.Where.WHERE_PROJECTILES_LAND:
		_plant_from(targets)


func power_used(used: Power) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	if plant.trigger != PlantMechanism.Trigger.REMOTE or not plant.set_off_by.has(used.power_id):
		return
	if _holder_user() != null and not _holder_user().real_time:
		_burst_all()
	else:
		set_off_all()


func projectile_landed(at: Vector3, near: Combatant) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	if plant.where != PlantMechanism.Where.WHERE_PROJECTILES_LAND or _holder_user() == null:
		return
	_user = _holder_user()
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	if near != null:
		_mark(near)
	else:
		_plant_at(at)


func tick(amount: float) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	if _marked.is_empty() or plant.trigger != PlantMechanism.Trigger.TIMER:
		return
	if _user != null and not _user.real_time:
		_turns_left -= roundi(amount)
		if _turns_left <= 0:
			_burst_all()


func end() -> void:
	for planted: Planted in standing():
		planted.queue_free()
	_plants.clear()
	_marked.clear()
	_listen(false)


## The plants still waiting to go off, oldest first.
func standing() -> Array[Planted]:
	var out: Array[Planted] = []
	for planted: Planted in _plants:
		if is_instance_valid(planted) and planted.armed():
			out.append(planted)
	_plants = out.duplicate()
	return out


## Sets every waiting plant off, each `chain_delay` seconds after the one before.
func set_off_all() -> void:
	var delay: float = 0.0
	for planted: Planted in standing():
		planted.set_off(delay)
		delay += (mechanism as PlantMechanism).chain_delay


# How many plants one use makes: `count` times the power's COUNT scaling.
func _count(targets: Array[Combatant]) -> int:
	var first: Combatant = targets[0] if not targets.is_empty() else null
	var scaled: float = PowerUse.multiplier(_user, power, PowerScaling.Affects.COUNT, first) \
			if power != null else 1.0
	return maxi(1, roundi((mechanism as PlantMechanism).count * scaled))


# A field use: `count` plants spaced along the line from the user through the spot `where` names.
func _plant_from(targets: Array[Combatant]) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	var body: Node3D = _user.get_parent() as Node3D
	if body == null or not body.is_inside_tree():
		return
	var at: Vector3 = body.global_position
	if plant.where == PlantMechanism.Where.AHEAD:
		at += BarrageRun.facing_of(body) * plant.distance
	elif plant.where == PlantMechanism.Where.AT_TARGET:
		var aim: Combatant = BarrageRun.aim_of(_user, targets)
		var aimed: Node3D = aim.get_parent() as Node3D if aim != null else null
		at = aimed.global_position if aimed != null \
				else at + BarrageRun.facing_of(body) * plant.distance
	var n: int = _count(targets)
	for i: int in n:
		_plant_at(BarrageRun.spot(BarrageMechanism.Pattern.FROM_GROUND, i, n, body.global_position,
				at, plant.spread * maxf(1.0, n - 1.0), 0.0, _rng).origin)


# Puts one plant at `at`, losing the oldest past `max_standing`.
func _plant_at(at: Vector3) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	var body: Node3D = _user.get_parent() as Node3D if is_instance_valid(_user) else null
	if body == null or not body.is_inside_tree() or body.get_parent() == null:
		return
	var planted := Planted.new()
	planted.attacker = _user
	planted.rng = _rng
	planted.trigger = plant.trigger
	planted.radius = plant.radius
	planted.seconds = plant.seconds
	planted.life = plant.lifetime
	planted.plant(plant.eruption)
	body.get_parent().add_child(planted)
	planted.global_position = at
	_plants.append(planted)
	var waiting: Array[Planted] = standing()
	if waiting.size() > plant.max_standing:
		waiting[0].queue_free()
		_plants.erase(waiting[0])


# A battle use: `n` marks, each on a standing foe from `targets` at random.
func _mark_among(targets: Array[Combatant], n: int) -> void:
	var foes: Array[Combatant] = []
	for target: Combatant in targets:
		if target != _user and BarrageRun.standing(target):
			foes.append(target)
	if foes.is_empty():
		return
	for i: int in n:
		_mark(foes[_rng.randi() % foes.size()])


# Puts one mark on `foe`.
func _mark(foe: Combatant) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	var statuses: StatusSet = StatusSet.of(foe.get_parent())
	if statuses == null or plant.mark == null or not statuses.apply(plant.mark):
		return
	if not _marked.has(foe):
		_marked.append(foe)
	_turns_left = plant.turns
	_listen(plant.trigger == PlantMechanism.Trigger.PROXIMITY or plant.trigger == PlantMechanism.Trigger.ON_HIT)


func _burst_all() -> void:
	for foe: Combatant in _marked.duplicate():
		_burst(foe)


# Sets off every mark on `foe`: they are gone, and it takes the eruption once for each.
func _burst(foe: Combatant) -> void:
	var plant: PlantMechanism = mechanism as PlantMechanism
	_marked.erase(foe)
	if _marked.is_empty():
		_listen(false)
	if not is_instance_valid(foe):
		return
	var statuses: StatusSet = StatusSet.of(foe.get_parent())
	var marks: int = statuses.stacks(plant.mark.id) if statuses != null else 0
	if statuses != null:
		statuses.cure(plant.mark.id)
	for i: int in marks:
		if is_instance_valid(_user) and BarrageRun.standing(foe):
			BarrageRun.strike_with(_user, foe, plant.eruption, _rng)


# Listens, or stops listening, for a marked foe dealing or taking damage.
func _listen(on: bool) -> void:
	var listening: bool = Events.combatant_damaged.is_connected(_on_damaged)
	if on and not listening:
		Events.combatant_damaged.connect(_on_damaged)
	elif not on and listening:
		Events.combatant_damaged.disconnect(_on_damaged)


func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	var proximity: bool = (mechanism as PlantMechanism).trigger == PlantMechanism.Trigger.PROXIMITY
	var watched: StringName = by if proximity else who
	if amount <= 0:
		return
	for foe: Combatant in _marked.duplicate():
		if is_instance_valid(foe) and foe.combatant_id == watched:
			_burst(foe)


func _holder_user() -> Combatant:
	return Combatant.of(holder.get_parent()) if holder != null and holder.get_parent() != null else null
