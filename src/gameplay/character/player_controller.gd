class_name PlayerController
extends CharacterBody3D
## The player's body and movement.
##
## INPUT OWNERSHIP: this reads movement input only. Interaction input is read by
## InteractionSensor, which is a sibling component, because routing it through here would
## force this file to know about interaction - which the MUST NOT line below forbids.
##
## OWNS: the player's position, velocity, gait and movement state.
## MUST NOT: know about dialogue, inventory, interaction rules or the camera. It reacts to
## a small number of signals that say "you are busy now" and otherwise minds its own
## business. This is what stops a player controller becoming the second god object.
##
## MOVEMENT IS CAMERA-RELATIVE: pressing up moves away from the camera regardless of where
## the camera is, which is what players expect and what makes a fixed-angle camera feel
## natural instead of maddening.
##
## NO JUMPING, deliberately. In an exploration game with a fixed camera, a free jump makes
## the player try to reach ledges the level was not built for, and every collision gap
## becomes a bug report. Vertical movement is authored instead: a ClimbPoint asks this body
## to move between two markers, via begin_climb() at the bottom of this file.
## The gravity below is for slopes and falling, not for jumping.

## Which character's attributes this body is subject to. Deliberately a SECOND export beside
## `Equipment.wearer_id` rather than one shared between them: this file must keep working with
## no equipment component under it at all, and a controller that read its id off a sibling
## would break the moment a game shipped a character who carries nothing.
@export var character_id: StringName = &"player"

@export var walk_speed: float = 3.2
@export var run_speed: float = 6.0
@export var sneak_speed: float = 1.4
## Metres per second squared. High values feel responsive; low values feel like ice.
@export var acceleration: float = 14.0
@export var friction: float = 18.0
## Metres per second up or down an authored climb. Slow on purpose: a climb the player can
## rush is indistinguishable from a teleport, and the point of it is that it takes commitment.
@export var climb_speed: float = 2.6
## Whether run is held or toggled. Mirrors the "gameplay/run_is_toggle" setting.
@export var run_is_toggle: bool = false

@onready var visual: CharacterVisual = $Visual

## THE ONE ATTRIBUTE THIS FILE READS, and its name is declared HERE rather than in `Attributes`
## on purpose: an attribute's name belongs to whatever consumes it, so an attribute nothing
## reads has nowhere to be written down. That is what stops the container growing a table of
## declared-and-unread names, which is the failure this package was split out of WP-09 to
## avoid. `attr/<character_id>/pace` scales every gait at once, so a slower character sneaks,
## walks and runs slower rather than acquiring a fourth speed nobody tuned.
const PACE: StringName = &"pace"

var state: GameEnums.MoveState = GameEnums.MoveState.IDLE

var _gravity: float = 24.0
var _run_toggled: bool = false
## Every system currently holding the player still. See InputLock: a boolean here was fine
## with one caller and broke the moment WP-01 added the second, because whichever of dialogue
## and the climb finished first cleared the other one's hold.
var _lock: InputLock = InputLock.new()
## Where an authored climb is heading, and the corner it turns on the way. Only meaningful
## while state is CLIMB.
var _climb_target: Vector3 = Vector3.ZERO
var _climb_waypoint: Vector3 = Vector3.ZERO
var _climb_turned: bool = false
var _climbing: bool = false


func _ready() -> void:
	var configured: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	_gravity = configured

	collision_layer = Layers.PLAYER
	collision_mask = Layers.PLAYER_MOVE_MASK
	# Let the body ride over small steps and stay glued to slopes when walking downhill.
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)

	run_is_toggle = Settings.get_bool("gameplay/run_is_toggle")
	Events.setting_changed.connect(_on_setting_changed)
	Events.dialogue_started.connect(_on_busy_started)
	Events.dialogue_finished.connect(_on_busy_finished)
	Events.ui_mode_changed.connect(_on_ui_mode_changed)
	Events.focus_lost.connect(_on_focus_lost)

	Events.player_spawned.emit(self)
	Log.info("character", "Player ready at %s" % str(global_position))


func _exit_tree() -> void:
	Events.player_despawned.emit()


