class_name GearUpgrades
extends RefCounted
## Upgrading and awakening pieces of gear (C7.5). See `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS:
##   - `upgrade` pays the next level's cost from the bag and raises the piece one level, up to
##     its cap (`GearDefinition.upgrade_cap`).
##   - While the piece is worn, every level it has reached gives the wearer more: a share of
##     the piece's added amounts again, the level's own stat changes (both under `upgrades`),
##     and more sockets for gems.
##   - A power can wait for a level: `Power.requires_upgrade` is checked by `unlocks`.
##   - `awaken`, at the cap, turns the piece into the one its track names, paying the track's
##     awakening cost. The new piece starts at level 0.
##
## IT KEEPS NO LIST OF ITS OWN. A piece's level is one entry in `Flags`:
##     upgrade/<piece item id>  ->  the level
## So it is saved with no new save code, and a new game clears it. Like a socket, it is per
## piece, not per wearer.
##
## HOW A NEW LEVEL REACHES THE WEARER: the level is written first, then the cost is taken from
## the bag. Every level costs something, so every `GearSet` hears `inventory_changed` and
## re-lends, and `GearLending` calls `apply`, which puts every worn piece's gains on the sheet
## from scratch.
##
## OWNS: a piece's level, its gains, and the awakening swap.
## MUST NOT: decide what is worn, draw anything, or name a game's gear.

## Why a piece cannot be upgraded or awakened. NONE means it can.
enum Refusal {
	NONE,
	## The item has no gear file.
	NOT_GEAR,
	## The piece has no upgrade track.
	NO_TRACK,
	## The piece is at its cap already (upgrading).
	CAPPED,
	## The piece is below its cap, or its track awakens into nothing (awakening).
	NOT_READY,
	## The bag does not hold the piece, or the cost.
	COST,
	## The bag cannot take the awakened piece.
	BAG_FULL,
}

const PREFIX: String = "upgrade/"
## The source every worn piece's upgrade gains are held under on the wearer's sheet.
const SOURCE: StringName = &"upgrades"


## The level `piece_id` has reached, 0 when it was never upgraded.
static func level(piece_id: StringName) -> int:
	return Flags.get_int(_key(piece_id))


## Why `piece_id` cannot go up a level, paying from `bag`, or NONE.
static func refusal(bag: Inventory, piece_id: StringName) -> Refusal:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	if piece == null:
		return Refusal.NOT_GEAR
	if piece.upgrade == null:
		return Refusal.NO_TRACK
	if level(piece_id) >= piece.upgrade_cap():
		return Refusal.CAPPED
	if not _affords(bag, piece.upgrade.levels[level(piece_id)].items):
		return Refusal.COST
	return Refusal.NONE


## Raises `piece_id` one level, paying from `bag`. Returns whether it did.
static func upgrade(bag: Inventory, piece_id: StringName) -> bool:
	if refusal(bag, piece_id) != Refusal.NONE:
		return false
	var reached: int = level(piece_id)
	# The level first, so a set woken by the bag's change already counts it.
	Flags.set_flag(_key(piece_id), reached + 1)
	_pay(bag, GearDb.for_item(piece_id).upgrade.levels[reached].items)
	return true


## Why `piece_id` cannot be awakened from `bag`, or NONE.
static func awaken_refusal(bag: Inventory, piece_id: StringName) -> Refusal:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	if piece == null:
		return Refusal.NOT_GEAR
	if piece.upgrade == null:
		return Refusal.NO_TRACK
	if piece.upgrade.awaken_into == &"" or level(piece_id) < piece.upgrade_cap():
		return Refusal.NOT_READY
	if bag == null or not bag.has(piece_id) or not _affords(bag, piece.upgrade.awaken_items):
		return Refusal.COST
	if not bag.can_accept(piece.upgrade.awaken_into):
		return Refusal.BAG_FULL
	return Refusal.NONE


## Turns `piece_id` in `bag` into the piece its track awakens into, paying the track's cost.
## The old piece's level is forgotten. Returns whether it did.
static func awaken(bag: Inventory, piece_id: StringName) -> bool:
	if awaken_refusal(bag, piece_id) != Refusal.NONE:
		return false
	var track: UpgradeTrack = GearDb.for_item(piece_id).upgrade
	Flags.erase_flag(_key(piece_id))
	_pay(bag, track.awaken_items)
	bag.remove(piece_id)
	bag.add(track.awaken_into)
	return true


## The sockets `piece` has gained from its levels.
static func extra_sockets(piece: GearDefinition) -> int:
	var out: int = 0
	for step: UpgradeLevel in _reached(piece):
		out += step.sockets
	return out


## True when `power` needs no upgrade, or a piece worn under `body` that carries it (its kit
## lists the power, or it is the power's `requires_gear`) has reached the level it needs.
static func unlocks(body: Node, power: Power) -> bool:
	if power.requires_upgrade <= 0:
		return true
	var gear: GearSet = GearSet.of(body)
	if gear == null:
		return false
	for piece_id: StringName in gear.worn_ids():
		var piece: GearDefinition = GearDb.for_item(piece_id)
		var carries: bool = piece_id == power.requires_gear or (piece != null and piece.kit != null
				and piece.kit.powers.has(power))
		if carries and level(piece_id) >= power.requires_upgrade:
			return true
	return false


## Puts the upgrade gains of every piece `gear` has on onto the wearer's sheet, from scratch.
static func apply(gear: GearSet) -> void:
	var fighter: Combatant = Combatant.of(gear.get_parent())
	if fighter == null:
		return
	fighter.sheet.remove_from(SOURCE)
	for piece_id: StringName in gear.worn_ids():
		var piece: GearDefinition = GearDb.for_item(piece_id)
		if piece == null:
			continue
		var bonus: float = 0.0
		var gains: Array[StatModifier] = []
		for step: UpgradeLevel in _reached(piece):
			bonus += step.stat_bonus
			gains.append_array(step.modifiers)
		for modifier: StatModifier in piece.all_modifiers():
			if modifier != null and modifier.op == StatModifier.Op.ADD and bonus != 0.0:
				gains.append(StatModifier.of(modifier.stat, modifier.op, modifier.value * bonus, SOURCE))
		for gain: StatModifier in gains:
			if gain != null:
				fighter.sheet.add(StatModifier.of(gain.stat, gain.op, gain.value, SOURCE))


# The levels `piece` has reached, lowest first, never past its cap.
static func _reached(piece: GearDefinition) -> Array[UpgradeLevel]:
	var out: Array[UpgradeLevel] = []
	if piece == null or piece.upgrade == null:
		return out
	for i: int in mini(level(piece.item_id), piece.upgrade_cap()):
		if piece.upgrade.levels[i] != null:
			out.append(piece.upgrade.levels[i])
	return out


static func _affords(bag: Inventory, cost: Dictionary[StringName, int]) -> bool:
	if bag == null:
		return false
	for item_id: StringName in cost:
		if not bag.has(item_id, cost[item_id]):
			return false
	return true


static func _pay(bag: Inventory, cost: Dictionary[StringName, int]) -> void:
	for item_id: StringName in cost:
		bag.remove(item_id, cost[item_id])


static func _key(piece_id: StringName) -> StringName:
	return StringName(PREFIX + String(piece_id))
