class_name InteractionSensor
extends Area3D
## Finds what the player could interact with, decides which one they mean, and fires it.
## Lives as a child of the player.
##
## THE ACTUAL PROBLEM THIS SOLVES
## Detection is trivial; *selection* is not. Stand where a sign, a lever and a door all
## overlap and the game must pick the one the player means, let them override it, and never
## silently swap the target while they are reaching for the button. Nearest-wins is not enough:
## a player facing a lever with a sign fractionally closer will press the button and read the
## sign, which reads as a bug.
##
## The ranking is: priority first (authored intent wins), then proximity, then how squarely
## the player is facing it. Ties are broken by node name so the order is stable frame to
## frame rather than dependent on physics callback order.
##
## OWNS: the candidate set, the ranking, the cycle override, hold timing, and the MOMENT the
## player is asked to turn towards what they have selected.
## MUST NOT: know what any interactable does, or contain any object's behaviour. It asks for a
## turn on `Events.turn_requested` naming the body it hangs under; it does not know that body
## has a sprite, a sheet or a facing, and must not learn.
##
## NOTE ON INPUT: this reads input directly. It is a component of the player, and the
## alternative - routing interaction input through PlayerController - would force the
## controller to know about interaction, which its own MUST NOT line forbids.

## THE CONSUMER OF `accessibility/hold_to_confirm`, and the only file that could be. What an
## interaction COSTS in input is this component's business: `Interactable.hold_seconds` is the
## author's per-object answer, and this setting is the player's floor under all of them.
const HOLD_TO_CONFIRM: String = "accessibility/hold_to_confirm"
## The hold a player who asked for one gets on an object the author gave none. Long enough that
## a brushed key cannot fire it, short enough not to feel like the 1.5s a chest asks for.
const FLOOR_SECONDS: float = 0.4
## The speed below which the player counts as standing still, for deciding whether a turn
## towards the prompt's target is worth asking for. Deliberately the same 0.05 m/s
## `CharacterVisual.update_from_velocity` uses to decide whether to re-aim.
const STILL_SPEED: float = 0.05

## How far the player can reach. The Area3D shape should be at least this big.
@export var max_distance: float = 2.4
## How much facing the target matters relative to being close to it. Raise it if selection
## feels like it ignores where the player is looking.
@export var facing_weight: float = 1.2
## Authored priority is worth this much, so a deliberate priority always beats geometry.
@export var priority_weight: float = 100.0

var _candidates: Array[Interactable] = []
var _current: Interactable = null
## The instance id of the target last announced, or 0 for none.
##
## WHY AN ID AND NOT `_current != null`: in Godot 4 a FREED object compares EQUAL to null, so
## a dangling _current reads as "no target" to every == and != in this file - which is exactly
## how a prompt for an object in an unloaded area stayed on screen. An id is a plain int and
## survives the object it names.
var _announced_id: int = 0
var _cycle: int = 0
var _hold: float = 0.0
var _facing: Vector3 = Vector3.FORWARD
## Whether the player was moving on the previous physics frame, so a turn can be asked for at
## the moment they COME TO REST beside something - which is the ordinary way a player arrives
## at an object, and the moment a target-changed test alone would miss entirely.
var _was_moving: bool = false
var _body: CharacterBody3D = null
## Held by whatever has taken interaction away: an open screen, a conversation. Tokens rather
## than a boolean for the same reason the player controller uses them - two holders must not
## be able to release each other.
var _lock: InputLock = InputLock.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.INTERACT_MASK
	monitoring = true
	monitorable = false
	_body = get_parent() as CharacterBody3D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	# This component reads input directly, so it needs its own hold on that input - it cannot
	# borrow the player controller's, because that lives a layer above this one. Same lock
	# class, same tokens, separately held.
	Events.ui_mode_changed.connect(_on_ui_mode_changed)
	Events.dialogue_started.connect(_on_dialogue_started)
	Events.dialogue_finished.connect(_on_dialogue_finished)
	Events.focus_lost.connect(_on_focus_lost)
	Log.info("interact", "Sensor ready, reach %.1fm" % max_distance)


func _physics_process(delta: float) -> void:
	_track_facing()
	_prune()
	var best: Interactable = _select()
	var changed: bool = best != _current
	if changed:
		_current = best
		_cycle = 0
		_hold = 0.0
		_announce()
	_turn_to_target(changed)
	_handle_input(delta)


## The interactable the player would act on right now, or null.
func current() -> Interactable:
	return _current


