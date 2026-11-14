extends TestCase
## Move events, armour and a second untouchable stretch (C8.16): a move's timed events are
## checked for mistakes; the clock knows both untouchable stretches, the armour stretch and a
## speed change; the `MoveEvents` node does each event once per swing (a shake, a hit pause, a
## shot, an effect picture, a sound); and a hit inside the armour stretch hurts without a push.
##
## OWNS: assertions about `MoveEvent`, `MoveEvents`, and the C8.16 parts of `ActionMove`,
## `MoveTimeline` and `Hurtbox`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _actors: Array[Node] = []
var _shakes: Array[Vector2] = []
var _pushes: int = 0


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	Events.camera_shake_requested.connect(_on_shake)
	Events.knockback_requested.connect(_on_push)
	_shapes()
	_the_clock()
	_on_a_body()
	_armour()
	Events.camera_shake_requested.disconnect(_on_shake)
	Events.knockback_requested.disconnect(_on_push)
	for actor: Node in _actors:
		actor.free()
	CombatClock.reset()
	Flags.clear_all()


func _event(kind: MoveEvent.Kind, at: float, amount: float = 0.0, seconds: float = 0.0) -> MoveEvent:
	var made := MoveEvent.new()
	made.kind = kind
	made.at = at
	made.amount = amount
	made.seconds = seconds
	return made


func _move() -> ActionMove:
	var made := ActionMove.new()
	made.id = &"move/fixture_event_swing"
	made.startup = 0.2
	made.active = 0.4
	made.recovery = 0.4
	made.travel_speed = 2.0
	return made


