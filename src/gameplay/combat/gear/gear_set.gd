class_name GearSet
extends Node
## The gear one fighter is wearing (C7.1a). A child of the fighter's body, beside its
## `Combatant`. See `docs/GEAR.md` Part 1.
##
## IN PLAIN WORDS:
##   - Wearing a piece puts its stat changes on the wearer, and taking it off removes them.
##   - Each slot holds one piece. Wearing a second piece in a full slot takes the first one off.
##   - The piece stays in the bag while it is worn. Losing the item takes it off.
##   - What is worn is saved, and is back on after a load. A new game starts with nothing worn.
##
## IT KEEPS NO LIST OF ITS OWN. Like upstream's `Equipment`, every worn piece is one entry in
## `Flags`:
##     gear/<wearer id>/<item id>  ->  the slot it is worn in
## So it is saved with no new save code, a new game clears it, and a gate or a quest step can
## ask for a worn piece by that key. The wearer id is the fighter's `combatant_id`. A party
## member's field body and its battle copy share that id, so both wear the same gear.
##
## WHY NOT `Equipment`: its slots are upstream's enum, which has no weapon or armour slot on
## purpose, and this fork may not edit it. The two do not touch each other.
##
## OWNS: the key shape, one piece per slot, and the worn pieces' modifiers on the stat sheet.
## MUST NOT: decide what a stat means, draw anything, or name a game's gear.

## Why a piece cannot be worn. NONE means it can.
enum Refusal {
	NONE,
	## The item has no gear file, so it is not gear.
	NOT_GEAR,
	## The wearer has a bag and the item is not in it.
	NOT_CARRIED,
	## The piece lists its wearers and this fighter is not one, or there is no fighter here.
	WRONG_WEARER,
	## None of the piece's slots is in this set's slot list.
	NO_SLOT,
}

const CATEGORY: String = "gear"
const PREFIX: String = "gear/"

## The slot list. Null means the defaults in `GearRules`.
@export var rules: GearRules

# The sources this set has put on the stat sheet, so a refresh removes exactly them.
var _applied: Array[StringName] = []


func _ready() -> void:
	if rules == null:
		rules = GearRules.new()
	refresh()


# Connected on entering the tree and not in `_ready`, because a party switch moves this node to
# another body, and that leaves the tree and enters it again.
func _enter_tree() -> void:
	if not Events.game_started.is_connected(refresh):
		Events.game_started.connect(refresh)
		Events.game_loaded.connect(_on_game_loaded)
		Events.inventory_changed.connect(_revalidate)


func _exit_tree() -> void:
	if Events.game_started.is_connected(refresh):
		Events.game_started.disconnect(refresh)
		Events.game_loaded.disconnect(_on_game_loaded)
		Events.inventory_changed.disconnect(_revalidate)


## The worn set on a body, or null. It looks by type, so renaming the node cannot lose it.
static func of(who: Node) -> GearSet:
	if who == null:
		return null
	for child: Node in who.get_children():
		var found: GearSet = child as GearSet
		if found != null:
			return found
	return null


## The flag that says this wearer wears `item_id`. Public because an author writes it into a
## gate or a quest step.
func key(item_id: StringName) -> StringName:
	return StringName("%s%s/%s" % [PREFIX, _wearer(), item_id])


## Why `item_id` cannot be worn here, or NONE. Every caller asks this one question, so a new
## rule (a level, a curse) goes here and nowhere else.
func refusal(item_id: StringName) -> Refusal:
	var piece: GearDefinition = GearDb.for_item(item_id)
	if piece == null:
		return Refusal.NOT_GEAR
	var who: StringName = _wearer()
	if who == &"" or not piece.may_wear(who):
		return Refusal.WRONG_WEARER
	var bag: Inventory = Inventory.of(get_parent())
	# A fighter with no bag (a foe) wears what it is given.
	if bag != null and not bag.has(item_id):
		return Refusal.NOT_CARRIED
	if _allowed(piece).is_empty():
		return Refusal.NO_SLOT
	return Refusal.NONE


