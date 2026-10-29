class_name Equipment
extends Node
## What one carrier is holding READY, as opposed to merely carrying. A COMPONENT beside
## `Inventory`, on the same reasoning: `Equipment.of(who)` resolves from the interactor the
## interaction contract already hands over, so an NPC or a follower can have one and no
## interactable needs a global.
##
## IT OWNS NO DICTIONARY. Every slot lives in `Flags`, namespaced per carrier:
##     equip/<wearer_id>/<item id>        -> true
## which is `PersistentState`'s shape (`obj/<area>/<object>/<field>`) and `Standing`'s reasoning
## (`standing/<who>`) applied to a third case. Three things fall out of it, and together they are
## the whole argument for this over a `Dictionary[EquipSlot, StringName]` plus a save section:
##
##   1. IT IS ALREADY SAVED. No `SaveSystem.register`, no save version, no migration. A flag
##      round-trips through machinery that is already tested, and a new game clears it for free
##      because `Director.start_new_game()` clears flags.
##   2. A GATE CAN REQUIRE IT WITH NO CODE. Point a gate's `requires_flag` at one of these keys
##      and traversal is gated on a held lantern — and `Gate` was not touched to make that work.
##      Nor was the dialogue runner, nor `QuestStep`, so "carry a light to the dark place" is
##      authorable as a quest step. Same seam WP-08 built quests on.
##   3. IT IS ANNOUNCED ALREADY. `flag_changed` fires, so `QuestTracker` re-derives and a
##      condition re-evaluates, and nothing had to learn that equipment exists.
##
## The cost, stated rather than hidden: the key contains an item id, so that id becomes a public
## identifier the way an `object_id` is. Renaming an item's `.tres` invalidates a save's memory
## of it being HELD — the item itself survives, because `Inventory` deliberately keeps counts
## whose definition vanished, but it comes back stowed. That is a strictly smaller blast radius
## than the alternative, which writes the same id into a save section of its own anyway.
##
## THE ITEM STAYS IN THE BAG WHILE IT IS EQUIPPED, and this is the load-bearing invariant.
## Moving it out would make equipment a second place items live: `Inventory.count_of()` would
## begin lying, `Gate.requires_item` would refuse a key that is in the player's hand, and every
## caller of `has()` would have to ask two questions. So equipping is PURELY a flag — and the
## consequence is that losing the item has to stow it, which is `_revalidate` at the foot.
##
## OWNS: the key shape, which slots are exclusive, and the rule that you hold what you carry.
## MUST NOT: keep a copy of what is equipped, decide what any slot MEANS, know what an item
## does, or reach for the player. What a lantern is FOR is a gate's question, not this file's.

const CATEGORY: String = "equipment"
const PREFIX: String = "equip/"

## Unique per carrier, and it namespaces every flag this component writes. A second wearer — an
## NPC, a follower, a mannequin — MUST override it, or two carriers share one set of slots.
@export var wearer_id: StringName = &"player"


func _ready() -> void:
	# Stow anything that left the bag. Connected to `inventory_changed` rather than to
	# `item_lost` because that is the one signal EVERY path emits, a restored save included, and
	# a revalidation that missed a path would leave a flag claiming the carrier holds what they
	# no longer have — which a gate would then honour.
	Events.inventory_changed.connect(_revalidate)


func _exit_tree() -> void:
	if Events.inventory_changed.is_connected(_revalidate):
		Events.inventory_changed.disconnect(_revalidate)


## The one way anything finds a carrier's slots. Scans by type, exactly as `Inventory.of` does,
## so renaming the node cannot silently disconnect it.
static func of(who: Node) -> Equipment:
	if who == null:
		return null
	for child: Node in who.get_children():
		var worn: Equipment = child as Equipment
		if worn != null:
			return worn
	return null


## The flag key for one item on this carrier. Public because it is the thing an AUTHOR writes
## into a gate, and a shape nobody should have to reconstruct from a header.
func key(item_id: StringName) -> StringName:
	return StringName("%s%s/%s" % [PREFIX, wearer_id, item_id])


func is_equipped(item_id: StringName) -> bool:
	return Flags.get_bool(key(item_id))


