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
## 4a. Each move started, other than the dodge, is told to the fighter's `PowerSet` (C6.4b), so a
##    kit gauge can count a new move.
## 4c. The moves played are the fighter's own, with a worn weapon's chain in their place
##    (`Combatant.field_moves`, C7.3b), unless a running power hands over others on top: a
##    form's own attack chain and dodge (`current_moves`, C6.5b).
## 4b. A quick-slot key (1 to 4) uses that slot's power (`press_slot`, C6.3a).
## 4d. A counter stance's move (C6.6d) is started on this timeline by the `Hurtbox`; the fighter
##    turns to face whoever it counters (`Events.countered`), so the counter swings at them.
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

## Who this fighter is, as the loadout that fitted them. A party switch changes it (C4.7).
var loadout: ActionLoadout
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
# The last swing told to the `PowerSet`.
var _reported: int = 0
# The swing that is a dodge, so a form entered or left mid-roll cannot make it read as a swing.
var _dodge_swing: int = -1
var _roll: Vector3 = Vector3.ZERO
var _fitted: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
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
	Events.countered.connect(_on_countered)


func _physics_process(delta: float) -> void:
	# The switch key hands the body to the next party member (C4.7), but not mid-swing, while
	# knocked back, or while anything else holds the body (a menu, dialogue).
	if Input.is_action_just_pressed(CombatActions.SWITCH) and not timeline.busy() and not stunned() \
			and not _held_by_others() and _body != null:
		FieldParty.switch(_body)
	for slot: int in CombatActions.SLOTS.size():
		if Input.is_action_just_pressed(CombatActions.SLOTS[slot]):
			press_slot(slot)
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
		HitGuard.pass_time(me, dt)
	_stun_left = maxf(0.0, _stun_left - dt)
	# Berserk (C9.5c): the fighter swings without stopping and cannot roll.
	if _taken_over():
		attack = true
		dodge = false
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
	_report_move()
	_aim_hitbox()
	_move_body()


## Uses the power in quick slot `slot` (0 is the first, C6.3a). It works mid-swing, as a menu
## command does, but not while knocked back or staggered, fallen, or held by something else (a
## menu, dialogue). False when refused or the slot is empty. A power that has a `move` then plays
## it on the fighter's own clock, in place of whatever swing was running.
func press_slot(slot: int) -> bool:
	var me: Combatant = Combatant.of(get_parent())
	var vitals: Vitals = Vitals.of(get_parent())
	if me == null or stunned() or _held_by_others() or (vitals != null and vitals.is_defeated()):
		return false
	var slotted: Array[Power] = PowerSlots.powers(me)
	if not PowerSlots.press(me, slot, _rng):
		return false
	# A power with a move of its own plays it (C9.9b): its wind-up, hitbox, travel and i-frames.
	if slotted[slot].move != null:
		timeline.start(slotted[slot].move)
	return true


## The moves the fighter plays now: its own `moves`, with a worn weapon's chain in their place
## (C7.3b), and over that what a running power puts in (a form's chain and dodge, C6.5b).
func current_moves() -> MoveSet:
	var me: Combatant = Combatant.of(get_parent())
	var base: MoveSet = me.field_moves(moves) if me != null else moves
	var powers: PowerSet = PowerSet.of(get_parent())
	return powers.moves_over(base) if powers != null else base


## True while the fighter cannot start moves: knocked back, or under a status counted in
## seconds that skips turns, such as a stagger (`StatusSet.halts`).
func stunned() -> bool:
	if _stun_left > 0.0:
		return true
	var statuses: StatusSet = StatusSet.of(get_parent())
	return statuses != null and statuses.halts()


# True while a status plays this fighter in the player's place (berserk, C9.5c).
func _taken_over() -> bool:
	var statuses: StatusSet = StatusSet.of(get_parent())
	return statuses != null and statuses.takeover() != null


func _start_moves(attack: bool, dodge: bool) -> void:
	var playing: MoveSet = current_moves()
	if dodge and playing.dodge != null and timeline.can_dodge():
		timeline.start(playing.dodge)
		_dodge_swing = timeline.swing
		# Roll the way the body is already moving; standing still, roll the way it faces.
		var going: Vector3 = _flat(_body.velocity) if _body != null else Vector3.ZERO
		_roll = going.normalized() if going.length() > 0.1 else facing
	elif attack:
		timeline.press(playing.attack_chain)


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


# Tells the kit about each move started since last frame, except a dodge (C6.4b).
func _report_move() -> void:
	if timeline.swing == _reported or timeline.move == null:
		return
	_reported = timeline.swing
	var powers: PowerSet = PowerSet.of(get_parent())
	if powers != null and timeline.swing != _dodge_swing:
		powers.moved(timeline.move)


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
	elif timeline.phase == MoveTimeline.Phase.ACTIVE and timeline.speed() > 0.0:
		var way: Vector3 = _roll if timeline.swing == _dodge_swing else facing
		wish = way * timeline.speed()
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


func _on_countered(who: StringName, against: StringName) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id or _body == null or not is_inside_tree():
		return
	var them: Combatant = Combatant.find(get_tree(), against)
	var body: Node3D = them.get_parent() as Node3D if them != null else null
	if body == null:
		return
	var toward: Vector3 = _flat(body.global_position - _body.global_position)
	if toward.length() > 0.01:
		facing = toward.normalized()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
