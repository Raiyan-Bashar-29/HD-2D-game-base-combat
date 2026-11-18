class_name MoveEvents
extends Node
## Makes a move's timed events happen on a field body (C8.16). See `MoveEvent`.
##
## IN PLAIN WORDS: one of these sits on every field body, beside the `ArtSwap`. Each physics
## frame it reads the body's move clock (held by its `Hurtbox`) and does every event of the
## playing move whose time has come, once per swing:
## - SOUND plays at the body. EFFECT shows a picture near the body for its seconds.
## - SHOT sends a `Projectile` out the way the body faces, with its arc and `pierce`; one
##   `at_foe` starts at the foe the body aims at (`BarrageRun.aim_of`: its lock-on, else the
##   nearest foe in sight). On a shot (its own events) it sends a shot for the same attacker.
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
		MoveEvent.Kind.PAUSE when event.others_only:
			_stop_others(body, event.seconds)
		MoveEvent.Kind.PAUSE:
			if CombatClock.scale > 0.0 and event.seconds > 0.0:
				_before = CombatClock.scale
				_pause_left = event.seconds
				CombatClock.set_scale(0.0)


# A super pause (C10.34): every other real-time fighter's own time stops for `seconds`, by a status
# that wears off on the fight's clock (`FighterTime`).
static func _stop_others(body: Node3D, seconds: float) -> void:
	var me: Combatant = Combatant.of(body)
	if me == null or seconds <= 0.0 or not body.is_inside_tree():
		return
	var still := StatusEffect.new()
	still.id = &"status/super_pause"
	still.unit = StatusEffect.Unit.SECONDS
	still.duration = seconds
	still.modifiers = [StatModifier.of(FighterTime.STAT, StatModifier.Op.ADD, -1.0, &"")]
	for node: Node in body.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other: Combatant = node as Combatant
		var statuses: StatusSet = StatusSet.of(other.get_parent()) if other != null else null
		if other != me and other.real_time and statuses != null:
			statuses.apply(still)


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
	sprite.pixel_size = event.amount if event.amount > 0.0 else 0.02
	body.get_parent().add_child(sprite)
	sprite.global_position = _spot(body, event.offset)
	get_tree().create_timer(event.seconds, false).timeout.connect(sprite.queue_free)


func _shoot(body: Node3D, event: MoveEvent) -> void:
	if body == null or body.get_parent() == null or event.shot == null:
		return
	var way: Vector3 = BarrageRun.facing_of(body)
	var shot := Projectile.new()
	# A shot a shot sends out (C8.16e) strikes for the first shot's attacker.
	shot.attacker = Combatant.of(body) if not body is Hitbox else (body as Hitbox).attacker
	for child: Node in body.get_children():
		if child is Hitbox:
			shot.rng = (child as Hitbox).rng
	shot.speed = event.amount
	shot.lift = event.lift
	shot.fall = event.gravity
	shot.pierce = event.pierce
	shot.launch(event.shot)
	if not event.shot.events.is_empty():
		shot.add_child(MoveEvents.new())
	body.get_parent().add_child(shot)
	# A shot never starts inside or behind a wall (C9.12).
	var lift: Vector3 = Vector3.UP * CombatSight.EYE
	shot.global_position = CombatSight.short_of(body, body.global_position + lift, _spot(body, event.offset))
	var foe: Combatant = BarrageRun.aim_of(shot.attacker, []) if event.at_foe and shot.attacker != null else null
	if foe != null:
		shot.global_position = _spot(body, event.offset) - body.global_position + (foe.get_parent() as Node3D).global_position
	shot.direction = way


# `offset` in the body's own space (forward is -z, the way it faces), as a point in the world.
func _spot(body: Node3D, offset: Vector3) -> Vector3:
	var forward: Vector3 = BarrageRun.facing_of(body)
	var side: Vector3 = forward.cross(Vector3.UP)
	return body.global_position + side * offset.x + Vector3.UP * offset.y - forward * offset.z


func _timeline() -> MoveTimeline:
	# A shot (C8.16d) plays its own move's events on its own clock.
	if get_parent() is Hitbox:
		return (get_parent() as Hitbox).timeline
	for child: Node in get_parent().get_children():
		if child is Hurtbox:
			return (child as Hurtbox).timeline
	return null
