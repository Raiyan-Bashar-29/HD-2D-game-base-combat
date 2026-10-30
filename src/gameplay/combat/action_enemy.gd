class_name ActionEnemy
extends CharacterBody3D
## A real-time enemy's body (C3.7): it notices, chases, swings, backs off, walks home, reels
## from hits and falls. `scenes/objects/action_enemy.tscn` is the prefab; place one in an area
## and give it a `fighter` and a `brain`.
##
## IN PLAIN WORDS, each physics frame (`act`):
## 1. It senses: the nearest hostile fighter (any standing `Hurtbox` the faction table calls an
##    enemy), how far it is from home, its own hp, whether a move is playing, whether it reels.
## 2. It asks its `ActionDecider` what to do, with those plain facts.
## 3. It acts on the answer: walk to the target and stand at `attack_range`; start the chosen
##    move facing the target; back away; walk home; wander near home; or stand.
## Then its move clock steps and its hitbox sweeps, exactly as the player's do.
##
## IT BUILDS ITS OWN FIGHTING PARTS on ready (`Vitals`, `StatusSet`, `Combatant`, `Hurtbox`,
## `Hitbox`) from `fighter`, so the prefab is a body, a shape, a sprite and an agent, and every
## enemy kind is data. Its pools start full each time it is built, the way a battle's enemies do.
##
## WALKING USES THE AREA'S NAVIGATION when the area has a navmesh, through its
## `NavigationAgent3D` and `NpcBrain.reachable_point`, and walks straight at the point when it
## has none, so a test or a bare area still works.
##
## WHEN IT FALLS (C3.8) it announces `field_enemy_defeated` with its `experience` and `loot`
## once, lies there `linger` seconds, then is removed. Re-entering the area builds it afresh,
## unless `remember_defeat` keeps it gone for good through a flag.
##
## OWNS: this enemy's body: its home, facing, wander point, hit-stun and velocity.
## MUST NOT: decide (the `ActionDecider` does), resolve hits (the `Hurtbox` does), or grant its
## own reward (`ActionHost` does, on the announcement).

@export var fighter: CombatantDef
@export var brain: ActionBrain
## Seconds a knockback pushes and stuns it for.
@export var stun_time: float = 0.3
@export_group("Defeat")
## What beating it gives, through `Rewards.give` (C3.8).
@export var experience: int = 0
@export var loot: Array[StringName] = []
## Seconds it lies fallen before it is removed.
@export var linger: float = 1.0
## True for a one-off foe (a boss): once beaten it never comes back, even on re-entry. False, the
## default, means it is back whenever the area is entered again.
@export var remember_defeat: bool = false

var decider: ActionDecider
var timeline: MoveTimeline = MoveTimeline.new()
var home: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _agent: NavigationAgent3D
var _hitbox: Hitbox
var _target: Hurtbox
var _wander_to: Vector3 = Vector3.ZERO
var _stun_left: float = 0.0
var _push: Vector3 = Vector3.ZERO
var _gravity: float = 24.0
var _fallen: bool = false
var _gone_in: float = 0.0


func _ready() -> void:
	if remember_defeat and Flags.get_bool(defeat_flag()):
		queue_free()
		return
	collision_layer = Layers.NPC
	collision_mask = Layers.WORLD
	var configured: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	_gravity = configured
	home = global_position
	_wander_to = home
	decider = ActionDecider.new(brain if brain != null else ActionBrain.new())
	_agent = get_node_or_null(^"Agent") as NavigationAgent3D
	if fighter != null:
		_build()
	Events.knockback_requested.connect(_on_knockback)


func _physics_process(delta: float) -> void:
	act(delta)
	velocity.y = velocity.y - _gravity * delta if not is_on_floor() else 0.0
	move_and_slide()
	var visual: CharacterVisual = get_node_or_null(^"Visual") as CharacterVisual
	if visual != null:
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.05
		visual.update_from_velocity(Vector3(velocity.x, 0.0, velocity.z), delta,
			GameEnums.MoveState.WALK if moving else GameEnums.MoveState.IDLE)


## One frame of thinking and acting: senses, decides, sets the horizontal velocity, steps the
## move. Returns the state it acted on. It does not move the body; `_physics_process` does.
func act(delta: float) -> ActionDecider.State:
	# Fight time, not frame time: the hybrid's menu slows or stops the fight (C4.1).
	var dt: float = CombatClock.scaled(delta)
	var statuses: StatusSet = StatusSet.of(self)
	if statuses != null:
		statuses.tick_seconds(dt)
	_stun_left = maxf(0.0, _stun_left - dt)
	_target = nearest_hostile()
	var to_target: Vector3 = _flat(_target.global_position - global_position) if _target != null else Vector3.INF
	var vitals: Vitals = Vitals.of(self)
	var defeated: bool = vitals != null and vitals.is_defeated()
	var hp: float = float(vitals.current(&"hp")) / maxf(1.0, float(vitals.maximum(&"hp"))) if vitals != null else 1.0
	var state: ActionDecider.State = decider.think(dt, to_target.length() if _target != null else INF,
		_flat(global_position - home).length(), hp, timeline.busy(), _stun_left > 0.0, defeated, rng)
	_carry_out(state, to_target)
	if _fallen:
		_gone_in -= dt
		if _gone_in <= 0.0 and not is_queued_for_deletion():
			queue_free()
	timeline.step(dt)
	if _hitbox != null:
		_hitbox.rotation.y = atan2(-facing.x, -facing.z)
		if timeline.is_hitting():
			_hitbox.sweep()
	return state


