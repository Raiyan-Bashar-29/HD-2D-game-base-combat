class_name PartyFollower
extends CharacterBody3D
## A party member walking with the player in the field (C4.7). `FieldParty.spawn` makes one per
## active companion, from `scenes/objects/party_follower.tscn`.
##
## IN PLAIN WORDS: each physics frame (`follow`) it keeps its own statuses ticking (a field poison
## still burns) and its stagger recovering, then walks towards its place in the line: `spacing`
## metres behind the leader for each `slot` ahead of it. Left too far behind (a door, a fall
## through the world), it is set down on the leader's feet at once. A fallen or staggered
## follower stands still.
##
## It can be hit: it has a `Hurtbox`, so a real-time enemy that finds it nearest attacks it.
##
## IT THINKS (C4.8). Every `think_every` seconds of fight time, while a foe stands within
## `FieldCommands.REACH`, it asks its member's `BattleBrain` (the `brain` on the loadout's
## fighter, the same data a turn-based battle reads) what to do, through a `FieldBrainContext`:
## each entry it can pay for, in ATB and mp, competes by weight, so it heals the most hurt ally
## or casts at a foe as the data says. With an empty gauge, no brain or no foe near, it only
## walks.
##
## IT FIGHTS (C4.9). When its loadout has a `field_brain`, an `ActionDecider` (the same one a
## real-time enemy uses) runs it each frame, with its place in the line as its home:
## - a foe within the brain's `aggro_radius` is chased, and attacked once in reach, with a move
##   drawn from the brain. A move that opens the member's attack chain plays the whole chain,
##   pressed swing after swing as the player would; any other move plays alone. Its own
##   `Hitbox` strikes as its member, then it waits the brain's `attack_cooldown`;
## - hurt below `retreat_below`, it backs away;
## - strayed further than `leash_radius` from its place, it gives up and walks back;
## - with no foe in sight it keeps its place in the line, as before.
## A knockback pushes and stuns it, and a stagger or a fall drops the swing it was in.
##
## OWNS: walking after the leader, thinking and fighting for its member, its move clock and
## hit-stun, and this member's loadout while it is not the one controlled.
## MUST NOT: read input, or swap itself with the player (`FieldParty.switch` does both bodies).

const GROUP: StringName = &"party_follower"

## Who this member is and what they can do, handed back to the player's body on a switch.
var loadout: ActionLoadout
## The body it follows: the player's.
var leader: Node3D
## Its place in the line, 1 right behind the leader.
var slot: int = 1
## Metres between places in the line.
@export var spacing: float = 1.4
## Walking speed, in metres a second.
@export var speed: float = 4.5
## Further than this from the leader, it is set down on the leader's feet at once.
@export var catch_up: float = 12.0
## Seconds of fight time between two choices of its brain (C4.8).
@export var think_every: float = 1.0

## Its brain's draws. Randomised when it joins the world; a test may seed it.
var rng := RandomNumberGenerator.new()
## What its `field_brain` does next (C4.9). Rebuilt when the loadout's brain changes, as after
## a party switch; null while it has none.
var decider: ActionDecider
## The clock of its own swings, as a fighter's.
var timeline: MoveTimeline = MoveTimeline.new()
## The way it faces, flat; its hitbox points along it.
var facing: Vector3 = Vector3.FORWARD
## Seconds a knockback pushes and stuns it for.
@export var stun_time: float = 0.25

var _agent: NavigationAgent3D
var _hitbox: Hitbox
var _gravity: float = 24.0
var _think_left: float = 0.0
var _chaining: bool = false
var _fitted: int = -1
var _stun_left: float = 0.0
var _push: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	# It walks on the world and blocks no one: the player passes through their own party.
	collision_layer = 0
	collision_mask = Layers.WORLD
	var configured: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	_gravity = configured
	_agent = get_node_or_null(^"Agent") as NavigationAgent3D
	rng.randomize()
	_think_left = think_every
	if loadout != null and Combatant.of(self) == null:
		ActionHost.fit_identity(self, loadout)
	# Its swings strike from here. The hitbox is the body's, not the member's: it stays when a
	# switch moves the member away, and strikes as whoever is here now (`_fight` sets it).
	_hitbox = Hitbox.new()
	_hitbox.timeline = timeline
	add_child(_hitbox)
	for child: Node in get_children():
		if child is Hurtbox:
			(child as Hurtbox).timeline = timeline
	Events.knockback_requested.connect(_on_knockback)


