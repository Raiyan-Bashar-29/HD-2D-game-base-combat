extends TestCase
## The world-to-inventory loop: taking an item, emptying a chest, and a gate that wants a key.
## Driven by direct attempt() calls, never simulated input.
##
## FIXTURES, NOT THE DEMO. Every item here comes from `FixtureContent`, and the object ids and
## label keys are abstract, so this case says nothing about any particular game. A `Pickup` is
## HANDED its definition rather than looking one up, but a chest hands ids to an `Inventory`,
## which does look them up - so the fixture content root is switched on for the whole case.
##
## OWNS: assertions about item-bearing world objects.
## MUST NOT: re-assert inventory arithmetic - that is items_test.

const SLOT: int = 2
const UNIQUE: StringName = FixtureContent.UNIQUE_ITEM
const STACKS: StringName = FixtureContent.STACK_ITEM
const SPARE: StringName = FixtureContent.SPARE_ITEM

var _carrier: Node3D = null
var _bag: Inventory = null


func run() -> void:
	plan(38)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	SaveSystem.unregister(&"world")
	_build_carrier()
	_pickup()
	_container()
	_gate_wants_a_key()
	_tear_down()


func _build_carrier() -> void:
	_carrier = Node3D.new()
	_bag = Inventory.new()
	_bag.save_id = &"test_bag"
	_carrier.add_child(_bag)
	add_child(_carrier)


func _pickup() -> void:
	var pickup: Pickup = _make_pickup(&"t_key")
	equal("pickup is offered", pickup.is_offerable(), true)
	equal("pickup allows the take", pickup.refusal(_carrier), GameEnums.RefusalReason.NONE)
	equal("nobody carrying it is refused", pickup.refusal(null), GameEnums.RefusalReason.HANDS_FULL)
	equal("take succeeds", pickup.attempt(_carrier), true)
	equal("the item is in the bag", _bag.has(UNIQUE), true)
	equal("the pickup knows it is taken", pickup.is_taken(), true)
	equal("and stops being offered", pickup.is_offerable(), false)
	equal("and is invisible", pickup.visible, false)
	equal("state landed under its object id", Flags.get_bool(&"obj/global/t_key/taken"), true)
	equal("taking it again is refused", pickup.attempt(_carrier), false)

	# Persistence, both halves: the count and the world flag must both come back.
	equal("save", SaveSystem.save_to_slot(SLOT), OK)
	_bag.clear_all()
	Flags.set_flag(&"obj/global/t_key/taken", false)
	equal("load", SaveSystem.load_from_slot(SLOT), OK)
	equal("the item is still carried", _bag.has(UNIQUE), true)
	equal("and the world still knows it was taken", Flags.get_bool(&"obj/global/t_key/taken"), true)

	# A rebuilt pickup is what an area reload produces. It must not reappear.
	pickup.free()
	var rebuilt: Pickup = _make_pickup(&"t_key")
	equal("a rebuilt pickup is already taken", rebuilt.is_taken(), true)
	equal("and is not offered again", rebuilt.is_offerable(), false)
	rebuilt.free()


func _container() -> void:
	var chest: ItemContainer = _make_chest(&"t_chest")
	equal("chest totals collapse duplicates", chest.totals().size(), 2)
	equal("chest allows the take", chest.refusal(_carrier), GameEnums.RefusalReason.NONE)
	equal("chest empties", chest.attempt(_carrier), true)
	equal("two of the stacking item taken", _bag.count_of(STACKS), 2)
	equal("one of the spare taken", _bag.count_of(SPARE), 1)
	equal("chest is emptied", chest.is_emptied(), true)
	equal("chest stops being offered", chest.is_offerable(), false)
	equal("chest refuses as ALREADY_DONE", chest.refusal(_carrier), GameEnums.RefusalReason.ALREADY_DONE)

	# The real test of a refusal is not that it said no, but that it handed nothing over.
	equal("a second attempt fails", chest.attempt(_carrier), false)
	equal("and gave nothing more", _bag.count_of(STACKS), 2)

	chest.free()
	var rebuilt: ItemContainer = _make_chest(&"t_chest")
	equal("a rebuilt chest is still empty", rebuilt.is_emptied(), true)
	equal("and is not offered again", rebuilt.is_offerable(), false)
	rebuilt.free()


func _gate_wants_a_key() -> void:
	# The bag currently holds the unique item from _pickup, so start by proving the refusal path
	# with an item nobody has.
	var gate: Gate = build("res://scenes/objects/gate.tscn") as Gate
	gate.object_id = &"t_keyed_gate"
	gate.label_key = "fixture.gate.label"
	gate.requires_item = SPARE
	attach(gate)

	_bag.remove(SPARE, _bag.count_of(SPARE))
	equal("gate wants an item nobody carries", gate.refusal(_carrier), GameEnums.RefusalReason.MISSING_ITEM)
	equal("a null interactor carries nothing", gate.refusal(null), GameEnums.RefusalReason.MISSING_ITEM)
	equal("attempt fails", gate.attempt(_carrier), false)
	equal("gate stayed shut", gate.is_open(), false)
	equal("the refusal names the item", DictRead.get_string(gate.refusal_args(_carrier), "item") != "", true)

	equal("pick the required item up", _bag.add(SPARE), true)
	equal("gate is satisfied", gate.refusal(_carrier), GameEnums.RefusalReason.NONE)
	equal("gate opens", gate.attempt(_carrier), true)
	equal("gate is open", gate.is_open(), true)
	# Not consumed: a key spent invisibly is a state change the player cannot see.
	equal("the key was not eaten", _bag.has(SPARE), true)
	gate.free()


func _make_pickup(object_id: StringName) -> Pickup:
	var pickup: Pickup = build("res://scenes/objects/pickup.tscn") as Pickup
	pickup.object_id = object_id
	pickup.item = ItemDb.definition(UNIQUE)
	attach(pickup)
	return pickup


func _make_chest(object_id: StringName) -> ItemContainer:
	var chest: ItemContainer = build("res://scenes/objects/chest.tscn") as ItemContainer
	chest.object_id = object_id
	chest.label_key = "fixture.chest.label"
	var stock: Array[ItemDefinition] = []
	stock.append(ItemDb.definition(STACKS))
	stock.append(ItemDb.definition(STACKS))
	stock.append(ItemDb.definition(SPARE))
	chest.contents = stock
	attach(chest)
	return chest


func _tear_down() -> void:
	SaveSystem.delete_slot(SLOT)
	_carrier.free()
	_carrier = null
	_bag = null
	Flags.clear_all()
