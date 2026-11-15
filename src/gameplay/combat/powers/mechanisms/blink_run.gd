class_name BlinkRun
extends PowerExecutor
## Runs an M9 blink (C6.12a) on one fighter. Its settings are a `BlinkMechanism`; read its
## header for where each `to` lands.
##
## IN PLAIN WORDS: in the field, using the power works out where the user lands, strikes the
## foes on the way when there is a `path_strike`, moves the body there with its speed cleared,
## ends its move when `cancels_recovery`, and puts `arrival` on it. In a battle it moves the
## user's turn sooner (or swaps two places in the turn order) and puts `arrival` on it.
## In the field a blink never passes a wall (C9.12): it stops short of it, and a swap across one
## moves nobody.
##
## OWNS: carrying out one blink.
## MUST NOT: resolve a hit itself (`Hurtbox.take` and `BarrageRun.strike_with` do), or name a
## character.


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var blink: BlinkMechanism = mechanism as BlinkMechanism
	var aim: Combatant = BarrageRun.aim_of(user, targets) if blink.aims_at_foes() else null
	if user.real_time:
		_field(user, aim, rng)
	else:
		_battle(user, aim, rng)
	var statuses: StatusSet = StatusSet.of(user.get_parent())
	if blink.arrival != null and statuses != null:
		statuses.apply(blink.arrival, rng, user.combatant_id)


## Where `body` lands for `blink`, given the aimed body (null for none), or `Vector3.INF`
## when it goes nowhere.
static func landing(blink: BlinkMechanism, body: Node3D, aimed: Node3D) -> Vector3:
	var here: Vector3 = body.global_position
	match blink.to:
		BlinkMechanism.To.FORWARD:
			return here + _flat(BarrageRun.facing_of(body)) * blink.distance
		BlinkMechanism.To.UP:
			return here + Vector3.UP * blink.height
	if aimed == null:
		return Vector3.INF
	var there: Vector3 = aimed.global_position
	if blink.to == BlinkMechanism.To.SWAP:
		return there
	var toward: Vector3 = _flat(there - here)
	if toward.length() < 0.001:
		toward = _flat(BarrageRun.facing_of(body))
	var side: float = 1.0 if blink.to == BlinkMechanism.To.BEHIND_TARGET else -1.0
	return there + toward * blink.distance * side


func _field(user: Combatant, aim: Combatant, rng: RandomNumberGenerator) -> void:
	var blink: BlinkMechanism = mechanism as BlinkMechanism
	var body: Node3D = user.get_parent() as Node3D
	var aimed: Node3D = aim.get_parent() as Node3D if aim != null else null
	if body == null or not body.is_inside_tree():
		return
	var from: Vector3 = body.global_position
	var to: Vector3 = _past_walls(blink, body, landing(blink, body, aimed))
	if not to.is_finite():
		return
	if blink.path_strike != null:
		for hurtbox: Hurtbox in _on_path(user, from, to):
			hurtbox.take(user, blink.path_strike, rng, from)
	body.global_position = to
	if blink.to == BlinkMechanism.To.SWAP and aimed != null:
		aimed.global_position = from
	_stop(body)
	if aimed != null and blink.to != BlinkMechanism.To.SWAP:
		_face(body, _flat(aimed.global_position - to))
	if blink.cancels_recovery:
		for child: Node in body.get_children():
			if child is Hurtbox and (child as Hurtbox).timeline != null:
				(child as Hurtbox).timeline.cancel()


# Walls (C9.12): a blink stops short of the first wall on its way, and a swap across a wall
# does not happen (`Vector3.INF`).
static func _past_walls(blink: BlinkMechanism, body: Node3D, to: Vector3) -> Vector3:
	if not to.is_finite():
		return to
	var lift: Vector3 = Vector3.UP * CombatSight.EYE
	var from: Vector3 = body.global_position + lift
	if blink.to == BlinkMechanism.To.SWAP:
		return Vector3.INF if CombatSight.wall_between(body, from, to + lift).is_finite() else to
	return CombatSight.short_of(body, from, to + lift) - lift


func _battle(user: Combatant, aim: Combatant, rng: RandomNumberGenerator) -> void:
	var blink: BlinkMechanism = mechanism as BlinkMechanism
	var queue: CtbScheduler = Battle.running.scheduler as CtbScheduler if Battle.running != null else null
	if queue != null and blink.to == BlinkMechanism.To.SWAP and aim != null:
		var mine: float = queue.wait_of(user.combatant_id)
		var theirs: float = queue.wait_of(aim.combatant_id)
		if is_finite(mine) and is_finite(theirs):
			queue.delay_by(user.combatant_id, theirs - mine)
			queue.delay_by(aim.combatant_id, mine - theirs)
	elif queue != null and blink.sooner > 0.0:
		queue.delay_by(user.combatant_id, -blink.sooner)
	if blink.path_strike != null and aim != null and user.can_target(aim, FactionTable.Target.ENEMY):
		BarrageRun.strike_with(user, aim, blink.path_strike, rng)


# The standing foes' hurtboxes within half the path's width of the line `from` to `to`.
func _on_path(user: Combatant, from: Vector3, to: Vector3) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	var half: float = (mechanism as BlinkMechanism).path_width / 2.0
	var line := Vector3(to.x - from.x, 0.0, to.z - from.z)
	for node: Node in user.get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		var foe: Combatant = hurtbox.fighter() if hurtbox != null else null
		if foe == null or not BarrageRun.standing(foe) or not user.can_target(foe, FactionTable.Target.ENEMY):
			continue
		var gap: Vector3 = hurtbox.global_position - from
		var spot := Vector3(gap.x, 0.0, gap.z)
		var along: float = clampf(spot.dot(line) / maxf(line.length_squared(), 0.0001), 0.0, 1.0)
		if spot.distance_to(line * along) <= half:
			found.append(hurtbox)
	return found


# The player's fighter faces `way`; any other body is turned to it.
static func _face(body: Node3D, way: Vector3) -> void:
	if way == Vector3.ZERO:
		return
	for child: Node in body.get_children():
		if child is ActionFighter:
			(child as ActionFighter).facing = way
			return
	body.look_at(body.global_position + way, Vector3.UP)


static func _stop(body: Node3D) -> void:
	var moving: CharacterBody3D = body as CharacterBody3D
	if moving != null:
		moving.velocity = Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO
