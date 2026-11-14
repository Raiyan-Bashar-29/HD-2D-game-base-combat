class_name MoveEvents
extends Node
## Makes a move's timed events happen on a field body (C8.16). See `MoveEvent`.
##
## IN PLAIN WORDS: one of these sits on every field body, beside the `ArtSwap`. Each physics
## frame it reads the body's move clock (held by its `Hurtbox`) and does every event of the
## playing move whose time has come, once per swing:
## - SOUND plays at the body. EFFECT shows a picture near the body for its seconds.
## - SHOT sends a `Projectile` out the way the body faces.
## - SHAKE asks the camera to shake (`Events.camera_shake_requested`).
## - PAUSE stops the fight (`CombatClock`) for its seconds of real time, then puts the speed
##   back. A pause asked for while the fight is already stopped is skipped.
## - SPEED needs nothing here: `MoveTimeline.speed` reads it.
##
## OWNS: doing a playing move's events at their times, and ending a pause it began.
## MUST NOT: start, change or cancel a move, or decide what a hit does.

const EFFECT_NAME: String = "MoveEffect"

## How many events this node has done, for a test to count.
var done: int = 0

var _swing: int = -1
var _next: int = 0
var _pause_left: float = 0.0
var _before: float = 1.0


func _physics_process(_delta: float) -> void:
	watch()


func _process(delta: float) -> void:
	wait(delta)


func _exit_tree() -> void:
	wait(_pause_left)


## Does every event that is due now. Public so a test steps it without waiting for frames.
func watch() -> void:
	var timeline: MoveTimeline = _timeline()
	if timeline == null or not timeline.busy():
		_swing = -1
		return
	if timeline.swing != _swing:
		_swing = timeline.swing
		_next = 0
	var events: Array[MoveEvent] = timeline.move.events
	while _next < events.size() and (events[_next] == null or events[_next].at <= timeline.elapsed):
		if events[_next] != null:
			_do(events[_next])
		_next += 1


## `seconds` of real time pass for a pause this node began; at its end the fight runs again.
func wait(seconds: float) -> void:
	if _pause_left <= 0.0:
		return
	_pause_left -= seconds
	if _pause_left <= 0.0:
		CombatClock.set_scale(_before)


func _do(event: MoveEvent) -> void:
	done += 1
	var body: Node3D = get_parent() as Node3D
	match event.kind:
		MoveEvent.Kind.SOUND:
			_sound(event.sound)
		MoveEvent.Kind.EFFECT:
			_effect(body, event)
		MoveEvent.Kind.SHOT:
			_shoot(body, event)
		MoveEvent.Kind.SHAKE:
			Events.camera_shake_requested.emit(event.amount, event.seconds)
		MoveEvent.Kind.PAUSE:
			if CombatClock.scale > 0.0 and event.seconds > 0.0:
				_before = CombatClock.scale
				_pause_left = event.seconds
				CombatClock.set_scale(0.0)


func _sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# A picture in the world where the body stood, gone after the event's seconds.
func _effect(body: Node3D, event: MoveEvent) -> void:
	if body == null or body.get_parent() == null or event.picture == null:
		return
	var sprite := Sprite3D.new()
	sprite.name = EFFECT_NAME
	sprite.texture = event.picture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.02
	body.get_parent().add_child(sprite)
	sprite.global_position = _spot(body, event.offset)
	get_tree().create_timer(event.seconds, false).timeout.connect(sprite.queue_free)


func _shoot(body: Node3D, event: MoveEvent) -> void:
	if body == null or body.get_parent() == null or event.shot == null:
		return
	var way: Vector3 = BarrageRun.facing_of(body)
	var shot := Projectile.new()
	shot.attacker = Combatant.of(body)
	for child: Node in body.get_children():
		if child is Hitbox:
			shot.rng = (child as Hitbox).rng
	shot.speed = event.amount
	shot.launch(event.shot)
	body.get_parent().add_child(shot)
	shot.global_position = _spot(body, event.offset)
	shot.direction = way


# `offset` in the body's own space (forward is -z, the way it faces), as a point in the world.
func _spot(body: Node3D, offset: Vector3) -> Vector3:
	var forward: Vector3 = BarrageRun.facing_of(body)
	var side: Vector3 = forward.cross(Vector3.UP)
	return body.global_position + side * offset.x + Vector3.UP * offset.y - forward * offset.z


func _timeline() -> MoveTimeline:
	for child: Node in get_parent().get_children():
		if child is Hurtbox:
			return (child as Hurtbox).timeline
	return null
