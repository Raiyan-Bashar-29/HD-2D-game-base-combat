extends TestCase
## The item catalogue, the inventory, and whether every computed localization key resolves.
##
## FIXTURES, NOT THE DEMO. The inventory blocks run against `FixtureContent`'s three items, so
## they still run in a checkout with `data/` deleted. What genuinely asserts things about the
## DEMO catalogue - that the scan finds what is on disk, that authored names are translated -
## is gated on the demo existing and skipped loudly when it is not.
##
## OWNS: assertions about content data and carrying it.
## MUST NOT: assert about world objects - pickups and containers are pickups_test.

const UNIQUE: StringName = FixtureContent.UNIQUE_ITEM
const STACKS: StringName = FixtureContent.STACK_ITEM
const SPARE: StringName = FixtureContent.SPARE_ITEM
const GHOST: StringName = &"item/nope"

var _carrier: Node3D = null
var _bag: Inventory = null
var _gained: Array = []
var _changes: int = 0


func run() -> void:
	plan(50)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	_the_authored_catalogue_is_sound()
	_authored_names_are_translated()
	Fixtures.activate()
	_the_registry_finds_fixture_content()
	_build_carrier()
	_inventory()
	_signals()
	_save_round_trip()
	_computed_keys_resolve()
	_tear_down()


## The claim under test is docs/ARCHITECTURE.md's "adding the fiftieth item must not touch a
## single line of code". So this counts the files on disk rather than hard-coding three: add a
## fourth .tres and this case still passes, which is the whole point. It also cross-checks the
## undocumented ResourceLoader.list_directory against a plain DirAccess listing, so a change
## in either fails here instead of silently shrinking the catalogue.
func _the_authored_catalogue_is_sound() -> void:
	if not Fixtures.has_demo_content():
		skip("the authored catalogue is sound", "no content in data/items", 3)
		return
	ItemDb.rescan()
	equal("catalogue has no problems: %s" % str(ItemDb.problems()),
		ItemDb.problems().is_empty(), true)
	var on_disk: int = 0
	for file_name: String in DirAccess.get_files_at(ItemDb.content_dir):
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			on_disk += 1
	equal("registry found every definition on disk", ItemDb.count(), on_disk)
	equal("the scan and a plain DirAccess listing agree",
		ContentScan.resource_paths(ItemDb.content_dir).size(), on_disk)


## Every authored item must have a row in strings.csv. Fixture items deliberately do NOT, so
## this can only be asked of real content, and it is asked before the fixtures are switched in.
func _authored_names_are_translated() -> void:
	if not Fixtures.has_demo_content():
		skip("authored item names are translated", "no content in data/items", 1)
		return
	var missing: int = 0
	for item_id: StringName in ItemDb.all():
		var definition: ItemDefinition = ItemDb.definition(item_id)
		if tr(definition.name_key) == definition.name_key:
			missing += 1
			Log.warn("test", "no translation for %s" % definition.name_key)
	equal("every item name has a translation", missing, 0)


## The fixtures go out through ResourceSaver and come back through the registry's own directory
## scan, so this also proves the .tres round trip a consuming game authors into.
func _the_registry_finds_fixture_content() -> void:
	equal("the fixture catalogue has no problems: %s" % str(ItemDb.problems()),
		ItemDb.problems().is_empty(), true)
	# Asked for, not written down: adding a fixture item must not mean editing a number here.
	equal("every fixture item loaded", ItemDb.count(), FixtureContent.items().size())
	var key_def: ItemDefinition = ItemDb.definition(UNIQUE)
	equal("the unique item exists", key_def != null, true)
	equal("its id survived the round trip", key_def.id, UNIQUE)
	equal("it is unique", key_def.is_unique(), true)
	equal("it is a key item", key_def.category, GameEnums.ItemCategory.KEY_ITEM)
	equal("and reports its category by name", key_def.category_name(), "KEY_ITEM")
	equal("the stacking item kept its limit",
		ItemDb.definition(STACKS).max_stack, FixtureContent.STACK_LIMIT)

	# A typo is a null, not a crash.
	equal("unknown id returns null", ItemDb.definition(GHOST), null)
	equal("unknown id is not has()", ItemDb.has(GHOST), false)


## A bare Node3D, not the player scene: this also proves Inventory.of() works on any carrier,
## which is the reason it is a component rather than an autoload.
func _build_carrier() -> void:
	_carrier = Node3D.new()
	_bag = Inventory.new()
	# Set before add_child: _ready registers with SaveSystem under this id, and colliding with
	# the real player's "inventory" would make one of them silently never save.
	_bag.save_id = &"test_bag"
	_carrier.add_child(_bag)
	add_child(_carrier)
	equal("of() finds the bag on its carrier", Inventory.of(_carrier), _bag)
	var empty_carrier: Node3D = Node3D.new()
	equal("of() on a carrier with no bag is null", Inventory.of(empty_carrier) == null, true)
	empty_carrier.free()
	equal("of(null) is null", Inventory.of(null) == null, true)


