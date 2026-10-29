extends TestCase
## Equipment: what a carrier holds READY, the slot exclusivity, and the seam that lets a gate
## require it with no code at all. Also the two authored refusal lines that were declared,
## validated and read by nothing until this package.
##
## WHY THERE IS NO SAVE-SECTION BLOCK HERE and there is one in pickups_test: `Equipment` owns no
## dictionary. Every slot is a flag, so the save round trip is `Flags`', which core_test already
## covers. What is asserted below is the part that could still be wrong — that a flag arriving
## back through a load makes the component report the item held again, and that revalidation on
## the same load does not stow it on the way past.
##
## FIXTURES, NOT THE DEMO. Three equippable fixture items, two of them sharing a slot, and the
## traversal proof is a `Gate` built here with an abstract object id. Nothing in this file names
## a lantern, an arch or an area, and `check_boundary` scans it.
##
## OWNS: assertions about equipping, slots, equipment-gated traversal, and the authored refusal.
## MUST NOT: re-assert inventory arithmetic (items_test) or how a screen draws a row
## (screens_test).

const SLOT: int = 4
const HELD: StringName = FixtureContent.HELD_ITEM
const OTHER: StringName = FixtureContent.OTHER_HELD_ITEM
const WORN: StringName = FixtureContent.WORN_ITEM
const PLAIN: StringName = FixtureContent.UNIQUE_ITEM
const GHOST: StringName = &"item/fixture_absent"

var _carrier: Node3D = null
var _bag: Inventory = null
var _worn: Equipment = null

## The last equipment_changed, recorded in typed fields rather than an untyped Array of Arrays:
## indexing a Variant is exactly the unsafe access this project compiles as an error.
var _emissions: int = 0
var _last_wearer: StringName = &""
var _last_slot: GameEnums.EquipSlot = GameEnums.EquipSlot.NONE
var _last_item: StringName = &""


func run() -> void:
	plan(70)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	SaveSystem.unregister(&"world")
	_build_carrier()
	_what_may_be_held()
	_holding_and_stowing()
	_one_item_per_slot()
	_losing_it_stows_it()
	_it_survives_a_reload()
	_a_gate_gated_on_a_held_item()
	_an_authored_refusal_line()
	_tear_down()


## Equipment is a sibling of the bag under one carrier, exactly as the player scene wires it.
func _build_carrier() -> void:
	_carrier = Node3D.new()
	_bag = Inventory.new()
	_bag.save_id = &"test_bag"
	_carrier.add_child(_bag)
	_worn = Equipment.new()
	_worn.wearer_id = &"test_wearer"
	_carrier.add_child(_worn)
	add_child(_carrier)


func _what_may_be_held() -> void:
	equal("of() finds the component by type", Equipment.of(_carrier), _worn)
	equal("of() on nothing is null", Equipment.of(null), null)
	equal("a carrier with no slots answers null", Equipment.of(_bag), null)
	equal("nothing is held to begin with", _worn.count(), 0)

	equal("an equippable item knows its slot", _worn.slot_of(HELD), GameEnums.EquipSlot.LIGHT)
	equal("a garment knows its own", _worn.slot_of(WORN), GameEnums.EquipSlot.GARMENT)
	equal("an ordinary item has no slot", _worn.slot_of(PLAIN), GameEnums.EquipSlot.NONE)
	equal("nor has an id with no definition", _worn.slot_of(GHOST), GameEnums.EquipSlot.NONE)

	# THE SEAM: carrying is a precondition, so an equippable item nobody holds is refused.
	equal("an item not carried cannot be held", _worn.can_equip(HELD), false)
	equal("equipping it fails", _worn.equip(HELD), false)
	equal("and nothing is held", _worn.count(), 0)
	equal("pick it up", _bag.add(HELD), true)
	equal("now it may be held", _worn.can_equip(HELD), true)
	equal("an ordinary item may never be held", _worn.can_equip(PLAIN), false)


func _holding_and_stowing() -> void:
	Events.equipment_changed.connect(_on_changed)

	equal("equipping succeeds", _worn.equip(HELD), true)
	equal("it is held", _worn.is_equipped(HELD), true)
	equal("the slot names it", _worn.equipped_in(GameEnums.EquipSlot.LIGHT), HELD)
	equal("one thing is held", _worn.count(), 1)
	equal("it announced once", _emissions, 1)
	equal("naming this wearer", _last_wearer, _worn.wearer_id)
	equal("and the item", _last_item, HELD)
	equal("and its slot", _last_slot, GameEnums.EquipSlot.LIGHT)

	# The load-bearing invariant: it stays in the bag, so nothing that asks the bag is lied to.
	equal("it is still carried", _bag.has(HELD), true)

	equal("equipping it again changes nothing", _worn.equip(HELD), false)
	equal("and announced nothing further", _emissions, 1)

	equal("stowing succeeds", _worn.unequip(HELD), true)
	equal("nothing is held", _worn.count(), 0)
	# ERASED, not set false: an empty slot leaves no row in the save file at all.
	equal("and the flag is gone entirely", Flags.has_flag(_worn.key(HELD)), false)
	equal("the announcement named an empty slot", _last_item, &"")
	equal("stowing again changes nothing", _worn.unequip(HELD), false)

	equal("toggle holds it", _worn.toggle(HELD), true)
	equal("so it is held", _worn.is_equipped(HELD), true)
	equal("toggle stows it", _worn.toggle(HELD), true)
	equal("so it is stowed", _worn.is_equipped(HELD), false)
	equal("toggling something that may never be held does nothing", _worn.toggle(PLAIN), false)

	Events.equipment_changed.disconnect(_on_changed)


