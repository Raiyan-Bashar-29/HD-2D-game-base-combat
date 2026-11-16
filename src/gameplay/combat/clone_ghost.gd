class_name CloneGhost
extends Hitbox
## The ghost of a clone (C6.13a, `CloneMechanism`): a `Hitbox` that follows its `source`'s path
## and replays its moves `delay` seconds behind.
##
## IN PLAIN WORDS: each step it writes down where the source stands and faces, and stands where
## the source stood `delay` seconds ago. `echo` is told each move the source starts; `delay`
## seconds later the ghost plays a copy at `power_fraction` of its power on its own clock,
## facing the way the source faced then, and strikes what its box touches as a swing does, for
## the source's `Combatant` (`attacker`). After `lifetime` seconds it is gone. It has no hurtbox,
## so nothing hits it. A copy of the source's sprite, tinted, is its look.
## It runs on fight time (`CombatClock`), so a stopped fight freezes it.
##
## OWNS: its path and its queue of moves.
## MUST NOT: decide when it is made or sent away (`CloneRun` does), or name a character.

const GROUP: StringName = &"clone_ghosts"
# Slack for sums of frame times, so a sample written exactly `delay` ago counts.
const EPSILON: float = 0.0001

var source: Node3D
var delay: float = 0.5
var lifetime: float = 8.0
var power_fraction: float = 1.0
var tint: Color = Color(1, 1, 1, 0.5)

var _age: float = 0.0
var _times: PackedFloat64Array = PackedFloat64Array()
var _spots: PackedVector3Array = PackedVector3Array()
var _facings: PackedVector3Array = PackedVector3Array()
var _due: PackedFloat64Array = PackedFloat64Array()
var _moves: Array[ActionMove] = []
var _facing: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	timeline = MoveTimeline.new()
	_dress()


func _physics_process(delta: float) -> void:
	step(CombatClock.scaled(delta))


## The source started `move`: the ghost plays it `delay` seconds from now.
func echo(move: ActionMove) -> void:
	if move == null:
		return
	_due.append(_age + delay)
	_moves.append(move)


## `dt` seconds of fight time pass: it writes down the source, moves along the path, starts a
## move whose time has come, and strikes while that move is live.
func step(dt: float) -> void:
	_age += dt
	if _age >= lifetime:
		queue_free()
		return
	if is_instance_valid(source):
		_times.append(_age)
		_spots.append(source.global_position)
		_facings.append(BarrageRun.facing_of(source))
	_place(_age - delay + EPSILON)
	timeline.step(dt)
	if not _due.is_empty() and _due[0] <= _age + EPSILON:
		_play(_moves.pop_front() as ActionMove)
		_due.remove_at(0)
	rotation.y = atan2(-_facing.x, -_facing.z)
	if timeline.is_hitting():
		sweep()


## True once it has run out, for a test.
func gone() -> bool:
	return _age >= lifetime or is_queued_for_deletion()


# Stands at the last sample written at or before `when`, and forgets older ones.
func _place(when: float) -> void:
	while _times.size() > 1 and _times[1] <= when:
		_times.remove_at(0)
		_spots.remove_at(0)
		_facings.remove_at(0)
	if _times.is_empty() or _times[0] > when:
		return
	global_position = _spots[0]
	if _facings[0].length_squared() > 0.0001:
		_facing = _facings[0].normalized()


func _play(move: ActionMove) -> void:
	var copy: ActionMove = move.duplicate() as ActionMove
	copy.power = move.power * power_fraction
	timeline.start(copy)
	fit(copy)


# A ghost hits from where it stands, not from its source.
func _eye() -> Vector3:
	return CombatSight.aim(self)


# A tinted copy of the source's sprite, if it has one.
func _dress() -> void:
	if not is_instance_valid(source):
		return
	for child: Node in source.get_children():
		var sprite: SpriteBase3D = child as SpriteBase3D
		if sprite != null:
			var copy: SpriteBase3D = sprite.duplicate() as SpriteBase3D
			copy.modulate = tint
			add_child(copy)
			return
