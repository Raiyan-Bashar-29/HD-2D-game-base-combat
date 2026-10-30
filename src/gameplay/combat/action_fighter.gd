class_name ActionFighter
extends Node
## Makes a body fight in real time (C3.4): attack chains, a dodge, hit-stun and knockback.
## Put it under the body, beside its `Combatant`, `Hurtbox` and `Hitbox`. `ActionHost.equip`
## does that for the player.
##
## IN PLAIN WORDS, each physics frame (`drive`):
## 1. Statuses that count in seconds tick, so a field poison burns and a field sleep wears off.
## 2. A fallen fighter stops; a stunned one (hit-stun, or a SECONDS status that skips turns)
##    cannot start moves.
## 3. Otherwise the dodge button plays the dodge, if the timeline allows it, and the attack
##    button presses the chain. Both are ignored while anything ELSE holds the body's input
##    lock (dialogue, a menu, a climb).
## 4. The `MoveTimeline` steps; the hitbox is fitted to each new move, faces where the fighter
##    faces, and sweeps while the move is live.
## 5. While busy, the fighter holds the body's `&"action"` lock, so the controller stops
##    walking it; the fighter then sets the horizontal velocity itself: the push of a
##    knockback, or a move's `travel_speed` (a dodge's roll, a lunge).
##
## WHY VELOCITY, AND NOT `move_and_slide` HERE: the controller already moves the body every
## frame. A child processes after its parent, so velocity set here is what the controller moves
## by on the next frame. Moving twice would double every step.
##
## OWNS: this fighter's move clock, facing, hit-stun and its `&"action"` lock token.
## MUST NOT: resolve hits (the `Hurtbox` does), choose targets (a `LockOn` sibling does; the
## fighter only faces what it holds), or edit the controller. It talks to a `PlayerController`
## only through its lock methods.

const LOCK: StringName = &"action"

## What this fighter can do. Null means it cannot act, only be hit.
var moves: MoveSet
var timeline: MoveTimeline = MoveTimeline.new()
## Seconds a knockback pushes for, which is also how long it stuns.
var stun_time: float = 0.25
## The way the fighter faces, flat. Forward (-z) until it first moves.
var facing: Vector3 = Vector3.FORWARD

var _body: CharacterBody3D
var _hitbox: Hitbox
var _lock_on: LockOn
var _stun_left: float = 0.0
var _push: Vector3 = Vector3.ZERO
var _roll: Vector3 = Vector3.ZERO
var _fitted: int = -1


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	for child: Node in get_parent().get_children():
		if child is Hitbox:
			_hitbox = child as Hitbox
			_hitbox.timeline = timeline
		elif child is Hurtbox:
			(child as Hurtbox).timeline = timeline
		elif child is LockOn:
			_lock_on = child as LockOn
	Events.knockback_requested.connect(_on_knockback)


func _physics_process(delta: float) -> void:
	drive(delta, Input.is_action_just_pressed(CombatActions.ATTACK),
		Input.is_action_just_pressed(CombatActions.DODGE))


## One frame of fighting: `delta` seconds pass, with these buttons just pressed.
func drive(delta: float, attack: bool, dodge: bool) -> void:
	# Fight time, not frame time: the hybrid's menu slows or stops the fight (C4.1).
	var dt: float = CombatClock.scaled(delta)
	var statuses: StatusSet = StatusSet.of(get_parent())
	if statuses != null:
		statuses.tick_seconds(dt)
	# A stagger that has just worn off refills the shield (C4.6).
	var me: Combatant = Combatant.of(get_parent())
	if me != null:
		Weakness.recover(me)
	_stun_left = maxf(0.0, _stun_left - dt)
	# Locked on, the fighter always faces its target, so every swing and roll aims at it (C3.5).
	if _lock_on != null and _lock_on.target != null and _lock_on.direction() != Vector3.ZERO:
		facing = _lock_on.direction()
	var vitals: Vitals = Vitals.of(get_parent())
	# A fallen or staggered fighter drops whatever swing it was in.
	if (vitals != null and vitals.is_defeated()) or (statuses != null and statuses.halts()):
		timeline.cancel()
	elif not stunned() and not _held_by_others() and moves != null:
		_start_moves(attack, dodge)
	timeline.step(dt)
	_aim_hitbox()
	_move_body()


## True while the fighter cannot start moves: knocked back, or under a status counted in
## seconds that skips turns, such as a stagger (`StatusSet.halts`).
func stunned() -> bool:
	if _stun_left > 0.0:
		return true
	var statuses: StatusSet = StatusSet.of(get_parent())
	return statuses != null and statuses.halts()


func _start_moves(attack: bool, dodge: bool) -> void:
	if dodge and moves.dodge != null and timeline.can_dodge():
		timeline.start(moves.dodge)
		# Roll the way the body is already moving; standing still, roll the way it faces.
		var going: Vector3 = _flat(_body.velocity) if _body != null else Vector3.ZERO
		_roll = going.normalized() if going.length() > 0.1 else facing
	elif attack:
		timeline.press(moves.attack_chain)


## Fits the hitbox to each new move, turns it to face, and sweeps it while the move is live.
func _aim_hitbox() -> void:
	if _hitbox == null:
		return
	if timeline.busy() and timeline.swing != _fitted:
		_fitted = timeline.swing
		_hitbox.fit(timeline.move)
	# The hitbox's -z is its forward, so it points along `facing`.
	_hitbox.rotation.y = atan2(-facing.x, -facing.z)
	if timeline.is_hitting():
		_hitbox.sweep()


## Holds or lets go of the body, and sets its horizontal velocity while holding it.
func _move_body() -> void:
	if _body == null:
		return
	var player: PlayerController = _body as PlayerController
	var holding: bool = timeline.busy() or _stun_left > 0.0
	if player != null:
		if holding:
			player.lock_input(LOCK)
		else:
			player.release_input(LOCK)
	if not holding:
		var flat: Vector3 = _flat(_body.velocity)
		if flat.length() > 0.1 and (_lock_on == null or _lock_on.target == null):
			facing = flat.normalized()
		return
	# While holding, the fighter owns the horizontal velocity outright: a push, a roll, a
	# lunge, or standing firm. Leaving it to the controller's friction would let a roll slide
	# on through its recovery.
	var wish: Vector3 = Vector3.ZERO
	if _stun_left > 0.0:
		wish = _push
	elif timeline.phase == MoveTimeline.Phase.ACTIVE and timeline.move.travel_speed > 0.0:
		var way: Vector3 = _roll if timeline.move == moves.dodge else facing
		wish = way * timeline.move.travel_speed
	# A slowed fight slows the roll and the push with it, and a stopped one holds them still.
	_body.velocity.x = wish.x * CombatClock.scale
	_body.velocity.z = wish.z * CombatClock.scale


## True when something other than this fighter holds the body still: dialogue, a menu, a climb.
func _held_by_others() -> bool:
	var player: PlayerController = _body as PlayerController
	if player == null:
		return false
	for holder: StringName in player.input_holders():
		if holder != LOCK:
			return true
	return false


func _on_knockback(who: StringName, push: Vector3) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id:
		return
	# Being hit interrupts the swing: the push is the hit-stun.
	timeline.cancel()
	_stun_left = stun_time
	_push = push / stun_time if stun_time > 0.0 else Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
