class_name TriggerVolume
extends Area3D
## A region of the world that fires when someone walks into it. The other half of interaction:
## the sign waits to be pressed, this one waits to be crossed.
##
## WHY IT DOES NOT KNOW WHAT IT DOES
## The obvious design is `@export var scene_to_play` or `@export var door_to_open`, and it is
## the same trap the lever avoids. A trigger that names its consequence can only ever have
## that one consequence, and the second time two things must react - a quest step *and* a
## camera move - the coupling has to be undone. So a trigger does exactly two things: it sets
## a world flag, and it announces itself on the bus. Anything at all may watch either. This is
## also why it is not an Interactable: nobody presses it, so it has no verb, no prompt and no
## refusal - it is a fact about a place, not an offer.
##
## FIRE ONCE OR EVERY TIME. `fires_once` is the default because the common case is a one-time
## beat: entering a courtyard for the first time, crossing a threshold that starts a scene. A
## repeating trigger is for a region you want to keep being told about, like an ambience zone.
##
## IT ARMS A COUPLE OF PHYSICS FRAMES LATE, and that is not a detail. A spawning player exists
## at the area's origin for one frame before the director puts them on their spawn marker, so
## a trigger anywhere near that origin fires on load, every load, and announces something the
## player never did. Verified, not theorised: the courtyard dais trigger toasted at spawn from
## three metres away before this delay existed. Anything still standing inside when it does
## arm is treated as having entered, which is what a save reloaded inside a region should do.
##
## OWNS: whether it has fired, whether it is still listening, and its persistence.
## MUST NOT: know what its firing causes, run gameplay logic, or touch the UI beyond asking
## for a toast by key.

const FIRED_FIELD: StringName = &"fired"
## Physics frames between entering the tree and listening. Two, because the spawn placement
## lands on the frame after the area is added and the body must be settled before the sweep.
const ARM_DELAY_FRAMES: int = 2

## Identity for persistence, forwarded to the PersistentState child in _enter_tree. Without
## it a one-shot trigger re-fires every time the area is reloaded.
@export var object_id: StringName = &""
## After firing once, stop listening. False makes it fire on every entry.
@export var fires_once: bool = true
## Set true when this fires, so anything may watch without holding a reference to this node.
## Empty keeps the firing purely local to the object and the bus.
@export var world_flag: StringName = &""
## Optional toast shown on firing. A localization key, never raw text.
@export var notify_key: String = ""
## Seconds the toast stays up. Ignored when notify_key is empty.
@export_range(0.5, 8.0, 0.5) var notify_seconds: float = 3.0

## Local listeners. The bus carries the global announcement.
signal fired(who: Node3D)

var _disarmed: bool = false
var _arming: int = 0


func _ready() -> void:
	# A detector, not a target: it watches for bodies and is itself invisible to the
	# interaction sensor, which only looks at Layers.INTERACTABLE.
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	monitoring = false
	body_entered.connect(_on_body_entered)
	# Restore across a load before the first frame, so a trigger the player already crossed
	# is never armed again - and without replaying its toast.
	if fires_once and has_fired():
		_disarmed = true
		set_physics_process(false)
		return
	_arming = ARM_DELAY_FRAMES


func _physics_process(_delta: float) -> void:
	_arming -= 1
	if _arming > 0:
		return
	monitoring = true
	set_physics_process(false)


## True once this trigger has fired, and still true after a save and reload.
func has_fired() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(FIRED_FIELD)


## True when this trigger will never fire again. A one-shot that has gone off, including one
## restored from a save. Distinct from `monitoring`, which is briefly false while arming.
func is_disarmed() -> bool:
	return _disarmed


## The PersistentState child, if there is one. A trigger without one cannot remember anything,
## which is correct for a repeating ambience volume and wrong for a one-shot story beat.
func state() -> PersistentState:
	return get_node_or_null(^"PersistentState") as PersistentState


## Do the firing. Public, and separate from the body_entered handler, so a test drives it the
## way pickups_test drives attempt(): directly, never through simulated movement.
## Returns false when a one-shot trigger has already gone off.
func fire(who: Node3D) -> bool:
	if fires_once and has_fired():
		return false
	var store: PersistentState = state()
	if store != null:
		store.store(FIRED_FIELD, true)
	if world_flag != &"":
		Flags.set_flag(world_flag, true)
	if notify_key != "":
		Events.notify_requested.emit(notify_key, notify_seconds, {})
	fired.emit(who)
	Events.trigger_fired.emit(object_id, who)
	Log.info("world", "%s fired" % name)
	if fires_once:
		disarm()
	return true


## Stop listening for good. Deferred because body_entered arrives mid-physics-flush, and
## changing monitoring inside that callback is blocked by the engine with "Function blocked
## during in/out signal" - the node would stay armed and the error would scroll past.
func disarm() -> void:
	_disarmed = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)


## _enter_tree runs before any child's _ready, so PersistentState sees the id in time to
## validate it. Doing it in _ready would be too late. Same contract as Interactable.
func _enter_tree() -> void:
	if object_id == &"":
		return
	var store: PersistentState = state()
	if store != null:
		store.object_id = object_id


func _on_body_entered(body: Node3D) -> void:
	fire(body)