func _one_item_per_slot() -> void:
	equal("carry the second light", _bag.add(OTHER), true)
	equal("carry the garment", _bag.add(WORN), true)
	equal("hold the first light", _worn.equip(HELD), true)
	equal("hold the second", _worn.equip(OTHER), true)
	# The occupant is STOWED rather than the newcomer refused.
	equal("the first was displaced", _worn.is_equipped(HELD), false)
	equal("the slot names the second", _worn.equipped_in(GameEnums.EquipSlot.LIGHT), OTHER)
	equal("still only one thing held", _worn.count(), 1)

	equal("a garment is a different slot", _worn.equip(WORN), true)
	equal("so both are held at once", _worn.count(), 2)
	equal("the light is untouched", _worn.equipped_in(GameEnums.EquipSlot.LIGHT), OTHER)
	equal("and the garment is its own", _worn.equipped_in(GameEnums.EquipSlot.GARMENT), WORN)
	# Joined rather than compared as an Array, so a failure prints what the order actually was.
	equal("the ids come back sorted", ",".join(_worn.equipped_ids()),
		"%s,%s" % [String(OTHER), String(WORN)])
	equal("NONE is not a slot anything occupies", _worn.equipped_in(GameEnums.EquipSlot.NONE),
		&"")


## The price of leaving the item in the bag, and it is paid in one place.
func _losing_it_stows_it() -> void:
	equal("drop the garment", _bag.remove(WORN), true)
	equal("it stowed itself", _worn.is_equipped(WORN), false)
	equal("the light is still held", _worn.is_equipped(OTHER), true)
	equal("one thing held", _worn.count(), 1)


## Not a save-section test — there is no save section. What is asserted is that a flag coming
## back through `Flags` makes the component report the item held again, and that the
## revalidation triggered by the same load does not stow it in passing.
func _it_survives_a_reload() -> void:
	equal("save", SaveSystem.save_to_slot(SLOT), OK)
	Flags.erase_flag(_worn.key(OTHER))
	equal("scrambled", _worn.is_equipped(OTHER), false)
	equal("load", SaveSystem.load_from_slot(SLOT), OK)
	equal("it is held again", _worn.is_equipped(OTHER), true)
	equal("and the bag still has it, so revalidation left it alone", _bag.has(OTHER), true)


## THE POINT OF THE PACKAGE: traversal gated on what is in hand, with no new code in `Gate`.
## The gate reads a flag, and `Equipment` happens to be what writes this one — the same
## indirection that lets a lever open a door without either knowing the other exists.
func _a_gate_gated_on_a_held_item() -> void:
	var gate: Gate = build("res://scenes/objects/gate.tscn") as Gate
	gate.object_id = &"t_dark_gate"
	gate.label_key = "fixture.gate.label"
	gate.requires_flag = _worn.key(HELD)
	attach(gate)

	equal("the wrong light is in hand", _worn.is_equipped(HELD), false)
	equal("so the gate is locked", gate.refusal(_carrier), GameEnums.RefusalReason.LOCKED)
	equal("attempting it fails", gate.attempt(_carrier), false)
	equal("carrying it is not enough", _bag.has(HELD), true)
	equal("the gate is still shut", gate.is_open(), false)

	equal("put it in hand", _worn.equip(HELD), true)
	equal("the gate is satisfied", gate.refusal(_carrier), GameEnums.RefusalReason.NONE)
	equal("and it opens", gate.attempt(_carrier), true)
	equal("it is open", gate.is_open(), true)
	gate.free()


## `Gate.locked_key` and `PathAction.refusal_key` were both declared, both validated by
## `check_content`, and read by NOTHING until this package — the unwired-@export shape gotcha 2
## is about. The assertion is that the override returns the authored key for the reason it
## belongs to and "" for every other reason, because "" is what makes the UI fall back to the
## `refusal.<reason>` line it computes from the enum.
func _an_authored_refusal_line() -> void:
	var gate: Gate = build("res://scenes/objects/gate.tscn") as Gate
	gate.object_id = &"t_worded_gate"
	gate.requires_flag = _worn.key(GHOST)
	gate.locked_key = "fixture.gate.locked"
	attach(gate)

	equal("it is locked", gate.refusal(_carrier), GameEnums.RefusalReason.LOCKED)
	equal("and offers its authored line",
		gate.refusal_key(_carrier, GameEnums.RefusalReason.LOCKED), "fixture.gate.locked")
	equal("but not for a reason it was not written for",
		gate.refusal_key(_carrier, GameEnums.RefusalReason.MISSING_ITEM), "")

	var plain: Pickup = build("res://scenes/objects/pickup.tscn") as Pickup
	plain.object_id = &"t_plain"
	plain.item = ItemDb.definition(PLAIN)
	attach(plain)
	equal("an object with no authored line offers none",
		plain.refusal_key(_carrier, GameEnums.RefusalReason.LOCKED), "")
	plain.free()
	gate.free()


func _on_changed(wearer: StringName, slot: GameEnums.EquipSlot, item_id: StringName) -> void:
	_emissions += 1
	_last_wearer = wearer
	_last_slot = slot
	_last_item = item_id


func _tear_down() -> void:
	SaveSystem.delete_slot(SLOT)
