class_name Interactable
extends Area3D
## The contract every interactable object in the game satisfies. Subclass it, override two
## methods, and the sensor, the prompt and the refusal messaging all work with no further code.
##
## WHY A THIN BASE CLASS AND NOT A COMPONENT
## Composition is the default in this project, but interaction needs a *typed* contract: the
## sensor has to ask "can I?" and "do it" on an unknown object, and warnings-as-errors forbids
## calling a method on an untyped value. A duck-typed component would need casts at every call
## site. One shallow base class, with behaviour and state pushed into children, gets the type
## safety without an inheritance tree. Subclasses must stay thin.
##
## TO ADD A NEW KIND OF INTERACTABLE:
##     extends Interactable
##     func refusal(who: Node3D) -> GameEnums.RefusalReason:   # optional
##     func perform(who: Node3D) -> void:                       # the actual effect
##
## Everything else - detection, ranking, the prompt, the refusal toast, one-shot handling,
## hold-to-confirm - is already handled.
##
## OWNS: its own eligibility and effect, and its prompt text.
## MUST NOT: know who is interacting beyond a Node3D, reach for the player directly, or drive
## the UI. It answers questions and performs an effect; the sensor and the UI observe.

## Shown on the prompt. Presentational only; `perform()` decides what actually happens.
@export var verb: GameEnums.InteractVerb = GameEnums.InteractVerb.LOOK
## Localization key for the object's name, e.g. "object.sign.gate.label". Never raw text.
@export var label_key: String = ""
## Breaks ties when several objects overlap. Higher wins before distance is considered.
## NOT named `priority`: Area3D already defines that natively, for physics/audio override
## ordering, and redefining it is a parse error.
@export var interact_priority: int = 0
## Set false to make the object present but inert, e.g. a door sealed by the plot.
@export var available: bool = true
## After a successful interaction, stop offering it. For a note you only read once.
@export var one_shot: bool = false
## Identity for persistence, forwarded to the PersistentState child. Exported here so an
## instanced object scene sets its id with one root-level override, instead of an edit to a
## child node that hand-authored scenes cannot express robustly.
@export var object_id: StringName = &""
## Above zero, the player must hold the button this long. For deliberate or dangerous actions.
@export_range(0.0, 3.0, 0.05) var hold_seconds: float = 0.0

## Emitted after a successful interaction. Local listeners only; the bus carries the
## global announcement.
signal interacted(who: Node3D)
## Emitted when this object's eligibility changes, so the sensor can re-rank immediately.
signal availability_changed()


func _ready() -> void:
	# A target, not a sensor: it is detectable but detects nothing itself.
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	if label_key == "":
		Log.warn("interact", "%s has no label_key, so its prompt will be blank" % name)


## Override to gate the interaction. Return NONE to allow it. The reason is passed to the UI
## so the player is told *why*, instead of the button silently doing nothing.
func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	return GameEnums.RefusalReason.NONE


## Override with the actual effect. Called only after `refusal()` returned NONE.
func perform(_who: Node3D) -> void:
	Log.warn("interact", "%s performs nothing; override perform()" % name)


## Can this be offered at all right now? The sensor uses this for ranking, before refusal.
func is_offerable() -> bool:
	return available and is_inside_tree()


## The point the sensor measures distance to. Override for a large object whose origin is not
## where the player should stand, like a wide gate.
func focus_point() -> Vector3:
	return global_position


## Run the interaction, with all the shared bookkeeping. The sensor calls this; subclasses
## should not override it.
func attempt(who: Node3D) -> bool:
	if not is_offerable():
		return false
	var reason: GameEnums.RefusalReason = refusal(who)
	if reason != GameEnums.RefusalReason.NONE:
		var reason_names: Array = GameEnums.RefusalReason.keys()
		Log.debug("interact", "%s refused: %s" % [name, str(reason_names[reason])])
		Events.interaction_refused.emit(self, reason, refusal_args(who), refusal_key(who, reason))
		return false

	Events.interaction_started.emit(self)
	perform(who)
	if one_shot:
		set_available(false)
	Events.interaction_finished.emit(self)
	interacted.emit(who)
	Log.debug("interact", "%s interacted" % name)
	return true


## Change availability and tell the sensor, so a door that just unlocked is offered without
## the player having to step away and back.
func set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	availability_changed.emit()


## The `PersistentState` child, if this object has one. Returns null for objects whose state
## is not worth saving, which is most scenery.
func state() -> PersistentState:
	return get_node_or_null(^"PersistentState") as PersistentState


## _enter_tree runs top-down, before any child's _ready, so PersistentState sees the id in
## time to validate it. Doing this in _ready would be too late: the child would already have
## logged "no object_id".
func _enter_tree() -> void:
	if object_id == &"":
		return
	var store: PersistentState = state()
	if store != null:
		store.object_id = object_id


## Placeholder values for the refusal message. Override when a reason needs to name something:
## MISSING_ITEM tells the player nothing unless it says which item. The base returns nothing,
## which is correct for LOCKED and ALREADY_DONE.
func refusal_args(_who: Node3D) -> Dictionary:
	return {}


## An AUTHORED line for this refusal, replacing the generic one the UI computes from the reason.
## Empty — the base answer, and the right answer for almost everything — means "use
## refusal.<reason>".
##
## WHY THIS EXISTS AT ALL, given `RefusalReason` already names why. Because a reason is a
## CATEGORY and a message is a sentence. `refusal.locked` reads "it will not budge, something
## holds it shut", which is true of every locked thing in every game and specific to none of
## them; a gate whose author wrote "it is pitch dark beyond" is saying something the enum
## cannot. The alternative was a new enum value per authored line, which is a category per
## sentence — exactly the growth the closed sets in `GameEnums` exist to prevent.
##
## `reason` is a parameter, not a lookup, because one object refuses for several reasons and
## only some of them have a line worth writing.
func refusal_key(_who: Node3D, _reason: GameEnums.RefusalReason) -> String:
	return ""
