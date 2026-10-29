extends TestCase
## THE BAG'S COUNT FLAGS ARE ALREADY CURRENT WHEN AN ITEM SIGNAL FIRES.
##
## `Inventory.add` carries a comment saying `_publish()` runs BEFORE either signal, "so nothing
## woken by one reads a flag that still says the old number". `remove` has the identical
## ordering and no comment, and until this file nothing asserted it on either path - so a
## listener that reacted to `item_gained` by reading `bag/<carrier>/<item>` would have read the
## PREVIOUS count, and the only trace would have been an off-by-one in whatever it drew. That is
## the T3.3 mirror's ordering invariant, one level down from the `game_loaded` republish that
## `smoke_test.gd` already covers.
##
## The last assertion is the interesting one: spending the LAST of a stack erases the row rather
## than zeroing it, so "current" there means ABSENT, and the emission tally is what makes a
## missing row distinguishable from a handler that never ran.
##
## OWNS: the ordering between the count-flag publish and `Events.item_gained` / `item_lost`,
##   including the removal that takes the last one and erases the row.
## MUST NOT: assert how a count flag is spelled, how a bag is saved, or anything about an item
##   definition beyond needing one to exist in order to be carried.

## Both in the reserved `fixture_` namespace, so neither can collide with a content id a
## consuming game invents.
const CARRIER: StringName = &"fixture_bag_owner"
const SAVE_ID: StringName = &"fixture_bag"

const ADDED: int = 5
const SPENT: int = 2
## Returned by `get_int` when the row is not there at all, which is what an erase leaves.
const ABSENT: int = -1

var _bag: Inventory = null
var _flag_on_gain: int = ABSENT
var _flag_on_loss: int = ABSENT
var _count_on_gain: int = ABSENT
var _count_on_loss: int = ABSENT
var _losses: int = 0


func run() -> void:
	## 11 rather than 10 since T5.28: the fixture-root check became an ASSERTION instead of a skip,
	## and an assertion is an outcome where a skip was a substitute for ten of them.
	plan(11)
	_the_flag_is_current_when_a_signal_fires()


## Adding, spending some, and spending the rest each leave the mirror correct AT THE INSTANT the
## signal arrives, not one statement later.
func _the_flag_is_current_when_a_signal_fires() -> void:
	## ASSERTED RATHER THAN SKIPPED, per T5.28 and `docs/TESTING.md`. A skip here reports GREEN, so
	## the one condition this check exists to catch — a fixture root that could not be written —
	## would be the one condition nobody sees, and the ten assertions below would silently be
	## testing the developer's own content root instead of the fixtures.
	equal("the fixture content is on disk for the registry to find", Fixtures.activate(), true)
	_open_a_bag()
	var key: StringName = BagKeys.key(CARRIER, FixtureContent.STACK_ITEM)

	equal("a bag accepts a stackable item", _bag.add(FixtureContent.STACK_ITEM, ADDED), true)
	equal("item_gained reported what was added", _count_on_gain, ADDED)
	equal("the flag already read the NEW total inside item_gained", _flag_on_gain, ADDED)

	equal("some of a stack can be spent", _bag.remove(FixtureContent.STACK_ITEM, SPENT), true)
	equal("item_lost reported what was spent", _count_on_loss, SPENT)
	equal("the flag already read the REMAINDER inside item_lost",
		_flag_on_loss, ADDED - SPENT)

	_the_last_one_leaves_no_row(key)
	_close_the_bag(key)


## Spending the rest. `_publish` erases rather than zeroes, so the mirror being current means
## the row is GONE by the time the signal arrives - and the tally is what separates that from
## a handler that was never called.
func _the_last_one_leaves_no_row(key: StringName) -> void:
	var left: int = ADDED - SPENT
	equal("the rest of a stack can be spent", _bag.remove(FixtureContent.STACK_ITEM, left), true)
	equal("item_lost fired for each removal", _losses, 2)
	equal("the row was already erased inside the last item_lost", _flag_on_loss, ABSENT)
	equal("and it is still gone afterwards", Flags.get_int(key, ABSENT), ABSENT)


## A bag of its own, with its own save id: two participants sharing one id means the second
## silently replaces the first, which would make this case's presence break somebody else's.
func _open_a_bag() -> void:
	_bag = Inventory.new()
	_bag.carrier_id = CARRIER
	_bag.save_id = SAVE_ID
	Events.item_gained.connect(_on_gained)
	Events.item_lost.connect(_on_lost)
	attach(_bag)


func _close_the_bag(key: StringName) -> void:
	Events.item_gained.disconnect(_on_gained)
	Events.item_lost.disconnect(_on_lost)
	_bag.clear_all()
	Flags.erase_flag(key)
	_bag.queue_free()
	_bag = null


func _on_gained(item_id: StringName, count: int) -> void:
	_count_on_gain = count
	_flag_on_gain = Flags.get_int(BagKeys.key(CARRIER, item_id), ABSENT)


func _on_lost(item_id: StringName, count: int) -> void:
	_losses += 1
	_count_on_loss = count
	_flag_on_loss = Flags.get_int(BagKeys.key(CARRIER, item_id), ABSENT)