func _physics_process(delta: float) -> void:
	follow(delta)
	velocity.y = velocity.y - _gravity * delta if not is_on_floor() else 0.0
	move_and_slide()
	var visual: CharacterVisual = get_node_or_null(^"Visual") as CharacterVisual
	if visual != null:
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.05
		visual.update_from_velocity(Vector3(velocity.x, 0.0, velocity.z), delta,
			GameEnums.MoveState.WALK if moving else GameEnums.MoveState.IDLE)


## One frame of following: ticks statuses, thinks when its time comes, fights by its field
## brain when it has one, and otherwise sets the horizontal velocity towards `place()`. It does
## not move the body; `_physics_process` does.
func follow(delta: float) -> void:
	# Fight time, as every fighter: the hybrid's menu slows the party too (C4.1).
	var dt: float = CombatClock.scaled(delta)
	var statuses: StatusSet = StatusSet.of(self)
	if statuses != null:
		statuses.tick_seconds(dt)
	var me: Combatant = Combatant.of(self)
	if me != null:
		Weakness.recover(me)
	_stun_left = maxf(0.0, _stun_left - dt)
	var vitals: Vitals = Vitals.of(self)
	var fallen: bool = vitals != null and vitals.is_defeated()
	var still: bool = fallen or (statuses != null and statuses.halts())
	if not still:
		_think_left -= dt
		if _think_left <= 0.0:
			_think_left = think_every
			think()
	var wish: Vector3 = Vector3.ZERO
	if leader != null and is_instance_valid(leader):
		# Measured in 3D, so one that fell through the world or was left on another floor is
		# caught too. It is set down on the leader's feet, the one spot sure to be ground, and
		# walks out to its place from there.
		if not still and global_position.distance_to(leader.global_position) > catch_up:
			global_position = leader.global_position
			velocity = Vector3.ZERO
			timeline.cancel()
		else:
			wish = _fight(dt, still, fallen)
			if wish == Vector3.INF:
				wish = _keep_place() if not still else Vector3.ZERO
	velocity.x = wish.x * CombatClock.scale
	velocity.z = wish.z * CombatClock.scale


## One frame of fighting by the member's `field_brain`. Returns the walk it wants, or
## `Vector3.INF` when it is not fighting and should keep its place in the line.
func _fight(dt: float, still: bool, fallen: bool) -> Vector3:
	var brain: ActionBrain = loadout.field_brain if loadout != null else null
	if decider == null or decider.brain != brain:
		# A new member is here (a switch), or the brain changed: a fresh mind, and no old swing.
		decider = ActionDecider.new(brain) if brain != null else null
		timeline.cancel()
	if decider == null:
		return Vector3.INF
	var target: Hurtbox = Hurtbox.nearest_hostile(self)
	var to_target: Vector3 = _flat(target.global_position - global_position) if target != null else Vector3.INF
	var vitals: Vitals = Vitals.of(self)
	var hp: float = float(vitals.current(&"hp")) / maxf(1.0, float(vitals.maximum(&"hp"))) if vitals != null else 1.0
	# Its home is its place in the line, so the leash is measured from there and it walks back
	# to the leader, wherever the leader has gone.
	var state: ActionDecider.State = decider.think(dt, to_target.length() if target != null else INF,
		_flat(place() - global_position).length(), hp, timeline.busy(), still or _stun_left > 0.0, fallen, rng)
	var wish: Vector3 = Vector3.INF
	match state:
		ActionDecider.State.ATTACK:
			_face(to_target)
			_swing()
			wish = Vector3.ZERO
			if timeline.phase == MoveTimeline.Phase.ACTIVE and timeline.move.travel_speed > 0.0:
				wish = facing * timeline.move.travel_speed
		ActionDecider.State.CHASE:
			_face(to_target)
			# Walk in to just inside reach, then stand and wait out the cooldown.
			wish = Vector3.ZERO
			if to_target.length() > brain.attack_range * 0.9:
				wish = _towards(target.global_position) * brain.move_speed
		ActionDecider.State.RETREAT:
			_face(to_target)
			wish = -to_target.normalized() * brain.move_speed
		ActionDecider.State.STAGGERED, ActionDecider.State.DEFEATED:
			timeline.cancel()
			wish = _push if _stun_left > 0.0 and not fallen else Vector3.ZERO
		_:
			# IDLE, WANDER and RETURN: no fight here, so back to its place in the line.
			timeline.cancel()
	timeline.step(dt)
	_aim_hitbox()
	return wish