func _strike(power: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.5
	made.recovery = 0.1
	made.power = power
	made.knockback = 2.0
	return made


func _actor(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 50.0, &"attack": 2.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	actor.add_child(Hitbox.new())
	actor.add_child(MoveEvents.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _shapes() -> void:
	var move := _move()
	move.events = [_event(MoveEvent.Kind.SHAKE, 0.0, 0.5, 0.2), _event(MoveEvent.Kind.SPEED, 0.4, 6.0)]
	move.iframes2_from = 0.7
	move.iframes2_to = 0.9
	move.armour_from = 0.1
	move.armour_to = 0.5
	equal("a move with ordered events and sound stretches has no problems", move.problems("x").size(), 0)
	var bad := _move()
	var shot := _event(MoveEvent.Kind.SHOT, 0.5)
	shot.shot = _move()
	bad.events = [_event(MoveEvent.Kind.SOUND, 0.6), _event(MoveEvent.Kind.EFFECT, 0.3, 0.0, 1.0),
		shot, _event(MoveEvent.Kind.PAUSE, 5.0), null]
	bad.armour_to = -1.0
	equal("no sound, no picture, a shot that cannot strike, no seconds, an empty one, three out of place, a bad stretch",
		bad.problems("x").size(), 9)


func _the_clock() -> void:
	var move := _move()
	move.iframes_from = 0.0
	move.iframes_to = 0.2
	move.perfect_window = 0.1
	move.iframes2_from = 0.7
	move.iframes2_to = 0.9
	move.armour_from = 0.3
	move.armour_to = 0.5
	move.events = [_event(MoveEvent.Kind.SPEED, 0.4, 6.0)]
	var clock := MoveTimeline.new()
	equal("an idle clock is neither untouchable nor armoured and does not travel",
		[clock.invulnerable(), clock.armoured(), clock.speed()], [false, false, 0.0])
	clock.start(move)
	clock.step(0.05)
	var first: Array = [clock.invulnerable(), clock.perfectly(), clock.armoured(), clock.speed()]
	clock.step(0.3)
	var middle: Array = [clock.invulnerable(), clock.perfectly(), clock.armoured(), clock.speed()]
	clock.step(0.1)
	equal("the first stretch is untouchable and perfect; then armour only, at the move's own speed",
		[first, middle], [[true, true, false, 2.0], [false, false, true, 2.0]])
	equal("a speed event changes the travel speed from its time on", clock.speed(), 6.0)
	clock.step(0.3)
	equal("the second stretch is untouchable but never a perfect dodge, and armour has ended",
		[clock.invulnerable(), clock.perfectly(), clock.armoured()], [true, false, false])


# A move with one event of each kind the node does.
func _busy_move() -> ActionMove:
	var move := _move()
	var sound := _event(MoveEvent.Kind.SOUND, 0.1)
	sound.sound = AudioStreamWAV.new()
	var effect := _event(MoveEvent.Kind.EFFECT, 0.3, 0.0, 0.5)
	effect.picture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	effect.offset = Vector3(0.0, 1.0, -2.0)
	var shot := _event(MoveEvent.Kind.SHOT, 0.3, 8.0)
	shot.shot = _strike(3.0)
	shot.offset = Vector3(0.0, 1.0, -1.0)
	move.events = [_event(MoveEvent.Kind.SHAKE, 0.0, 0.5, 0.2), sound, effect, shot,
		_event(MoveEvent.Kind.PAUSE, 0.5, 0.0, 0.1)]
	return move


func _on_a_body() -> void:
	var hero := _actor(&"fixture_event_hero", &"side_a", Vector3.ZERO)
	var events: MoveEvents = hero.get_child(5) as MoveEvents
	var clock := MoveTimeline.new()
	(hero.get_child(3) as Hurtbox).timeline = clock
	var move := _busy_move()
	events.watch()
	equal("with no move playing nothing happens", events.done, 0)
	clock.start(move)
	events.watch()
	events.watch()
	equal("an event at the start happens once: the camera is asked to shake", [events.done, _shakes], [1, [Vector2(0.5, 0.2)]])
	clock.step(0.35)
	events.watch()
	var picture: Sprite3D = hero.get_parent().get_node_or_null(^"MoveEffect") as Sprite3D
	var shots: Array[Node] = get_tree().get_nodes_in_group(Projectile.GROUP)
	var flying: Projectile = shots[0] as Projectile if shots.size() == 1 else null
	equal("later the sound, the picture and the shot happen: the picture two metres ahead, the shot the body's own",
		[events.done, picture != null and picture.global_position.is_equal_approx(Vector3(0, 1, -2)),
			flying != null and flying.attacker == Combatant.of(hero) and flying.speed == 8.0
			and flying.direction.is_equal_approx(Vector3.FORWARD)], [4, true, true])
	clock.step(0.2)
	events.watch()
	var stopped: float = CombatClock.scale
	events.wait(0.05)
	var still: float = CombatClock.scale
	events.wait(0.06)
	equal("a hit pause stops the fight for its seconds and then lets it run", [stopped, still, CombatClock.scale], [0.0, 0.0, 1.0])
	clock.start(move)
	events.watch()
	equal("a second swing does its events again", [events.done, _shakes.size()], [6, 2])
	if picture != null:
		picture.free()
	if flying != null:
		flying.free()


func _armour() -> void:
	var hero := _actor(&"fixture_armour_hero", &"side_a", Vector3(5, 0, 0))
	var foe := _actor(&"fixture_armour_foe", &"side_b", Vector3(6, 0, 0))
	var held := _move()
	held.armour_from = 0.0
	held.armour_to = 0.3
	var clock := MoveTimeline.new()
	clock.start(held)
	clock.step(0.1)
	(foe.get_child(3) as Hurtbox).timeline = clock
	var swing := _strike(3.0)
	var arm := MoveTimeline.new()
	arm.start(swing)
	arm.step(0.01)
	var hitbox: Hitbox = hero.get_child(4) as Hitbox
	hitbox.timeline = arm
	_pushes = 0
	hitbox.strike(foe.get_child(3) as Hurtbox)
	equal("inside its armour stretch a fighter is hurt but not pushed", [Vitals.of(foe).current(&"hp"), _pushes], [45, 0])
	clock.step(0.3)
	arm.start(swing)
	arm.step(0.01)
	hitbox.strike(foe.get_child(3) as Hurtbox)
	equal("after it the same hit pushes", [Vitals.of(foe).current(&"hp"), _pushes], [40, 1])


func _on_shake(strength: float, seconds: float) -> void:
	_shakes.append(Vector2(strength, seconds))


func _on_push(_who: StringName, _push: Vector3) -> void:
	_pushes += 1
