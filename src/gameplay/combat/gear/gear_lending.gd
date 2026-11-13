class_name GearLending
extends RefCounted
## Writes what a fighter's worn pieces lend onto the fighter (C7.1c, C7.3, C7.3b; moved out of
## `GearSet` in C7.4a to keep that file in its budget).
##
## IN PLAIN WORDS: after every change to what is worn, `GearSet` calls `lend`. It reads the worn
## pieces in the slot list's order, so the weapon speaks first, and writes onto the wearer:
##   - `Combatant.lent_element`: the first piece with an element decides the plain attack's element.
##   - `Combatant.lent_tags`: every piece's weakness tags, each once.
##   - `Combatant.lent_moves`: the first piece with moves gives the field chain.
##   - the wearer's `PowerSet`: every piece's `kit`, held under `gear_kit/<item id>`. A fighter
##     with no powers of its own gets a `PowerSet` the first time a piece lends it a kit.
##
## OWNS: turning the worn pieces into what the wearer borrows.
## MUST NOT: decide what is worn, or touch the stat sheet. `GearSet` does both.

## Brings what `gear`'s wearer borrows in step with what `gear` has on.
static func lend(gear: GearSet) -> void:
	var body: Node = gear.get_parent()
	var fighter: Combatant = Combatant.of(body)
	if fighter == null:
		return
	fighter.lent_element = &""
	fighter.lent_tags.clear()
	fighter.lent_moves = null
	var kits: Dictionary[StringName, PowerKit] = {}
	for slot: StringName in gear.rules.slots:
		var piece: GearDefinition = GearDb.for_item(gear.worn(slot))
		if piece == null:
			continue
		if piece.kit != null:
			kits[StringName(GearSet.KIT_PREFIX + String(piece.item_id))] = piece.kit
		if fighter.lent_element == &"":
			fighter.lent_element = piece.strike_element()
		if fighter.lent_moves == null:
			fighter.lent_moves = piece.strike_moves()
		for tag: StringName in piece.all_attack_tags():
			if not fighter.lent_tags.has(tag):
				fighter.lent_tags.append(tag)
	var powers: PowerSet = PowerSet.of(body)
	if powers == null and not kits.is_empty():
		powers = PowerSet.new()
		body.add_child(powers)
	if powers != null:
		powers.lend(kits)