## Strikes as whoever is here now, fits the box to each new swing, turns it to face, and sweeps
## it while the swing is live: the same steps as a fighter's.
func _aim_hitbox() -> void:
	_hitbox.attacker = Combatant.of(self)
	if timeline.busy() and timeline.swing != _fitted:
		_fitted = timeline.swing
		_hitbox.fit(timeline.move)
	# The hitbox's -z is its forward, so it points along `facing`.
	_hitbox.rotation.y = atan2(-facing.x, -facing.z)
	if timeline.is_hitting():
		_hitbox.sweep()


## Starts or carries on the attack the decider chose: the whole attack chain when the chosen
## move opens it, pressed every frame so each next swing plays as its window opens (the press
## after the last swing is dropped, so the chain plays once); otherwise the chosen move alone.
func _swing() -> void:
	var chain: Array[ActionMove] = loadout.moves.attack_chain if loadout.moves != null else []
	if decider.chosen != null:
		_chaining = not chain.is_empty() and chain[0] == decider.chosen
		if not _chaining:
			timeline.start(decider.chosen)
	if _chaining:
		timeline.press(chain)


## The walk towards its place in the line, or none when it is already there.
func _keep_place() -> Vector3:
	var spot: Vector3 = place()
	if _flat(spot - global_position).length() > 0.3:
		return _towards(spot) * speed
	return Vector3.ZERO


## One choice of its member's brain, now: a skill or an item drawn by weight from what it can
## pay for and aim. False when it did nothing: no fighter, no foe within reach, or nothing on
## the brain allowed. `follow` calls it every `think_every` seconds.
func think() -> bool:
	var me: Combatant = Combatant.of(self)
	if me == null or loadout == null or loadout.fighter == null:
		return false
	var context := FieldBrainContext.new(me, rng)
	if not context.fighting():
		return false
	return BattleAi.decide(context, loadout.fighter.brain)


## Where it should stand: on the line from the leader towards itself, `spacing * slot` metres
## out, so the party trails the way the leader came. Straight behind when on top of the leader.
func place() -> Vector3:
	var away: Vector3 = _flat(global_position - leader.global_position)
	if away.length() < 0.05:
		away = leader.global_transform.basis.z
	return leader.global_position + _flat(away).normalized() * spacing * slot


## The flat direction to walk to reach `point`: along the navmesh path when the area has one,
## straight at it when it has none.
func _towards(point: Vector3) -> Vector3:
	var next: Vector3 = point
	if _agent != null and NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0:
		_agent.target_position = point
		if not _agent.is_navigation_finished():
			next = _agent.get_next_path_position()
	var way: Vector3 = _flat(next - global_position)
	return way.normalized() if way.length() > 0.05 else Vector3.ZERO


func _face(direction: Vector3) -> void:
	var flat: Vector3 = _flat(direction)
	if direction != Vector3.INF and flat.length() > 0.01:
		facing = flat.normalized()


func _on_knockback(who: StringName, push: Vector3) -> void:
	var mine: Combatant = Combatant.of(self)
	if mine == null or who != mine.combatant_id:
		return
	# Being hit interrupts the swing: the push is the hit-stun.
	timeline.cancel()
	_stun_left = stun_time
	_push = push / stun_time if stun_time > 0.0 else Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