## Puts a piece on. `into` picks the slot when the piece fits several; left empty, the first
## free slot is used, and when none is free, the first one. The piece that was there comes off.
## Returns whether anything changed.
func wear(item_id: StringName, into: StringName = &"") -> bool:
	if refusal(item_id) != Refusal.NONE:
		return false
	var piece: GearDefinition = GearDb.for_item(item_id)
	var slot: StringName = _pick(piece, into)
	if slot == &"" or slot_of(item_id) == slot:
		return false
	# A piece moved between two slots it fits comes off the old one first.
	take_off(item_id)
	var occupant: StringName = worn(slot)
	if occupant != &"":
		take_off(occupant)
	Flags.set_flag(key(item_id), String(slot))
	_apply(item_id, piece)
	Log.info(CATEGORY, "%s wears '%s' in %s" % [_wearer(), item_id, slot])
	return true


## Takes a piece off. The flag is erased, not set empty, so an empty slot leaves nothing in a
## save. Returns whether anything changed.
func take_off(item_id: StringName) -> bool:
	if slot_of(item_id) == &"":
		return false
	Flags.erase_flag(key(item_id))
	_remove(item_id)
	Log.info(CATEGORY, "%s took off '%s'" % [_wearer(), item_id])
	return true


## The slot `item_id` is worn in, or empty when it is not worn.
func slot_of(item_id: StringName) -> StringName:
	return StringName(Flags.get_string(key(item_id)))


## The item worn in `slot`, or empty.
func worn(slot: StringName) -> StringName:
	for item_id: StringName in worn_ids():
		if slot_of(item_id) == slot:
			return item_id
	return &""


## Every worn item, sorted by name so a screen and a test get a stable order.
func worn_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var scope: String = "%s%s/" % [PREFIX, _wearer()]
	for flag: StringName in Flags.with_prefix(scope):
		if Flags.get_string(flag) != "":
			out.append(StringName(String(flag).trim_prefix(scope)))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Puts the stat sheet back in step with what the flags say is worn. Runs when the set is
## built, after a load, and on a new game. A worn item whose gear file is gone gives nothing.
func refresh() -> void:
	var sheet: StatSheet = _sheet()
	if sheet == null:
		return
	for source: StringName in _applied:
		sheet.remove_from(source)
	_applied.clear()
	for item_id: StringName in worn_ids():
		var piece: GearDefinition = GearDb.for_item(item_id)
		if piece != null:
			_apply(item_id, piece)


func _on_game_loaded(_slot: int) -> void:
	refresh()


# Takes off anything that left the bag. This is the price of leaving the item in the bag, paid
# here once and not by everyone who removes an item.
func _revalidate() -> void:
	var bag: Inventory = Inventory.of(get_parent())
	if bag == null:
		return
	for item_id: StringName in worn_ids():
		if not bag.has(item_id):
			take_off(item_id)


func _apply(item_id: StringName, piece: GearDefinition) -> void:
	var sheet: StatSheet = _sheet()
	if sheet == null:
		return
	var source: StringName = _source(item_id)
	for modifier: StatModifier in piece.all_modifiers():
		if modifier != null:
			sheet.add(StatModifier.of(modifier.stat, modifier.op, modifier.value, source))
	_applied.append(source)


func _remove(item_id: StringName) -> void:
	var source: StringName = _source(item_id)
	var sheet: StatSheet = _sheet()
	if sheet != null:
		sheet.remove_from(source)
	_applied.erase(source)


# The piece's slots that this set has, in the piece's order.
func _allowed(piece: GearDefinition) -> Array[StringName]:
	var out: Array[StringName] = []
	for slot: StringName in piece.slots():
		if rules.has_slot(slot):
			out.append(slot)
	return out


func _pick(piece: GearDefinition, into: StringName) -> StringName:
	var allowed: Array[StringName] = _allowed(piece)
	if into != &"":
		return into if allowed.has(into) else &""
	for slot: StringName in allowed:
		if worn(slot) == &"":
			return slot
	return allowed[0]


func _source(item_id: StringName) -> StringName:
	return StringName(PREFIX + String(item_id))


func _wearer() -> StringName:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.combatant_id if fighter != null else &""


func _sheet() -> StatSheet:
	var fighter: Combatant = Combatant.of(get_parent())
	return fighter.sheet if fighter != null else null
