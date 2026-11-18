class_name Hitbox
extends Area3D
## The area a real-time move covers while it is live (C3.3): a sword's arc, a lunge, a blast.
## Put it under the attacking actor; it builds its own box shape from each move.
##
## IN PLAIN WORDS: while the attacker's `timeline` says its move is hitting, every `Hurtbox` this
## touches is struck ONCE PER SWING. The physics engine reports a hurtbox that walks into the
## box (`area_entered`); `sweep` catches the ones that were already inside when the swing went
## live, which `area_entered` never reports. Whoever runs the moves calls `fit` as a move starts
## and `sweep` each physics frame; both are cheap when nothing is hitting.
##
## Once per swing is kept by remembering which hurtboxes this swing has struck. A new swing
## (`MoveTimeline.swing` counts them), or a new clock, forgets them all, so it may strike each
## again.
##
## WALLS (C9.12): a hurtbox behind a wall is never struck; `CombatSight` says what a wall is.
##
## OWNS: the hitbox's shape and who it has already struck this swing.
## MUST NOT: decide what a hit does (the `Hurtbox` resolves it) or play the move (`MoveTimeline`).

## Who is attacking: the `Combatant` beside this under the same actor.
var attacker: Combatant
## The clock of the attacker's moves. Null means it never hits.
var timeline: MoveTimeline
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _shape: CollisionShape3D
## The instance ids of the hurtboxes struck during swing `_swing`.
var _struck: Dictionary[int, bool] = {}
# For a move with `hit_gap` (C10.16): how often this swing struck each hurtbox, and when last.
var _counts: Dictionary[int, int] = {}
var _last: Dictionary[int, float] = {}
var _swing: int = -1
## The clock `_swing` was counted on: a new clock counts from 1 again, so it also forgets.
var _clock: MoveTimeline


func _ready() -> void:
	collision_layer = CombatLayers.HITBOX
	collision_mask = CombatLayers.HITBOX_MASK
	monitoring = true
	monitorable = false
	if attacker == null:
		attacker = Combatant.of(get_parent())
	area_entered.connect(_on_area_entered)


## Shapes the box to `move`: its size, and its offset from the attacker (forward is -z).
func fit(move: ActionMove) -> void:
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	(_shape.shape as BoxShape3D).size = move.hitbox_size
	_shape.position = move.hitbox_offset


## The box's size and offset now, for a test or a debug overlay.
func extent() -> AABB:
	if _shape == null:
		return AABB()
	var size: Vector3 = (_shape.shape as BoxShape3D).size
	return AABB(_shape.position - size / 2.0, size)


## Strikes every hurtbox already inside the box. Returns how many were struck now.
func sweep() -> int:
	var count: int = 0
	if timeline == null or not timeline.is_hitting():
		return count
	for area: Area3D in get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox != null and strike(hurtbox):
			count += 1
	return count


## Strikes one hurtbox, unless the move is not live or this swing already struck it.
## True when the hurtbox counted the hit.
## Forgets who this swing has struck, so each may be struck again: a shot of several hits
## (C8.16d, `Projectile`) calls it between its hits.
func forget() -> void:
	_struck.clear()
	_counts.clear()
	_last.clear()


func strike(hurtbox: Hurtbox) -> bool:
	if timeline == null or not timeline.is_hitting() or attacker == null:
		return false
	if _swing != timeline.swing or _clock != timeline:
		_swing = timeline.swing
		_clock = timeline
		forget()
	var key: int = hurtbox.get_instance_id()
	if _walled(hurtbox) or Grab.shielded(hurtbox.get_parent(), self) or not _may_strike(key, timeline):
		return false
	var clock: MoveTimeline = timeline
	var move: ActionMove = timeline.move
	var counted: bool = hurtbox.take(attacker, timeline.move, rng, global_position, timeline.boost)
	# A landed hit lets a `cancel_on_hit` move go straight into the next swing (C8.8a).
	if hurtbox.landed:
		clock.connected()
	# A grab (C8.8b): the victim is held and this fighter goes straight into the throw.
	var victim: Node3D = hurtbox.get_parent() as Node3D
	if hurtbox.flinched and move.throw_move != null and victim != null and not Grab.held(victim) and not Grab.immune(victim):
		clock.start(move.throw_move)
		Grab.hold(victim, self, move.throw_move)
	return counted


# True when this swing may strike `key` now, and counts it: once a swing, or for a move with a
# `hit_gap` up to its `hits` times, that far apart in its own time (C10.16).
func _may_strike(key: int, clock: MoveTimeline) -> bool:
	var gap: float = clock.move.hit_gap if clock.move != null else 0.0
	if gap <= 0.0:
		if _struck.has(key):
			return false
		_struck[key] = true
		return true
	var count: int = _counts.get(key, 0)
	if count >= clock.move.hits or clock.elapsed - _last.get(key, -INF) < gap - 0.0001:
		return false
	_counts[key] = count + 1
	_last[key] = clock.elapsed
	return true


## Where this hit comes from, for the wall check (C9.12): the attacker's middle. A shot or a
## blast comes from where it is.
func _eye() -> Vector3:
	var body: Node3D = attacker.get_parent() as Node3D if attacker != null else null
	return CombatSight.aim(body if body != null else self)


# True when a wall stands between this hit and `hurtbox` (C9.12). It is not remembered as
# struck, so a foe who steps out from behind the wall can still be hit this swing.
func _walled(hurtbox: Hurtbox) -> bool:
	var target: Node3D = hurtbox.get_parent() as Node3D
	var at: Vector3 = CombatSight.aim(target if target != null else hurtbox)
	return CombatSight.wall_between(self, _eye(), at, CombatSight.solids(target)).is_finite()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox != null:
		strike(hurtbox)