func _physics_process(delta: float) -> void:
	# A climb owns the body outright: no input, no gravity, no sliding. Anything less and the
	# player slides off the ladder the first time the shape below them stops being floor.
	if _climbing:
		climb_step(delta)
		return
	_poll_run_toggle()
	var wish: Vector3 = Vector3.ZERO
	if not _lock.is_locked():
		wish = _read_movement_input()

	var target_speed: float = current_speed()
	var target_velocity: Vector3 = wish * target_speed

	# Accelerate towards the wish velocity, decelerate to a stop with friction.
	var rate: float = acceleration if wish != Vector3.ZERO else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	move_and_slide()

	# STATE BEFORE THE VISUAL, not after. `_update_state` is what decides whether this frame was a
	# walk, a run or a sneak, and since T5.2 the sprite picks its animation BLOCK from that - so
	# updating it afterwards drew every gait one frame late, which is invisible until the block
	# changes and then reads as a flicker on the first frame of every run.
	_update_state(wish)
	if visual != null:
		visual.update_from_velocity(velocity, delta, state)


## Input is read on the horizontal plane, then rotated into the camera's frame.
func _read_movement_input() -> Vector3:
	var raw: Vector2 = Vector2(
		Input.get_axis(Actions.MOVE_LEFT, Actions.MOVE_RIGHT),
		Input.get_axis(Actions.MOVE_UP, Actions.MOVE_DOWN),
	)
	if raw.length_squared() < 0.0001:
		return Vector3.ZERO
	# Clamp rather than normalise, so an analogue stick keeps its partial deflection while
	# two keyboard keys together do not produce faster diagonal movement.
	if raw.length() > 1.0:
		raw = raw.normalized()
	var direction: Vector3 = Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, _camera_yaw())
	return direction


func _camera_yaw() -> float:
	var active: Camera3D = get_viewport().get_camera_3d()
	return active.global_rotation.y if active != null else 0.0


## Public because it is the one honest CONSUMER of an attribute, and a consumer nothing can
## read is a consumer nothing can check: no assertion can drive a physics frame, so the proof
## that PACE changes how fast this body moves is this function asked twice with a flag written
## in between. The windowed probe measures the distance that follows from it.
func current_speed() -> float:
	return _gait_speed() * Attributes.multiplier(character_id, PACE)


func _gait_speed() -> float:
	if Input.is_action_pressed(Actions.SNEAK):
		return sneak_speed
	if _is_running():
		return run_speed
	return walk_speed


## A pure query. It used to poll is_action_just_pressed itself, but it is called twice per
## frame (from _gait_speed and from _update_state), so the toggle flipped twice and never
## changed: toggle-run silently did nothing. Polling now happens once, in _poll_run_toggle.
func _is_running() -> bool:
	if _lock.is_locked():
		return false
	if run_is_toggle:
		return _run_toggled
	return Input.is_action_pressed(Actions.RUN)


## Called once at the top of _physics_process, and nowhere else. Keep it that way.
func _poll_run_toggle() -> void:
	if run_is_toggle and not _lock.is_locked() and Input.is_action_just_pressed(Actions.RUN):
		_run_toggled = not _run_toggled


func _update_state(wish: Vector3) -> void:
	var next: GameEnums.MoveState = state
	if _lock.is_locked():
		next = GameEnums.MoveState.BUSY
	elif not is_on_floor() and velocity.y < -0.5:
		next = GameEnums.MoveState.FALL
	elif wish == Vector3.ZERO:
		next = GameEnums.MoveState.IDLE
	elif Input.is_action_pressed(Actions.SNEAK):
		next = GameEnums.MoveState.SNEAK
	elif _is_running():
		next = GameEnums.MoveState.RUN
	else:
		next = GameEnums.MoveState.WALK

	_enter_state(next)


## The one place `state` is written and the one place the change is announced. Both the
## per-frame update and the authored climb go through it, so a state can never change
## without the rest of the game hearing about it.
func _enter_state(next: GameEnums.MoveState) -> void:
	if next == state:
		return
	state = next
	Events.player_state_changed.emit(state)


## Hand control to something else: dialogue, a screen, a cutscene, an authored climb. The
## token names the borrower, so releasing is something only the borrower can do. Any system
## may call this without this file needing to know which system it was.
##
## Do NOT reintroduce a set_input_locked(bool) convenience over the top of this. The whole
## point is that there is no way to say "unlocked" without saying who you are.
func lock_input(token: StringName) -> void:
	_lock.lock(token)
	velocity.x = 0.0
	velocity.z = 0.0


func release_input(token: StringName) -> void:
	_lock.release(token)


func is_input_locked() -> bool:
	return _lock.is_locked()


## Who is still holding. For a log line when the player mysteriously will not move.
func input_holders() -> Array[StringName]:
	return _lock.holders()


func _on_busy_started(_speaker: StringName) -> void:
	lock_input(&"dialogue")


