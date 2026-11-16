class_name WeaponLine
extends RefCounted
## The weapon a fighter wears and its mode, as one piece of text (C7.7b), for the field HUD and
## the battle screen.
##
## IN PLAIN WORDS: the weapon is the piece worn in the first slot of the slot list (the weapon,
## by convention). Its mode is the form its own kit holds now (IXA's lance or shield,
## `docs/GEAR.md` § IXA), so "IXA (Shield)"; a weapon with no form held shows its name alone,
## and a fighter with no weapon shows nothing.
##
## OWNS: choosing which piece is the weapon and which form is its mode, and the text.
## MUST NOT: change what is worn or held.

const KEY: String = "ui.combat_hud.weapon"
const MODE_KEY: String = "ui.combat_hud.weapon_mode"


## "IXA (Shield)", "IXA", or "" for a fighter with no weapon.
static func text(body: Node) -> String:
	var gear: GearSet = GearSet.of(body)
	var rules: GearRules = GearSet.configured_rules()
	if gear == null or rules.slots.is_empty():
		return ""
	var item_id: StringName = gear.worn(rules.slots[0])
	if item_id == &"":
		return ""
	var item: ItemDefinition = ItemDb.definition(item_id)
	var shown: String = TranslationServer.translate(item.name_key) if item != null else String(item_id)
	var mode: String = mode_key(body, GearDb.for_item(item_id))
	if mode == "":
		return TranslationServer.translate(KEY).format({"weapon": shown})
	return TranslationServer.translate(MODE_KEY).format({"weapon": shown,
		"mode": TranslationServer.translate(mode)})


## The name key of the form of `piece`'s own kit held on `body` now, or "".
static func mode_key(body: Node, piece: GearDefinition) -> String:
	if piece == null or piece.kit == null:
		return ""
	for run: FormRun in FormRun.held_in(body):
		if piece.kit.powers.has(run.power):
			var key: String = (run.mechanism as FormMechanism).name_at(run.stage)
			if key != "":
				return key
	return ""
