class_name Projectile
extends Hitbox
## One shot in flight (C6.7): a `Hitbox` that moves. A barrage (`BarrageRun`) fires them; any
## other code that wants something thrown, shot or summoned to strike may too.
##
## IN PLAIN WORDS: a projectile plays its shot, an `ActionMove`, on its own clock. During the
## shot's `startup` it waits where it appeared (a cut about to fall, a blade in a portal); during
## `active` it flies along `direction` at `speed` and strikes whatever hurtbox it touches, once
## each, exactly as a swing does (`Hurtbox.take` decides what the hit does). When `active` ends it
## is gone. A shot that is not `pierce` is also gone after its first strike.
##
## HOMING: with a `homing_at` body and a `turn_rate` above 0, each frame it turns toward that
## body by at most `turn_rate` radians a second. A target that is freed is simply no longer chased.
##
## It always faces along `direction` (its -z), so a long box (a beam) lies along its line. It runs
## on fight time (`CombatClock`), so a stopped fight freezes it in the air.
##
## WHERE IT LANDS (C6.26): a shot whose flight ends without it striking anyone says where it
## ended (`landed`), so a plant can leave something in the ground there (the shards that missed).
##
## It belongs in the world, not under the fighter, so it does not follow its shooter about.
##
## OWNS: one shot's flight, its clock and when it is gone.
## MUST NOT: decide what a hit does (the `Hurtbox` does), or choose where shots start (the
## barrage's pattern does).

## Its flight ended without it striking anyone, at `at`.
signal landed(at: Vector3)

## Every projectile in flight joins this group, so a test or a debug overlay can find them.
const GROUP: StringName = &"combat_projectiles"

## Which way it flies; kept at length 1.
var direction: Vector3 = Vector3.FORWARD
## Metres a second. 0 stays put.
var speed: float = 0.0
## Radians a second it may turn toward `homing_at`. 0 does not home.
var turn_rate: float = 0.0
## The body it chases, or null.
var homing_at: Node3D
## True: it flies on through what it strikes.
var pierce: bool = false

var _gone: bool = false
var _struck_any: bool = false


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	fly(CombatClock.scaled(delta))


## Readies the shot `shot` on a clock of its own and shapes the box to it. Call before adding.
func launch(shot: ActionMove) -> void:
	timeline = MoveTimeline.new()
	timeline.start(shot)
	fit(shot)


## `dt` seconds of fight time pass: the clock steps, the shot turns, moves, faces its way and
## strikes what it overlaps. At the end of its flight it is gone.
func fly(dt: float) -> void:
	if _gone or timeline == null:
		return
	timeline.step(dt)
	if not timeline.busy() or timeline.phase == MoveTimeline.Phase.RECOVERY:
		if not _struck_any:
			landed.emit(global_position)
		_end()
		return
	if timeline.phase == MoveTimeline.Phase.ACTIVE:
		_steer(dt)
		global_position += direction * speed * dt
	_face()
	sweep()


## True once it has ended: flown its course, or struck with no `pierce`.
func gone() -> bool:
	return _gone


func strike(hurtbox: Hurtbox) -> bool:
	if _gone:
		return false
	var counted: bool = super.strike(hurtbox)
	_struck_any = _struck_any or counted
	if counted and not pierce:
		_end()
	return counted


# Turns toward `homing_at`, no faster than `turn_rate` allows.
func _steer(dt: float) -> void:
	if turn_rate <= 0.0 or homing_at == null or not is_instance_valid(homing_at):
		return
	var want: Vector3 = homing_at.global_position - global_position
	if want.length_squared() < 0.0001:
		return
	want = want.normalized()
	var angle: float = direction.angle_to(want)
	if angle > 0.0001:
		direction = direction.slerp(want, minf(1.0, turn_rate * dt / angle)).normalized()


# Points -z along `direction`, so the box lies along the line it flies.
func _face() -> void:
	if direction.length_squared() < 0.0001:
		return
	var up: Vector3 = Vector3.FORWARD if absf(direction.normalized().y) > 0.99 else Vector3.UP
	global_basis = Basis.looking_at(direction, up)


func _end() -> void:
	_gone = true
	queue_free()