func _on_busy_finished(_speaker: StringName) -> void:
	release_input(&"dialogue")


## A screen took over. The player does not learn which screen, or care: UiRoot announces the
## mode and this takes or gives back exactly one token for it. A MODAL also pauses the tree,
## so _physics_process stops too - but an OVERLAY does not, and that is the case the token is
## actually for.
func _on_ui_mode_changed(mode: GameEnums.UiMode) -> void:
	if mode == GameEnums.UiMode.GAMEPLAY:
		release_input(&"ui")
	else:
		lock_input(&"ui")


## THE ONE LATCH HERE THE ENGINE CANNOT RELEASE. Godot drops every held key on focus loss
## (measured, T6.5), so a held run ends by itself; a TOGGLED run is this file's own state, and
## left on it sends the player bolting on the first touch of a direction after an alt-tab.
func _on_focus_lost() -> void:
	_run_toggled = false


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay" and key == "run_is_toggle" and value is bool:
		run_is_toggle = value
		_run_toggled = false


# AUTHORED VERTICAL MOVEMENT. There is no jump, so a ladder or a trellis asks the body to
# move between two points and the body does it - deliberately, at a fixed rate, with input
# suspended for the duration.


## May a climb begin? On the floor, and not already climbing. ClimbPoint asks this instead of
## assuming it: whether the body is grounded is the body's own knowledge, and a mid-air climb
## is exactly the free-jump behaviour the design rules out.
func can_climb() -> bool:
	return not _climbing and is_on_floor()


## Start a climb to a world position. Returns false only when one is already running.
##
## The grounded rule is deliberately NOT re-checked here. Refusing is the interactable's job
## and it already asked can_climb(); a cutscene that wants to lift the player off a ledge must
## not be blocked by a rule that exists to shape player movement.
func begin_climb(to: Vector3) -> bool:
	if _climbing:
		return false
	_climbing = true
	_climb_target = to
	# The corner is ALWAYS turned at the top: up-then-over going up, over-then-down coming
	# down. A straight line between the foot of a ladder and the ledge above it passes
	# through the ledge, and because a climb writes global_position directly there is no
	# collision left to stop it - the body would slide through solid stone in full view.
	var lower: Vector3 = to if to.y < global_position.y else global_position
	_climb_waypoint = Vector3(lower.x, maxf(global_position.y, to.y), lower.z)
	_climb_turned = false
	velocity = Vector3.ZERO
	lock_input(&"climb")
	_enter_state(GameEnums.MoveState.CLIMB)
	Log.debug("character", "Climb to %s via %s" % [str(to), str(_climb_waypoint)])
	return true


func is_climbing() -> bool:
	return _climbing


## Advance an in-progress climb by one step. Called from _physics_process, and public so a
## test can drive a climb to completion deterministically instead of waiting on real frames -
## the same reason interactions are tested through attempt() and never through fake input.
func climb_step(delta: float) -> void:
	if not _climbing:
		return
	var step: float = climb_speed * delta
	var before: Vector3 = global_position
	# The corner has to LATCH. Without the flag, the frame after arriving at the waypoint
	# steps off it towards the target, the next frame sees the body is no longer AT the
	# waypoint and steers back, and the climb oscillates on the corner forever - which is
	# exactly what the first version of this did, for 600 test steps.
	if not _climb_turned:
		global_position = global_position.move_toward(_climb_waypoint, step)
		_climb_turned = global_position.is_equal_approx(_climb_waypoint)
		_drive_visual(before, delta)
		return
	global_position = global_position.move_toward(_climb_target, step)
	_drive_visual(before, delta)
	if not global_position.is_equal_approx(_climb_target):
		return
	_climbing = false
	release_input(&"climb")
	_enter_state(GameEnums.MoveState.IDLE)
	if visual != null:
		visual.update_from_velocity(Vector3.ZERO, delta, state)


## THE CLIMB'S OWN ANIMATION TICK, and the reason it has to exist here: `_physics_process`
## returns before the per-frame update while a climb owns the body, so the visual never heard
## about a climb AT ALL. `MoveState.CLIMB` was entered, announced on the bus and passed to
## nothing, which left `SpriteSheetLayout.climb_row` - exported, defaulted, validated by
## `problems()` and asserted since T5.2 - impossible to draw. The velocity is DERIVED from the
## move just applied rather than read off `velocity`, which an authored climb leaves at zero.
func _drive_visual(before: Vector3, delta: float) -> void:
	if visual == null:
		return
	visual.update_from_velocity((global_position - before) / maxf(delta, 0.0001), delta, state)
