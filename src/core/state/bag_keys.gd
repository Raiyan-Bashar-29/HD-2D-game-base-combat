class_name BagKeys
extends RefCounted
## The shape of the flag that says how many of something a carrier holds. Nothing else.
##
##     bag/<carrier_id>/<item id>        bag/player/item/brass_lantern -> 2
##
## WHY THIS IS ITS OWN FILE, AND IT IS THE WHOLE REASON THE PACKAGE WORKS
## Three unrelated places need this shape and no two of them may reconstruct it: `Inventory`
## WRITES it, `tools/check_content.gd` PARSES it back to validate the item id a quest step
## names, and a test asserts on it. A format built twice is a format that disagrees once, and
## the disagreement would surface as a quest that will not complete for an item the player is
## plainly carrying. So the builder and the parser live in one file, beside each other.
##
## WHY IT IS NOT ON `Inventory`, WHICH IS WHERE `Equipment.PREFIX` SITS
## `check_content.gd` runs under `--headless --script`, where autoload IDENTIFIERS do not
## resolve. `Inventory` touches `Log`, `Events`, `Flags` and `SaveSystem`, so a tool that named
## `Inventory.PREFIX` would fail to COMPILE — see check_content.gd's own header, which calls
## that a real mechanical enforcement of the layer rule rather than a style note. This file
## touches no autoload for exactly that reason, and it must stay that way.
##
## WHY THE CARRIER COMES BEFORE THE ITEM. The sixth use of the namespace-over-`Flags` shape,
## after `PersistentState`'s obj/<area>/<object>/<field>, `Standing`'s standing/<who>,
## `Equipment`'s equip/<wearer>/<item>, `WorldMap`'s map/<area> and `Attributes`'
## attr/<who>/<name>. Most general part first, as flags.gd's naming rule says, so one carrier's
## whole bag is one `Flags.with_prefix` away and a stash cannot collide with a player.
##
## AN ITEM ID CONTAINS A SLASH, which is what makes parsing worth a function at all:
## `item/rose_petal` is two segments, so the carrier is the FIRST segment after the prefix and
## the item id is everything left. Splitting on the last slash would answer `rose_petal`.
##
## OWNS: building and parsing this one key shape.
## MUST NOT: read or write a flag, know what an item is, touch an autoload, or grow a second
## key shape. A key for something that is not an item count belongs in its own file.

const PREFIX: String = "bag/"


## Every key for one carrier shares this. What `Flags.with_prefix` is handed.
static func scope(carrier_id: StringName) -> String:
	return "%s%s/" % [PREFIX, carrier_id]


## The key holding how many of `item_id` this carrier has. Public because it is what an AUTHOR
## writes into a quest step, and a shape nobody should have to reconstruct from a header.
static func key(carrier_id: StringName, item_id: StringName) -> StringName:
	return StringName("%s%s" % [scope(carrier_id), item_id])


static func is_bag_key(flag: StringName) -> bool:
	return item_of(flag) != &""


## The carrier a key belongs to, or empty when the flag is not one of ours.
static func carrier_of(flag: StringName) -> StringName:
	var rest: String = String(flag)
	if not rest.begins_with(PREFIX):
		return &""
	rest = rest.trim_prefix(PREFIX)
	var at: int = rest.find("/")
	return StringName(rest.substr(0, at)) if at > 0 else &""


## The item id a key names, or empty when the flag is not one of ours. An empty carrier or an
## empty item id both answer empty, so `bag//x` and `bag/player/` are refused rather than
## producing a half-parsed id that a validator would then look up and fail to find.
static func item_of(flag: StringName) -> StringName:
	var carrier: StringName = carrier_of(flag)
	if carrier == &"":
		return &""
	return StringName(String(flag).trim_prefix(scope(carrier)))