## SELECT PAST THE CURRENT TARGET, and report whether there was anywhere to go. Returns false
## when the player is beside a single object, which is the ordinary case and not a failure: the
## caller then falls through to the interact key rather than swallowing it.
##
## PUBLIC, AND FOR THE REASON `is_suspended()` IS. The cycle used to live inline in
## `_handle_input`, reachable only by pressing Tab — and the suite is synchronous, so it cannot
## press anything: `Input.parse_input_event` is buffered until a main-loop flush that never
## comes mid-run, and `Input.action_press` does land but leaves the action reading
## `is_action_just_pressed() == true` for the whole run, because the process-frame counter never
## advances inside one `_ready()`. That stuck key then cycles every OTHER case's sensor. So the
## override that every overlapping object rests on was unassertable, and said so in
## `interaction_test.gd`'s own MUST NOT line for four phases. The key binding is still proved
## windowed, by `dev_stage.gd --cycle`; this is the decision it makes.
func cycle() -> bool:
	if _candidates.size() <= 1:
		return false
	_cycle += 1
	_hold = 0.0
	_current = _select()
	_announce()
	# Cycling is a deliberate change of target and always deserves the turn, on the same
	# terms as any other: only while standing, which a cycling player always is.
	_turn_to_target(true)
	return true


## TURN THE PLAYER TOWARDS WHAT THE PROMPT IS OFFERING, at the two moments it means anything:
## the target changed, or they just came to a stop with one selected.
##
## THE STILLNESS GATE IS NOT TASTE, it is the shape of `CharacterVisual`.
## `update_from_velocity` re-aims from velocity every physics frame while the character moves,
## so a turn asked for mid-walk is overwritten on the next frame: it would cost a one-frame
## flicker and buy nothing. And a player crossing a courtyard past a row of objects should keep
## facing where they are going rather than snapping at each one as it takes the prompt.
##
## THE SENSOR ASKS, IT DOES NOT TURN. It emits `Events.turn_requested` naming the body it hangs
## under and lets whatever draws that body answer, so this file still knows nothing about a
## sprite, a sheet or a facing enum - which is what keeps it inside its own MUST NOT line.
func _turn_to_target(target_changed: bool) -> void:
	var still: bool = _is_still()
	var just_stopped: bool = still and _was_moving
	_was_moving = not still
	if not still or not (target_changed or just_stopped):
		return
	if _body == null or not is_instance_valid(_current):
		return
	Events.turn_requested.emit(_body, _current.focus_point())


## Below the same speed `CharacterVisual` treats as standing still, and the constant says so,
## because two files disagreeing by a hundredth about what "moving" means is a turn that is
## asked for and silently undone on the very next frame.
func _is_still() -> bool:
	if _body == null:
		return true
	var flat := Vector2(_body.velocity.x, _body.velocity.z)
	return flat.length_squared() <= STILL_SPEED * STILL_SPEED


## 0.0 to 1.0 while a hold-to-confirm interaction is in progress. The UI draws this.
func hold_progress() -> float:
	var needed: float = hold_needed()
	if needed <= 0.0:
		return 0.0
	return clampf(_hold / needed, 0.0, 1.0)


## How long the current target must be held for, which is the AUTHOR'S value or the player's
## floor, whichever is longer. One function so the progress the prompt draws and the threshold
## that fires can never disagree - reading the setting in both places is how they would.
func hold_needed() -> float:
	if _current == null:
		return 0.0
	var floor_seconds: float = FLOOR_SECONDS if Settings.get_bool(HOLD_TO_CONFIRM) else 0.0
	return maxf(_current.hold_seconds, floor_seconds)


func _handle_input(delta: float) -> void:
	# Suspended, not disabled: selection keeps running so the prompt has a target to redraw
	# the instant control returns, rather than needing the player to step away and back.
	if _lock.is_locked():
		_hold = 0.0
		return
	if _current == null:
		_hold = 0.0
		return

	if Input.is_action_just_pressed(Actions.INTERACT_CYCLE) and cycle():
		return

	var needed: float = hold_needed()
	if needed > 0.0:
		if Input.is_action_pressed(Actions.INTERACT):
			_hold += delta
			if _hold >= needed:
				_hold = 0.0
				_current.attempt(_body)
		else:
			_hold = 0.0
		return

	if Input.is_action_just_pressed(Actions.INTERACT):
		_current.attempt(_body)


## Rank every candidate and return the one the cycle offset points at.
func _select() -> Interactable:
	var ranked: Array[Interactable] = []
	for candidate: Interactable in _candidates:
		if candidate.is_offerable() and _score(candidate) > -INF:
			ranked.append(candidate)
	if ranked.is_empty():
		return null
	# Stable order: score descending, then name, so physics callback order cannot reshuffle
	# the prompt between frames.
	#
	# `String(...)`, AND THE CAST IS THE WHOLE OF WHY THIS LINE IS CORRECT. `Node.name` is a
	# StringName, and `<` on two StringNames compares their INTERNED ADDRESSES rather than
	# their text — so this read `a.name < b.name` for four phases and ordered ties by whichever
	# name the engine happened to intern first, which is script and scene load order. Measured
	# both ways in one run: for the same pair, StringName said `Z_later < A_earlier` and String
	# said the opposite. The comment above was therefore half true — the order was stable within
	# a run, because an address does not move — and half false, because it was never the NAME,
	# so an author numbering two overlapping objects to choose between them was ignored, and the
	# answer could differ between a fresh boot and the same objects reached another way.
	ranked.sort_custom(func(a: Interactable, b: Interactable) -> bool:
		var sa: float = _score(a)
		var sb: float = _score(b)
		if is_equal_approx(sa, sb):
			return String(a.name) < String(b.name)
		return sa > sb)
	return ranked[posmod(_cycle, ranked.size())]


