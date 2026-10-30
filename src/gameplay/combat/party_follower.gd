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
## walks. Walking up to foes and swinging at them is C4.9.
##
## OWNS: walking after the leader, thinking for its member, and this member's loadout while it
## is not the one controlled.
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

var _agent: NavigationAgent3D
var _gravity: float = 24.0
var _think_left: float = 0.0


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


func _physics_process(delta: float) -> void:
	follow(delta)
	velocity.y = velocity.y - _gravity * delta if not is_on_floor() else 0.0
	move_and_slide()
	var visual: CharacterVisual = get_node_or_null(^"Visual") as CharacterVisual
	if visual != null:
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.05
		visual.update_from_velocity(Vector3(velocity.x, 0.0, velocity.z), delta,
			GameEnums.MoveState.WALK if moving else GameEnums.MoveState.IDLE)


## One frame of following: ticks statuses, thinks when its time comes, then sets the horizontal
## velocity towards `place()`. It does not move the body; `_physics_process` does.
func follow(delta: float) -> void:
	# Fight time, as every fighter: the hybrid's menu slows the party too (C4.1).
	var dt: float = CombatClock.scaled(delta)
	var statuses: StatusSet = StatusSet.of(self)
	if statuses != null:
		statuses.tick_seconds(dt)
	var me: Combatant = Combatant.of(self)
	if me != null:
		Weakness.recover(me)
	var wish: Vector3 = Vector3.ZERO
	var vitals: Vitals = Vitals.of(self)
	var still: bool = (vitals != null and vitals.is_defeated()) or (statuses != null and statuses.halts())
	if not still:
		_think_left -= dt
		if _think_left <= 0.0:
			_think_left = think_every
			think()
	if leader != null and is_instance_valid(leader) and not still:
		var spot: Vector3 = place()
		var gap: float = _flat(spot - global_position).length()
		# Measured in 3D, so one that fell through the world or was left on another floor is
		# caught too. It is set down on the leader's feet, the one spot sure to be ground, and
		# walks out to its place from there.
		if global_position.distance_to(leader.global_position) > catch_up:
			global_position = leader.global_position
			velocity = Vector3.ZERO
		elif gap > 0.3:
			wish = _towards(spot) * speed
	velocity.x = wish.x * CombatClock.scale
	velocity.z = wish.z * CombatClock.scale


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


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
