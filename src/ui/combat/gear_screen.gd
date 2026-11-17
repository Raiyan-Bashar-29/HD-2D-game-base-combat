class_name GearScreen
extends MenuScreen
## The gear screen (C7.7a): see and change what each party member wears. See `docs/GEAR.md`.
##
## IN PLAIN WORDS: one member at a time, like the passive loadout screen.
##   - One row per slot: the slot's name and the piece worn there, in its rarity's colour.
##   - Press a slot to list, under it, the pieces in the bag that fit it. Each shows what it
##     changes against the worn one ("attack +3, speed -1"). Press one to wear it. One that
##     cannot be worn is greyed out with the reason (`GearSet.refusal`).
##   - "Take off" empties the slot; it is greyed out for a cursed piece.
## A slot or stat with no row in the CSV shows its id, so a game's own stats still read.
##
## OWNS: the rows and what pressing one does.
## MUST NOT: decide who may wear what (`GearSet` does) or keep its own list of what is worn.

const SCREEN_ID: StringName = &"gear"
const TITLE_KEY: String = "combat.gear.title"
const HINT_KEY: String = "combat.gear.hint"
const MEMBER_KEY: String = "combat.gear.member"
const NEXT_KEY: String = "combat.loadout.next_member"
const SLOT_ROW_KEY: String = "combat.gear.slot_row"
const EMPTY_KEY: String = "combat.gear.empty"
const TAKE_OFF_KEY: String = "combat.gear.take_off"
const CHOICES_KEY: String = "combat.gear.choices"
const NONE_FITS_KEY: String = "combat.gear.none_fits"
const PIECE_KEY: String = "combat.gear.piece"
const REFUSED_KEY: String = "combat.loadout.row_refused"
const SAME_KEY: String = "combat.gear.same"
const GAIN_KEY: String = "combat.gear.gain"
const LOSS_KEY: String = "combat.gear.loss"
const AFFIX_KEY: String = "combat.gear.affix"
const SLOT_PREFIX: String = "combat.gear.slot."
const STAT_PREFIX: String = "combat.stat."
const REFUSAL_PREFIX: String = "combat.gear.refusal."

## The members' bodies and, at the same index, their definitions.
var bodies: Array[Node] = []
var defs: Array[CombatantDef] = []
## Which member is shown.
var index: int = 0
## The slot whose choices are listed; empty for none.
var slot: StringName = &""


func _init() -> void:
	screen_id = SCREEN_ID
	pauses_world = true
	closes_on_cancel = true
	title_key = TITLE_KEY
	hint_key = HINT_KEY
	opaque = false


## A screen for these members. `member_defs[i]` is the definition of `member_bodies[i]`.
static func for_members(member_bodies: Array[Node], member_defs: Array[CombatantDef]) -> GearScreen:
	var screen := GearScreen.new()
	screen.bodies = member_bodies
	screen.defs = member_defs
	return screen


