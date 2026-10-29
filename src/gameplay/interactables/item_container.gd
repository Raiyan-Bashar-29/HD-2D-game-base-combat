class_name ItemContainer
extends Interactable
## A chest, basket or shelf that hands its whole contents over in one press.
##
## NOT NAMED `Container`. That is a native Godot class (the Control base), and
## `class_name Container` is a parse error that cascades into every subclass as "could not
## resolve class" - the same trap as Area3D's native `priority`, which is why the base's field
## is `interact_priority`. Verified against the engine's own class list before naming this.
##
## WHY TAKE-ALL, AND WHY THE TOAST DOES NOT LIST THE CONTENTS
## A per-slot transfer screen needs pause semantics and an input-context stack, neither of
## which has a home yet, so take-all is a complete honest interaction instead of a stub.
## A comma-joined list of names is not translatable: list punctuation and word order differ by
## language, and a joined string cannot be pluralised. The toast queue also holds only four,
## so a five-item chest would silently drop lines. So one distinct item gets named, several
## get one line, and the per-item detail is already on the bus as item_gained for a future log.
##
## ALL OR NOTHING: refusal() checks the contents in aggregate, so perform() cannot partially
## fail and "emptied" can never be a lie. That is what keeps persistence to a single boolean
## instead of a per-slot remainder table.
##
## OWNS: what it holds, and whether it has been emptied.
## MUST NOT: know who emptied it beyond a Node3D, or how anything is displayed.

const EMPTIED_FIELD: StringName = &"emptied"
const TAKEN_ONE_KEY: String = "notify.item_taken"
const TAKEN_ALL_KEY: String = "notify.container_emptied"

## Repeat a definition to hold several of it. A parallel count array would be a bug farm, and
## a second Resource type does not earn its keep until a chest holds twenty of something.
@export var contents: Array[ItemDefinition] = []
@export var display_seconds: float = 2.5


func _ready() -> void:
	verb = GameEnums.InteractVerb.OPEN
	super()
	if contents.is_empty():
		Log.warn("item", "%s has no contents" % name)
	# Restore before the first frame, without replaying the toast.
	if is_emptied():
		set_available(false)


func refusal(who: Node3D) -> GameEnums.RefusalReason:
	if is_emptied():
		return GameEnums.RefusalReason.ALREADY_DONE
	var bag: Inventory = Inventory.of(who)
	if bag == null:
		return GameEnums.RefusalReason.HANDS_FULL
	# Aggregated: two of the same item must fit TOGETHER, not each on its own.
	var wanted: Dictionary[StringName, int] = totals()
	for item_id: StringName in wanted:
		if not bag.can_accept(item_id, wanted[item_id]):
			return GameEnums.RefusalReason.HANDS_FULL
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	var bag: Inventory = Inventory.of(who)
	if bag == null:
		return
	var wanted: Dictionary[StringName, int] = totals()
	for item_id: StringName in wanted:
		if not bag.add(item_id, wanted[item_id]):
			# Unreachable unless refusal() and add() disagree, which would be a real defect.
			Log.error("item", "%s could not hand over %s after refusal passed" % [name, item_id])
	var store: PersistentState = state()
	if store != null:
		store.store(EMPTIED_FIELD, true)
	set_available(false)
	_announce(wanted)


func is_emptied() -> bool:
	var store: PersistentState = state()
	return store != null and store.fetch_bool(EMPTIED_FIELD)


## What this container would hand over, collapsed to one entry per item. Public so a test can
## assert against it without duplicating the counting.
func totals() -> Dictionary[StringName, int]:
	var wanted: Dictionary[StringName, int] = {}
	for definition: ItemDefinition in contents:
		if definition == null:
			continue
		var item_id: StringName = definition.id
		wanted[item_id] = (wanted[item_id] if wanted.has(item_id) else 0) + 1
	return wanted


func _announce(wanted: Dictionary[StringName, int]) -> void:
	if wanted.size() != 1:
		Events.notify_requested.emit(TAKEN_ALL_KEY, display_seconds, {})
		return
	for item_id: StringName in wanted:
		var definition: ItemDefinition = ItemDb.definition(item_id)
		if definition != null:
			Events.notify_requested.emit(TAKEN_ONE_KEY, display_seconds, {"item": tr(definition.name_key)})