func _inventory() -> void:
	equal("starts empty", _bag.total_count(), 0)
	equal("add three", _bag.add(STACKS, 3), true)
	equal("count reflects it", _bag.count_of(STACKS), 3)
	equal("has enough", _bag.has(STACKS, 3), true)
	equal("does not have more", _bag.has(STACKS, 4), false)
	equal("stacks onto the same entry", _bag.add(STACKS, 2), true)
	equal("stacked count", _bag.count_of(STACKS), 5)
	equal("one distinct item", _bag.distinct_count(), 1)

	# max_stack is the only capacity rule while capacity itself is unlimited.
	equal("cannot exceed max_stack", _bag.add(STACKS, FixtureContent.STACK_LIMIT), false)
	equal("refused add changed nothing", _bag.count_of(STACKS), 5)
	equal("a unique item can be held once", _bag.add(UNIQUE), true)
	equal("but not twice", _bag.add(UNIQUE), false)
	equal("an unknown item is refused", _bag.add(GHOST), false)

	equal("remove some", _bag.remove(STACKS, 2), true)
	equal("count after remove", _bag.count_of(STACKS), 3)
	equal("cannot remove more than held", _bag.remove(STACKS, 99), false)
	equal("failed remove changed nothing", _bag.count_of(STACKS), 3)
	equal("removing all erases the entry", _bag.remove(STACKS, 3), true)
	equal("entry gone", _bag.count_of(STACKS), 0)
	equal("only the unique item remains", _bag.distinct_count(), 1)

	# Order is category then id, so a future UI has a stable grouping that does not shift
	# with the display language.
	_bag.add(SPARE, 1)
	var order: Array[StringName] = _bag.ids()
	equal("key items sort before materials", order[0], UNIQUE)


func _signals() -> void:
	_gained = []
	_changes = 0
	var on_gain: Callable = func(id: StringName, n: int) -> void: _gained.append([id, n])
	var on_change: Callable = func() -> void: _changes += 1
	Events.item_gained.connect(on_gain)
	Events.inventory_changed.connect(on_change)

	_bag.add(STACKS, 2)
	equal("item_gained fired once", _gained.size(), 1)
	equal("item_gained carried the count added, not the total", _gained[0][1], 2)
	equal("inventory_changed fired", _changes, 1)

	# A refused add must be completely silent, or a UI would flicker on every failed grab.
	_bag.add(UNIQUE)
	equal("a refused add emits nothing", _changes, 1)

	Events.item_gained.disconnect(on_gain)
	Events.inventory_changed.disconnect(on_change)


func _save_round_trip() -> void:
	SaveSystem.unregister(&"world")
	var slot: int = SaveSystem.MAX_SLOTS - 2
	equal("save the bag", SaveSystem.save_to_slot(slot), OK)

	var held: int = _bag.count_of(STACKS)
	_bag.clear_all()
	equal("scrambled", _bag.total_count(), 0)

	equal("load the bag", SaveSystem.load_from_slot(slot), OK)
	equal("the stack was restored", _bag.count_of(STACKS), held)
	equal("and the unique item", _bag.has(UNIQUE), true)
	SaveSystem.delete_slot(slot)


## Verb and refusal keys are BUILT at runtime from enum names, so no text-scanning validator
## can ever follow them. An enum loop is the only thing that can, and tr() returning the key
## unchanged is exactly how a missing translation presents. Engine keys, so no demo needed.
func _computed_keys_resolve() -> void:
	var verbs: Array = GameEnums.InteractVerb.keys()
	var missing_verbs: int = 0
	for index: int in verbs.size():
		var raw: String = verbs[index]
		var key: String = "verb.%s" % raw.to_lower()
		if tr(key) == key:
			missing_verbs += 1
			Log.warn("test", "no translation for %s" % key)
	equal("every InteractVerb has a translation", missing_verbs, 0)

	var reasons: Array = GameEnums.RefusalReason.keys()
	var missing_reasons: int = 0
	for index: int in reasons.size():
		var raw: String = reasons[index]
		# refusal.none is deliberately blank: NONE means "allowed", so it is never displayed.
		if raw == "NONE":
			continue
		var key: String = "refusal.%s" % raw.to_lower()
		if tr(key) == key:
			missing_reasons += 1
			Log.warn("test", "no translation for %s" % key)
	equal("every RefusalReason has a translation", missing_reasons, 0)

	# The substitution the toast relies on. Without it a pickup could not name what was taken.
	equal("toast placeholder substitutes",
		tr("notify.item_taken").format({"item": "Thing"}).contains("Thing"), true)


func _tear_down() -> void:
	_carrier.free()
	_carrier = null
	_bag = null
