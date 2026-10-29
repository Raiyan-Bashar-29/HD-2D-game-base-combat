class_name Pickup
extends Interactable
## An item lying in the world, waiting to be taken.
##
## WHY IT HOLDS A DEFINITION AND NOT AN ID STRING
## An @export typed as ItemDefinition puts the .tres into the area scene's ext_resource
## block, so `--headless --import` fails loudly on a dangling reference and the editor offers
## a picker instead of a name to mistype. An id string defers both to runtime, where a typo
## becomes a pickup that refuses forever with no explanation. Verified: Resource-typed
## exports resolve correctly from hand-authored .tscn files, unlike Node-typed ones.
##
## WHY IT DOES NOT FREE ITSELF
## A taken pickup goes invisible, unmonitorable and unavailable, and stays in the tree. The
## interaction sensor may still hold a reference to it inside the very call that took it, and
## a freed node that something still points at is the least debuggable failure available. The
## cost is one Area3D with monitoring off per looted item. If a fully-looted area ever
## measures, _vanish() is the single place to add queue_free().
##
## OWNS: which item it is, how many, and whether it has been taken.
## MUST NOT: know who took it beyond a Node3D, how the inventory stores anything, or how the
## confirmation is displayed.

const TAKEN_FIELD: StringName = &"taken"
const TAKEN_KEY: String = "notify.item_taken"

@export var item: ItemDefinition = null
@export_range(1, 99, 1) var count: int = 1
@export var display_seconds: float = 2.0


func _ready() -> void:
	verb = GameEnums.InteractVerb.TAKE
	# A pickup with no label of its own is named after the item it holds, so placing the
	# fiftieth item needs no extra localization key and no extra authoring step. Set before
	# super(), or the base's "no label_key" warning fires on a pickup that has one.
	if label_key == "" and item != null:
		label_key = item.name_key
	super()
	if item == null:
		Log.error("item", "%s has no item definition — it will never be offered" % name)
		available = false
		return
	if state() == null:
		Log.warn("item", "%s has no PersistentState — it will return after a reload" % name)
	# Restore before the first frame, so an item already taken never flickers into view.
	if is_taken():
		_vanish()


func refusal(who: Node3D) -> GameEnums.RefusalReason:
	if is_taken():
		return GameEnums.RefusalReason.ALREADY_DONE
	var bag: Inventory = Inventory.of(who)
	if bag == null or not bag.can_accept(item.id, count):
		return GameEnums.RefusalReason.HANDS_FULL
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	var bag: Inventory = Inventory.of(who)
	if bag == null or not bag.add(item.id, count):
		return
	var store: PersistentState = state()
	if store != null:
		store.store(TAKEN_FIELD, true)
	_vanish()
	# tr() on a key this object owns, not a literal: the no-raw-strings rule forbids literal
	# player-facing text, not looking up a key. The toast substitutes {item}.
	Events.notify_requested.emit(TAKEN_KEY, display_seconds, {"item": tr(item.name_key)})


func is_taken() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(TAKEN_FIELD)


## Out of the world without leaving the tree. Availability goes first, so the sensor re-ranks
## in the same frame rather than holding a prompt for something that is gone.
func _vanish() -> void:
	set_available(false)
	monitorable = false
	visible = false