## NONE for an item that cannot be equipped, and NONE for an id with no definition at all — a
## missing definition is not a new slot.
func slot_of(item_id: StringName) -> GameEnums.EquipSlot:
	var definition: ItemDefinition = ItemDb.definition(item_id)
	if definition == null:
		return GameEnums.EquipSlot.NONE
	return definition.equip_slot


## THE SEAM, and the analogue of `Inventory.can_accept`. Every caller asks this one question
## before offering anything, so a strength requirement, a two-handed rule or a story gate goes
## HERE and nowhere else — no item and no caller changes.
func can_equip(item_id: StringName) -> bool:
	if slot_of(item_id) == GameEnums.EquipSlot.NONE:
		return false
	var bag: Inventory = Inventory.of(get_parent())
	return bag != null and bag.has(item_id)


## Returns whether anything CHANGED, not whether it is now equipped, so a caller that asked
## twice can tell that the second call did nothing.
func equip(item_id: StringName) -> bool:
	if not can_equip(item_id) or is_equipped(item_id):
		return false
	var slot: GameEnums.EquipSlot = slot_of(item_id)
	# One item per slot. The one already there is STOWED rather than the new one refused: a
	# refusal would make swapping a light a two-step operation for no reason the player can see.
	var occupant: StringName = equipped_in(slot)
	if occupant != &"":
		unequip(occupant)
	Flags.set_flag(key(item_id), true)
	Log.info(CATEGORY, "%s equipped '%s'" % [wearer_id, item_id])
	Events.equipment_changed.emit(wearer_id, slot, item_id)
	return true


## ERASES the flag rather than setting it false, so an empty slot leaves no row in the save file
## at all — the same reason `Standing` stores nothing for someone never met.
func unequip(item_id: StringName) -> bool:
	if not is_equipped(item_id):
		return false
	var slot: GameEnums.EquipSlot = slot_of(item_id)
	Flags.erase_flag(key(item_id))
	Log.info(CATEGORY, "%s stowed '%s'" % [wearer_id, item_id])
	Events.equipment_changed.emit(wearer_id, slot, &"")
	return true


## What a UI row does. Returns whether anything changed, so a row that could do neither reads as
## inert rather than reporting a success it did not have.
func toggle(item_id: StringName) -> bool:
	if is_equipped(item_id):
		return unequip(item_id)
	return equip(item_id)


## The item in a slot, or empty. DERIVED by scanning this carrier's flags rather than kept in a
## dictionary — `flags.gd` says derive what can be derived, and a slot table would be a second
## truth that a save restoring only the flags would leave stale.
func equipped_in(slot: GameEnums.EquipSlot) -> StringName:
	if slot == GameEnums.EquipSlot.NONE:
		return &""
	for item_id: StringName in equipped_ids():
		if slot_of(item_id) == slot:
			return item_id
	return &""


## Sorted, so a UI and an assertion both get a stable order out of a Dictionary that has none.
##
## `sort_custom` THROUGH `String`, NOT `sort()`. `Array[StringName].sort()` orders by the
## StringName's internal handle, not alphabetically — measured here: the two fixture ids came
## back reversed and the only trace was a failing assertion. `Inventory.ids()` already sorts its
## ids the same way and for the same reason, which is what made the cause findable in a minute.
func equipped_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var scope: String = "%s%s/" % [PREFIX, wearer_id]
	for flag: StringName in Flags.with_prefix(scope):
		if Flags.get_bool(flag):
			out.append(StringName(String(flag).trim_prefix(scope)))
	out.sort_custom(_before)
	return out


func _before(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


func count() -> int:
	return equipped_ids().size()


## Stow anything no longer carried. This is the price of leaving the item in the bag, and it is
## deliberately paid here in one place rather than by every caller of `Inventory.remove`.
##
## It runs on a restored save too, and it is safe in either participant order: if `Inventory`
## applies first this stows against the OLD flags and `Flags` then overwrites the result, and if
## `Flags` applies first the check is already against the restored bag.
func _revalidate() -> void:
	var bag: Inventory = Inventory.of(get_parent())
	if bag == null:
		return
	for item_id: StringName in equipped_ids():
		if not bag.has(item_id):
			Log.info(CATEGORY, "%s no longer carries '%s' — stowing it" % [wearer_id, item_id])
			unequip(item_id)
