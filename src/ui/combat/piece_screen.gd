class_name PieceScreen
extends MenuScreen
## The piece screen (C10.3): work on one piece of gear, opened from the gear screen's "Work on"
## row. See `docs/GEAR.md` § Sets, sockets, upgrading.
##
## IN PLAIN WORDS:
##   - A note names the piece and its level ("Coat: level 1 of 3").
##   - One row per socket shows the gem in it. Pressing a filled one takes the gem out into the
##     bag, using up a remover when the project names one.
##   - One row per gem in the bag puts it into the first free socket.
##   - "Upgrade" pays the next level's cost, shown on the row. "Awaken" shows at a piece whose
##     track awakens into another, and the screen then shows the new piece.
##   - A row that cannot be used is greyed out with the reason.
## It works anywhere the gear screen opens. A game that wants upgrading only at a smith gives
## its pieces no track and uses an UPGRADE recipe at a `CraftStation` instead.
##
## OWNS: the rows and what pressing one does.
## MUST NOT: decide what may be socketed or upgraded (`GearSockets` and `GearUpgrades` do), or
## refer to `GearScreen` (that one opens this; a reference back would be a cycle).

const SCREEN_ID: StringName = &"gear_piece"
const TITLE_KEY: String = "combat.piece.title"
const HINT_KEY: String = "combat.piece.hint"
const LEVEL_KEY: String = "combat.piece.level"
const SOCKET_KEY: String = "combat.piece.socket"
const EMPTY_KEY: String = "combat.gear.empty"
const PUT_KEY: String = "combat.piece.put"
const UPGRADE_KEY: String = "combat.piece.upgrade"
const AWAKEN_KEY: String = "combat.piece.awaken"
const COST_KEY: String = "combat.piece.cost"
const FREE_KEY: String = "combat.piece.free"
const AFFIX_KEY: String = "combat.gear.affix"
const REFUSED_KEY: String = "combat.loadout.row_refused"
const SOCKET_REFUSAL_PREFIX: String = "combat.piece.socket_refusal."
const UPGRADE_REFUSAL_PREFIX: String = "combat.piece.upgrade_refusal."

## The piece shown, by item id. Awakening changes it to the new piece.
var piece_id: StringName = &""
## Whose bag pays and holds the gems.
var body: Node = null


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## A screen for `item_id`, paid from the bag `owner` uses.
static func for_piece(owner: Node, item_id: StringName) -> PieceScreen:
	var screen := PieceScreen.new()
	screen.body = owner
	screen.piece_id = item_id
	return screen


## The bag `owner` uses: its own, else the player's.
static func bag_of(owner: Node) -> Inventory:
	var bag: Inventory = Inventory.of(owner) if owner != null and is_instance_valid(owner) else null
	if bag == null and Director.player != null:
		bag = Inventory.of(Director.player)
	return bag


## An item's name, with the affixes its piece rolled after it ("Coat of Embers", C7.2b).
static func item_name(item_id: StringName) -> String:
	var item: ItemDefinition = ItemDb.definition(item_id)
	var shown: String = TranslationServer.translate(item.name_key) if item != null else String(item_id)
	for key: String in GearAffixes.names(item_id):
		shown = TranslationServer.translate(AFFIX_KEY).format({"item": shown,
			"affix": TranslationServer.translate(key)})
	return shown


## What a cost reads as: "Ore x2, Coin x5", or "free".
static func cost_text(cost: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in cost:
		parts.append(TranslationServer.translate(COST_KEY).format({"item": item_name(item_id),
			"count": cost[item_id]}))
	return ", ".join(parts) if not parts.is_empty() else TranslationServer.translate(FREE_KEY)


func _fill() -> void:
	var piece: GearDefinition = GearDb.for_item(piece_id)
	if piece == null:
		return
	add_note(tr(LEVEL_KEY).format({"item": item_name(piece_id), "level": GearUpgrades.level(piece_id),
		"cap": piece.upgrade_cap()}))
	var bag: Inventory = bag_of(body)
	var held: Array[StringName] = GearSockets.gems(piece_id)
	for index: int in held.size():
		var filled: bool = held[index] != &""
		var row: Button = add_row(tr(SOCKET_KEY).format({"number": index + 1,
			"gem": item_name(held[index]) if filled else tr(EMPTY_KEY)}), _on_unsocket.bind(index))
		# An empty socket is a plain line, greyed with no reason.
		row.disabled = not filled
		if filled:
			_refuse(row, SOCKET_REFUSAL_PREFIX, GearSockets.Refusal, GearSockets.removal_refusal(bag, piece_id, index))
	for gem_id: StringName in _gems_in(bag):
		var put: Button = add_row(tr(PUT_KEY).format({"gem": item_name(gem_id)}), _on_socket.bind(gem_id))
		_refuse(put, SOCKET_REFUSAL_PREFIX, GearSockets.Refusal, GearSockets.socket_refusal(bag, piece_id, gem_id))
	if piece.upgrade != null:
		_fill_track(piece, bag)


func _fill_track(piece: GearDefinition, bag: Inventory) -> void:
	var reached: int = GearUpgrades.level(piece_id)
	var next: Dictionary[StringName, int] = {}
	if reached < piece.upgrade_cap() and piece.upgrade.levels[reached] != null:
		next = piece.upgrade.levels[reached].items
	var up: Button = add_row(tr(UPGRADE_KEY).format({"cost": cost_text(next)}), _on_upgrade)
	_refuse(up, UPGRADE_REFUSAL_PREFIX, GearUpgrades.Refusal, GearUpgrades.refusal(bag, piece_id))
	if piece.upgrade.awaken_into != &"":
		var wake: Button = add_row(tr(AWAKEN_KEY).format({"item": item_name(piece.upgrade.awaken_into),
			"cost": cost_text(piece.upgrade.awaken_items)}), _on_awaken)
		_refuse(wake, UPGRADE_REFUSAL_PREFIX, GearUpgrades.Refusal, GearUpgrades.awaken_refusal(bag, piece_id))


# The gem items in the bag, by id.
static func _gems_in(bag: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: StringName in (bag.ids() if bag != null else []):
		if GemDb.for_item(item_id) != null:
			out.append(item_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


# Greys `row` out with the reason when `why` is not the enum's NONE (0 in both enums).
func _refuse(row: Button, prefix: String, reasons: Dictionary, why: int) -> void:
	if why == 0:
		return
	row.disabled = true
	row.text = tr(REFUSED_KEY).format({"label": row.text,
		"reason": tr(prefix + str(reasons.find_key(why)).to_lower())})


func _on_unsocket(index: int) -> void:
	if GearSockets.unsocket(bag_of(body), piece_id, index):
		refresh()


func _on_socket(gem_id: StringName) -> void:
	if GearSockets.socket(bag_of(body), piece_id, gem_id):
		refresh()


func _on_upgrade() -> void:
	if GearUpgrades.upgrade(bag_of(body), piece_id):
		refresh()


func _on_awaken() -> void:
	var into: StringName = GearDb.for_item(piece_id).upgrade.awaken_into
	if GearUpgrades.awaken(bag_of(body), piece_id):
		piece_id = into
		refresh()