## Higher is better. Returns -INF for anything out of reach.
func _score(target: Interactable) -> float:
	var to_target: Vector3 = target.focus_point() - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	if distance > max_distance:
		return -INF
	var alignment: float = 0.0
	if distance > 0.01:
		alignment = _facing.dot(to_target / distance)
	return float(target.interact_priority) * priority_weight + (max_distance - distance) + alignment * facing_weight


## Remember the last direction the player actually moved, so selection respects where they
## are pointing even while standing still.
func _track_facing() -> void:
	if _body == null:
		return
	var flat: Vector3 = Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	if flat.length_squared() > 0.04:
		_facing = flat.normalized()


## Drop anything freed or removed from the tree while it was in the set.
func _prune() -> void:
	var kept: Array[Interactable] = []
	for candidate: Interactable in _candidates:
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			kept.append(candidate)
	_candidates = kept
	# _current TOO, and this is the part that was missing. Pruning the candidate list alone left
	# a freed node in _current after an area unloaded, and because a freed object compares equal
	# to null, `best != _current` said "unchanged" - so nothing was re-announced and the prompt
	# kept offering an object in an area that no longer existed. Only an area change can produce
	# this, which is why it survived three packages until the second area was built.
	if _announced_id != 0 and not _current_is_live():
		_current = null
		_cycle = 0
		_hold = 0.0
		_announce()


## Valid AND in the tree. A queue_free()d node stays valid until the end of the frame, so
## is_instance_valid alone is not enough to know it is still part of the world.
##
## TAKES NO ARGUMENT, deliberately. A freed instance cannot be PASSED to a parameter typed
## `Interactable` - the call itself fails the argument type check - so a dangling reference
## must never cross a call boundary. Reading the field in place is the only safe form.
func _current_is_live() -> bool:
	return is_instance_valid(_current) and _current.is_inside_tree()


func _announce() -> void:
	# is_instance_valid, not `== null`, for the reason recorded on _announced_id above.
	if not is_instance_valid(_current):
		_announced_id = 0
		Events.interact_target_changed.emit(null, GameEnums.InteractVerb.LOOK, "")
		return
	_announced_id = _current.get_instance_id()
	Events.interact_target_changed.emit(_current, _current.verb, _current.label_key)


func _on_area_entered(area: Area3D) -> void:
	var target: Interactable = area as Interactable
	if target == null or _candidates.has(target):
		return
	_candidates.append(target)
	# An object that unlocks while the player stands next to it must become selectable at
	# once, not after they step away and back.
	if not target.availability_changed.is_connected(_on_availability_changed):
		target.availability_changed.connect(_on_availability_changed)


func _on_area_exited(area: Area3D) -> void:
	var target: Interactable = area as Interactable
	if target == null:
		return
	_candidates.erase(target)
	if target.availability_changed.is_connected(_on_availability_changed):
		target.availability_changed.disconnect(_on_availability_changed)


## Resets the hold and the cycle, exactly as the other two paths that change _current do.
## Without it, a 1.5s hold on a slow chest carried over to an adjacent object that became
## available mid-hold, and fired it on the next physics frame from a hold nobody gave it.
func _on_availability_changed() -> void:
	_current = _select()
	_cycle = 0
	_hold = 0.0
	_announce()


## Is interaction currently taken away? Public so a test can assert the hand-over without
## faking input, which is the same reason interactions are tested through attempt().
func is_suspended() -> bool:
	return _lock.is_locked()


func _on_ui_mode_changed(mode: GameEnums.UiMode) -> void:
	if mode == GameEnums.UiMode.GAMEPLAY:
		_lock.release(&"ui")
	else:
		_lock.lock(&"ui")


## A hold part-way to firing is DROPPED, not paused. The engine releases the key on focus loss
## (measured for a keyboard, T6.5; a pad was not measured), and the next physics frame would then
## zero this - but with the tree paused that frame waits until the player returns, so the reset
## happens here, at the moment, rather than depending on either.
func _on_focus_lost() -> void:
	_hold = 0.0


func _on_dialogue_started(_speaker: StringName) -> void:
	_lock.lock(&"dialogue")


func _on_dialogue_finished(_speaker: StringName) -> void:
	_lock.release(&"dialogue")