## The nearest standing hurtbox this enemy may attack, or null.
func nearest_hostile() -> Hurtbox:
	var me: Combatant = Combatant.of(self)
	if me == null or not is_inside_tree():
		return null
	var best: Hurtbox = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox == null or not me.can_target(hurtbox.fighter(), FactionTable.Target.ENEMY):
			continue
		var vitals: Vitals = Vitals.of(hurtbox.get_parent())
		var distance: float = global_position.distance_to(hurtbox.global_position)
		if (vitals == null or not vitals.is_defeated()) and distance < best_distance:
			best = hurtbox
			best_distance = distance
	return best


func _carry_out(state: ActionDecider.State, to_target: Vector3) -> void:
	var speed: float = decider.brain.move_speed
	var wish: Vector3 = Vector3.ZERO
	match state:
		ActionDecider.State.ATTACK:
			if decider.chosen != null:
				_face(to_target)
				timeline.start(decider.chosen)
				if _hitbox != null:
					_hitbox.fit(decider.chosen)
			if timeline.phase == MoveTimeline.Phase.ACTIVE and timeline.move.travel_speed > 0.0:
				wish = facing * timeline.move.travel_speed
		ActionDecider.State.CHASE:
			_face(to_target)
			# Walk in to just inside range, then stand and wait out the cooldown.
			if to_target.length() > decider.brain.attack_range * 0.9:
				wish = _towards(_target.global_position) * speed
		ActionDecider.State.RETREAT:
			_face(to_target)
			wish = -to_target.normalized() * speed
		ActionDecider.State.RETURN:
			wish = _towards(home) * speed
		ActionDecider.State.WANDER:
			if _flat(_wander_to - global_position).length() < 0.3:
				_wander_to = _wander_point()
			wish = _towards(_wander_to) * speed * 0.5
		ActionDecider.State.STAGGERED:
			timeline.cancel()
			wish = _push
		ActionDecider.State.DEFEATED:
			timeline.cancel()
			_fall()
	# A slowed fight slows the walk with it, and a stopped one holds it still. Gravity is not
	# scaled, so a frozen enemy still stands on the floor.
	velocity.x = wish.x * CombatClock.scale
	velocity.z = wish.z * CombatClock.scale


## The flat direction to walk to reach `point`: along the navmesh path when the area has one,
## straight at it when it has none.
func _towards(point: Vector3) -> Vector3:
	var next: Vector3 = point
	if _agent != null and _has_navmesh():
		_agent.target_position = point
		if _agent.is_navigation_finished():
			return Vector3.ZERO
		next = _agent.get_next_path_position()
	var way: Vector3 = _flat(next - global_position)
	return way.normalized() if way.length() > 0.05 else Vector3.ZERO


## A random point within `wander_radius` of home, clamped to where the navmesh can reach.
func _wander_point() -> Vector3:
	var angle: float = rng.randf() * TAU
	var wish: Vector3 = home + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf() * decider.brain.wander_radius
	if _agent != null and _has_navmesh():
		return NpcBrain.reachable_point(_agent.get_navigation_map(), global_position, wish, _agent.navigation_layers)
	return wish


## The flag that remembers a `remember_defeat` enemy was beaten: its area and its node name.
func defeat_flag() -> StringName:
	return StringName("field_defeated/%s/%s" % [Director.current_area_id, name])


## The first think after it falls announces the defeat, once, and starts the `linger` clock
## that `act` runs down before removing it.
func _fall() -> void:
	if _fallen:
		return
	_fallen = true
	_gone_in = linger
	var mine: Combatant = Combatant.of(self)
	Events.field_enemy_defeated.emit(mine.combatant_id if mine != null else &"", experience, loot)
	if remember_defeat:
		Flags.set_flag(defeat_flag(), true)


func _has_navmesh() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _face(direction: Vector3) -> void:
	if direction == Vector3.INF:
		return
	var flat: Vector3 = _flat(direction)
	if flat.length() > 0.01:
		facing = flat.normalized()


## Adds the fighting parts from `fighter`, with every pool full.
func _build() -> void:
	add_child(Vitals.new())
	add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = StringName(String(fighter.combatant_id) + "/" + String(name))
	combatant.faction = fighter.faction
	combatant.base_stats = fighter.base_stats
	combatant.weak_to = fighter.weak_to
	combatant.attack_tags = fighter.attack_tags
	combatant.kind = fighter.combatant_id
	add_child(combatant)
	var vitals: Vitals = Vitals.of(self)
	for stat: StringName in fighter.base_stats:
		if String(stat).begins_with(Vitals.MAX_PREFIX):
			var pool := StringName(String(stat).trim_prefix(Vitals.MAX_PREFIX))
			vitals.set_to(pool, vitals.maximum(pool))
	var hurtbox := Hurtbox.new()
	hurtbox.timeline = timeline
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.8, 0.0)
	hurtbox.add_child(shape)
	add_child(hurtbox)
	_hitbox = Hitbox.new()
	_hitbox.timeline = timeline
	add_child(_hitbox)


func _on_knockback(who: StringName, push: Vector3) -> void:
	var mine: Combatant = Combatant.of(self)
	if mine == null or who != mine.combatant_id:
		return
	_stun_left = stun_time
	_push = push / stun_time if stun_time > 0.0 else Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
