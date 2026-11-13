class_name GearSockets
extends RefCounted
## Gems socketed into pieces of gear (C7.4c). See `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS:
##   - A piece holds as many gems as `GearDefinition.socket_count()` says, plus the sockets its
##     upgrade levels add (`GearUpgrades.extra_sockets`, C7.5).
##   - Socketing a gem uses the gem item up. While the piece is worn, the gem's stat changes are
##     on the wearer, and a gem with an element gives the piece's plain attack that element.
##   - Taking a gem out gives the item back. When the project setting `combat/gear/gem_remover`
##     names an item, taking one out also uses up one of those (a remover). Empty means free.
##
## IT KEEPS NO LIST OF ITS OWN. Each filled socket is one entry in `Flags`:
##     socket/<piece item id>/<index>  ->  the gem's item id
## So it is saved with no new save code, and a new game clears it. It is per piece, not per
## wearer: the gem is in the piece, so whoever wears it next gets the gem too.
##
## HOW A WORN PIECE'S GEMS REACH THE WEARER: socketing or unsocketing always changes the bag, so
## every `GearSet` hears `inventory_changed` and re-lends; `GearLending` then calls `apply`,
## which puts every worn piece's gems on the sheet under one source, `gems`, from scratch.
##
## OWNS: which gem is in which socket, and the gems' share of the wearer's sheet.
## MUST NOT: decide what is worn, draw anything, or name a game's gems or remover.

## Why a gem cannot be socketed or taken out. NONE means it can.
enum Refusal {
	NONE,
	## The piece has no gear file.
	NOT_GEAR,
	## The item has no gem file.
	NOT_GEM,
	## The bag does not hold the gem.
	NOT_CARRIED,
	## Every socket of the piece is filled, or it has none.
	NO_FREE_SOCKET,
	## Nothing is in that socket.
	EMPTY_SOCKET,
	## A remover is needed and the bag holds none.
	NO_REMOVER,
	## The bag cannot take the gem back.
	BAG_FULL,
}

const PREFIX: String = "socket/"
## The source every worn gem's stat changes are held under on the wearer's sheet.
const SOURCE: StringName = &"gems"
## The project setting naming the remover item. Empty means taking a gem out is free.
const REMOVER_SETTING: String = "combat/gear/gem_remover"


## The gems in `piece_id`, by socket index; an empty socket gives an empty id.
static func gems(piece_id: StringName) -> Array[StringName]:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	var out: Array[StringName] = []
	if piece == null:
		return out
	for index: int in piece.socket_count() + GearUpgrades.extra_sockets(piece):
		out.append(StringName(Flags.get_string(_key(piece_id, index))))
	return out


## Why `gem_id` cannot go into `piece_id` from `bag`, or NONE.
static func socket_refusal(bag: Inventory, piece_id: StringName, gem_id: StringName) -> Refusal:
	if GearDb.for_item(piece_id) == null:
		return Refusal.NOT_GEAR
	if GemDb.for_item(gem_id) == null:
		return Refusal.NOT_GEM
	if bag == null or not bag.has(gem_id):
		return Refusal.NOT_CARRIED
	if not gems(piece_id).has(&""):
		return Refusal.NO_FREE_SOCKET
	return Refusal.NONE


## Puts `gem_id` from `bag` into the first free socket of `piece_id`, using the gem up. Returns
## whether it did.
static func socket(bag: Inventory, piece_id: StringName, gem_id: StringName) -> bool:
	if socket_refusal(bag, piece_id, gem_id) != Refusal.NONE:
		return false
	# The socket first, so a set woken by the bag's change already counts the gem.
	Flags.set_flag(_key(piece_id, gems(piece_id).find(&"")), String(gem_id))
	bag.remove(gem_id)
	return true


## Why the gem in socket `index` of `piece_id` cannot be taken out into `bag`, or NONE.
static func removal_refusal(bag: Inventory, piece_id: StringName, index: int) -> Refusal:
	var held: Array[StringName] = gems(piece_id)
	if GearDb.for_item(piece_id) == null:
		return Refusal.NOT_GEAR
	if index < 0 or index >= held.size() or held[index] == &"":
		return Refusal.EMPTY_SOCKET
	var remover: StringName = remover_id()
	if bag == null or (remover != &"" and not bag.has(remover)):
		return Refusal.NO_REMOVER
	if not bag.can_accept(held[index]):
		return Refusal.BAG_FULL
	return Refusal.NONE


## Takes the gem in socket `index` of `piece_id` out into `bag`, using up a remover if one is
## named. Returns whether it did.
static func unsocket(bag: Inventory, piece_id: StringName, index: int) -> bool:
	if removal_refusal(bag, piece_id, index) != Refusal.NONE:
		return false
	var gem_id: StringName = gems(piece_id)[index]
	Flags.erase_flag(_key(piece_id, index))
	if remover_id() != &"":
		bag.remove(remover_id())
	bag.add(gem_id)
	return true


## The remover item, or empty when taking a gem out is free.
static func remover_id() -> StringName:
	return StringName(str(ProjectSettings.get_setting(REMOVER_SETTING, "")))


## The element `piece`'s plain attack lends: the first socketed gem's, else the piece's own.
static func element_of(piece: GearDefinition) -> StringName:
	for gem_id: StringName in gems(piece.item_id):
		var gem: GemDefinition = GemDb.for_item(gem_id)
		if gem != null and gem.element != &"":
			return gem.element
	return piece.strike_element()


## Puts the gems of every piece `gear` has on onto the wearer's sheet, from scratch.
static func apply(gear: GearSet) -> void:
	var fighter: Combatant = Combatant.of(gear.get_parent())
	if fighter == null:
		return
	fighter.sheet.remove_from(SOURCE)
	for piece_id: StringName in gear.worn_ids():
		for gem_id: StringName in gems(piece_id):
			var gem: GemDefinition = GemDb.for_item(gem_id)
			if gem == null:
				continue
			for modifier: StatModifier in gem.modifiers:
				if modifier != null:
					fighter.sheet.add(StatModifier.of(modifier.stat, modifier.op, modifier.value, SOURCE))


static func _key(piece_id: StringName, index: int) -> StringName:
	return StringName("%s%s/%d" % [PREFIX, piece_id, index])