## The pieces in the bag `body` uses (its own, else the player's) that fit `into`, by id.
static func candidates(body: Node, into: StringName) -> Array[StringName]:
	var bag: Inventory = Inventory.of(body)
	if bag == null and Director.player != null:
		bag = Inventory.of(Director.player)
	var out: Array[StringName] = []
	for item_id: StringName in (bag.ids() if bag != null else []):
		var piece: GearDefinition = GearDb.for_item(item_id)
		if piece != null and piece.slots().has(into):
			out.append(item_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## What swapping `from` (empty for nothing) for `to` changes, stat by stat: "attack +3, speed
## -1". Added amounts only; a multiplier is not compared.
static func compare(from: StringName, to: StringName) -> String:
	var diff: Dictionary[StringName, float] = {}
	_sum(diff, to, 1.0)
	_sum(diff, from, -1.0)
	var stats: Array[StringName] = diff.keys()
	stats.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for stat: StringName in stats:
		var amount: float = snappedf(diff[stat], 0.01)
		if is_zero_approx(amount):
			continue
		parts.append(TranslationServer.translate(GAIN_KEY if amount > 0.0 else LOSS_KEY).format(
			{"stat": _named(STAT_PREFIX, stat), "amount": absf(amount)}))
	return ", ".join(parts) if not parts.is_empty() else TranslationServer.translate(SAME_KEY)


## The key that says why a piece cannot be worn.
static func refusal_key(why: GearSet.Refusal) -> String:
	return REFUSAL_PREFIX + str(GearSet.Refusal.find_key(why)).to_lower()


func _fill() -> void:
	if index >= bodies.size() or index >= defs.size() or not is_instance_valid(bodies[index]):
		return
	var gear: GearSet = GearSet.of(bodies[index])
	add_note(tr(MEMBER_KEY).format({"name": tr(defs[index].name_key)}))
	if bodies.size() > 1:
		add_row(tr(NEXT_KEY), _on_next)
	for each: StringName in GearSet.configured_rules().slots:
		var worn: StringName = gear.worn(each) if gear != null else &""
		var row: Button = add_row(tr(SLOT_ROW_KEY).format({"slot": _named(SLOT_PREFIX, each),
			"item": _item_name(worn) if worn != &"" else tr(EMPTY_KEY)}), _on_slot.bind(each))
		_tint(row, worn)
	if slot != &"" and gear != null:
		_fill_choices(gear)


func _fill_choices(gear: GearSet) -> void:
	add_note(tr(CHOICES_KEY).format({"slot": _named(SLOT_PREFIX, slot)}))
	var worn: StringName = gear.worn(slot)
	if worn != &"":
		var off: Button = add_row(tr(TAKE_OFF_KEY).format({"item": _item_name(worn)}),
			_on_take_off.bind(worn))
		var piece: GearDefinition = GearDb.for_item(worn)
		off.disabled = piece != null and piece.cursed
	var shown: int = 0
	for item_id: StringName in candidates(bodies[index], slot):
		if item_id == worn:
			continue
		shown += 1
		var row: Button = add_row(tr(PIECE_KEY).format({"item": _item_name(item_id),
			"compare": compare(worn, item_id)}), _on_wear.bind(item_id))
		_tint(row, item_id)
		var why: GearSet.Refusal = gear.refusal(item_id, slot)
		if why != GearSet.Refusal.NONE:
			row.disabled = true
			row.text = tr(REFUSED_KEY).format({"label": row.text, "reason": tr(refusal_key(why))})
	if shown == 0:
		add_note(tr(NONE_FITS_KEY))


static func _sum(diff: Dictionary[StringName, float], item_id: StringName, sign_of: float) -> void:
	var piece: GearDefinition = GearDb.for_item(item_id) if item_id != &"" else null
	var all: Array[StatModifier] = []
	if piece != null:
		all.append_array(piece.all_modifiers())
	# What the piece rolled when it dropped counts too (C7.2b).
	all.append_array(GearAffixes.of(item_id))
	for modifier: StatModifier in all:
		if modifier.op == StatModifier.Op.ADD:
			diff[modifier.stat] = diff.get(modifier.stat, 0.0) + modifier.value * sign_of


# A slot or stat by its CSV row, else its id.
static func _named(prefix: String, id: StringName) -> String:
	var key: String = prefix + String(id)
	var shown: String = TranslationServer.translate(key)
	return String(id) if shown == key else shown


func _item_name(item_id: StringName) -> String:
	var item: ItemDefinition = ItemDb.definition(item_id)
	var shown: String = tr(item.name_key) if item != null else String(item_id)
	# A piece's rolled affixes follow its name, such as "Coat of Embers" (C7.2b).
	for key: String in GearAffixes.names(item_id):
		shown = tr(AFFIX_KEY).format({"item": shown, "affix": tr(key)})
	return shown


# A row in its piece's rarity colour.
func _tint(row: Button, item_id: StringName) -> void:
	var piece: GearDefinition = GearDb.for_item(item_id) if item_id != &"" else null
	var tier: Rarity = RarityDb.of(piece.rarity) if piece != null else null
	if tier != null:
		row.add_theme_color_override(&"font_color", tier.color)


func _on_slot(chosen: StringName) -> void:
	slot = &"" if slot == chosen else chosen
	refresh()


func _on_wear(item_id: StringName) -> void:
	var gear: GearSet = GearSet.of(bodies[index])
	if gear != null and gear.wear(item_id, slot):
		refresh()


func _on_take_off(item_id: StringName) -> void:
	var gear: GearSet = GearSet.of(bodies[index])
	if gear != null and gear.take_off(item_id):
		refresh()


func _on_next() -> void:
	index = (index + 1) % bodies.size()
	slot = &""
	refresh()
