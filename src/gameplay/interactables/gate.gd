class_name Gate
extends Interactable
## A door or gate that can be locked. Proves the refusal path: the player presses the button,
## is told *why* nothing happened, and the same button works once the condition is met.
##
## WHY REFUSAL IS A FIRST-CLASS RESULT
## The cheap implementation is to hide the prompt when the gate is locked. That is worse than
## it sounds: the player cannot tell a locked door from scenery, so they never learn there is
## something to come back for. Offering the interaction and refusing it with a reason is what
## turns a wall into a goal.
##
## OWNS: whether it is open, its persistence, and how hard opening it knocks the camera.
## MUST NOT: know how the condition became true, or what is on the other side. It must not
## reach for the player or a global inventory either - it asks whoever is interacting.

const OPEN_FIELD: StringName = &"open"
## How long the shake decays over. Not exported: a gate author decides how HEAVY their gate is,
## and how long a jolt lasts is the template's answer about what a jolt is.
const SHAKE_SECONDS: float = 0.6

## Must be true before this gate will open. Empty means it is never locked.
@export var requires_flag: StringName = &""
## Item the interactor must be carrying. Empty means no item is needed. Checked AFTER
## requires_flag, so a gate the plot has sealed says LOCKED rather than sending the player
## hunting for a key that would not help yet.
@export var requires_item: StringName = &""
## The geometry that physically blocks the way. Disabled and hidden when the gate opens.
@export var blocker: StaticBody3D = null
## Shown when the player is refused, and when it opens.
@export var locked_key: String = "refusal.locked"
@export var opened_key: String = ""
## Once open, stay open. A gate that re-locks itself behind the player is a different object.
@export var stays_open: bool = true
## How hard the camera shakes when this gate opens, as 0..1 of whatever amplitude the area's
## rig authored. ZERO IS THE DEFAULT AND IT MEANS SILENT, which is right for a garden gate and
## wrong for a portcullis - and the template cannot know which one any particular gate is, so
## it is authored per gate rather than decided here. See `Events.camera_shake_requested`.
@export_range(0.0, 1.0, 0.05) var open_shake: float = 0.0

signal opened()


func _ready() -> void:
	verb = GameEnums.InteractVerb.OPEN
	super()
	# Restore across a load before the first frame is drawn, so a gate the player already
	# opened is never briefly shut.
	if is_open():
		_apply_open(false)


func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	if is_open():
		return GameEnums.RefusalReason.ALREADY_DONE
	if requires_flag != &"" and not Flags.get_bool(requires_flag):
		return GameEnums.RefusalReason.LOCKED
	if requires_item != &"" and not _carried_by(_who):
		return GameEnums.RefusalReason.MISSING_ITEM
	return GameEnums.RefusalReason.NONE


func perform(_who: Node3D) -> void:
	var store: PersistentState = state()
	if store != null:
		store.store(OPEN_FIELD, true)
	_apply_open(true)
	# THE ASK IS ON THE BUS AND THE CAMERA IS NOT NAMED HERE. This gate knows how heavy it is
	# and knows nothing about a rig; the rig knows how far it may move and nothing about gates.
	# An area whose scene has no rig simply has no listener, which is correct rather than broken.
	if open_shake > 0.0:
		Events.camera_shake_requested.emit(open_shake, SHAKE_SECONDS)
	if opened_key != "":
		Events.notify_requested.emit(opened_key, 2.5, {})
	opened.emit()


func is_open() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(OPEN_FIELD)


## `announce` is false when restoring a save, so loading does not replay the toast.
func _apply_open(announce: bool) -> void:
	if blocker != null:
		blocker.visible = false
		# Layer zero rather than disabling the node, so anything already resting on it is
		# not left standing on a shape that vanished mid-frame.
		blocker.collision_layer = 0
	if stays_open:
		set_available(false)
	if announce:
		Log.info("interact", "%s opened" % name)


## Asks whoever is interacting, not the player and not a global inventory. A null interactor
## (a test, a scripted trigger) simply is not carrying anything. The key is NOT consumed:
## a spent key with no inventory screen is a state change the player cannot see.
func _carried_by(who: Node3D) -> bool:
	var bag: Inventory = Inventory.of(who)
	return bag != null and bag.has(requires_item)


## Names the item in the refusal message, so MISSING_ITEM says which key is missing instead
## of leaving the player to guess.
func refusal_args(_who: Node3D) -> Dictionary:
	if requires_item == &"":
		return {}
	var definition: ItemDefinition = ItemDb.definition(requires_item)
	return {"item": tr(definition.name_key)} if definition != null else {}


## `locked_key` was DECLARED, validated by check_content and never read by anything until WP-09,
## which is the unwired-@export failure shape gotcha 2 is about: the field existed, an author
## could set it, and the player still got the generic line. Nothing failed, because a message
## that is merely wrong looks exactly like a message that is right.
func refusal_key(_who: Node3D, reason: GameEnums.RefusalReason) -> String:
	return locked_key if reason == GameEnums.RefusalReason.LOCKED else ""
