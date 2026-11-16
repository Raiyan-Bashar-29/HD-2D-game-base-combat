extends TestCase
## The gear screen (C7.7a): the gear key opens it for a fighter; a row per slot shows what is
## worn there in its rarity's colour; pressing a slot lists the bag's pieces that fit it with
## what each changes; pressing one wears it and pressing "take off" empties the slot; a piece
## that cannot be worn is greyed out with the reason; a cursed piece cannot be taken off.
##
## OWNS: assertions about `GearScreen` and the host's gear key.
## MUST NOT: name a game's gear, rarities or fighters, or wait for frames. The gear and rarity
## files are written to this run's scratch directory, over the fixture items.

const HERO: StringName = &"fixture_gear_screen_hero"
const BLADE: StringName = FixtureContent.STACK_ITEM
const BETTER: StringName = FixtureContent.WORN_ITEM
const BARRED: StringName = FixtureContent.SPARE_ITEM
const HEX: StringName = FixtureContent.UNIQUE_ITEM
const RARE: StringName = &"rarity/fixture_screen_rare"
const RARE_COLOUR: Color = Color(0.2, 0.4, 1.0)

var _stack: UiRoot
var _host: LoadoutHost
var _body: Node3D
var _def: CombatantDef


func run() -> void:
	plan(7)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_def = CombatantDef.new()
	_def.combatant_id = HERO
	_def.name_key = "ui.pause.title"
	_body = _wearer()
	_stack = UiRoot.new()
	attach(_stack)
	_host = LoadoutHost.new()
	_host.loadout = ActionLoadout.new()
	_host.loadout.fighter = _def
	attach(_host)
	_opening()
	_wearing()
	_stack.close_all()
	_host.free()
	_stack.free()
	_body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	RarityDb.content_dir = RarityDb.RARITY_DIR
	RarityDb.rescan()
	Flags.clear_all()


func _opening() -> void:
	var opened: bool = _host.toggle(_stack, _body, true)
	var screen: GearScreen = _stack.top() as GearScreen
	equal("the gear key opens the gear screen and stops the world",
		[opened, screen != null, screen.pauses_world if screen != null else false], [true, true, true])
	var weapon: Button = _row_starting(screen, _slot_line(&"weapon", ""))
	equal("a row per slot names the worn piece, in its rarity's colour",
		[weapon != null, weapon.get_theme_color(&"font_color") if weapon != null else Color.BLACK,
			_row_starting(screen, _slot_line(&"head", tr(GearScreen.EMPTY_KEY))) != null],
		[true, RARE_COLOUR, true])
	weapon.pressed.emit()
	var better: Button = _row_starting(screen, _item(BETTER))
	var barred: Button = _row_starting(screen, _item(BARRED))
	equal("pressing a slot lists what fits it with what it changes; a refused one is greyed with why",
		[better != null, better.text.contains(GearScreen.compare(BLADE, BETTER)), better.disabled,
			barred.disabled if barred != null else false,
			barred.text.contains(tr(GearScreen.refusal_key(GearSet.Refusal.WRONG_WEARER))) if barred != null else false],
		[true, true, false, true, true])
	equal("the comparison counts the stat by stat change, and none for the same piece",
		[GearScreen.compare(BLADE, BETTER), GearScreen.compare(BLADE, BLADE)],
		[tr(GearScreen.GAIN_KEY).format({"stat": tr("combat.stat.attack"), "amount": 3.0}),
			tr(GearScreen.SAME_KEY)])


func _wearing() -> void:
	var screen: GearScreen = _stack.top() as GearScreen
	_row_starting(screen, _item(BETTER)).pressed.emit()
	var gear: GearSet = GearSet.of(_body)
	equal("pressing a piece wears it in that slot", gear.worn(&"weapon"), BETTER)
	_row_starting(screen, tr(GearScreen.TAKE_OFF_KEY).format({"item": _item(BETTER)})).pressed.emit()
	equal("take off empties the slot", gear.worn(&"weapon"), &"")
	gear.wear(HEX, &"weapon")
	screen.slot = &"weapon"
	screen.refresh()
	var off: Button = _row_starting(screen, tr(GearScreen.TAKE_OFF_KEY).format({"item": _item(HEX)}))
	equal("a cursed piece's take-off row is greyed out, and a second press of the key closes",
		[off != null and off.disabled, _host.toggle(_stack, _body, true), _stack.depth()], [true, true, 0])


func _slot_line(slot: StringName, item: String) -> String:
	var shown: String = tr("combat.gear.slot." + String(slot))
	return tr(GearScreen.SLOT_ROW_KEY).format({"slot": shown, "item": item})


func _item(item_id: StringName) -> String:
	return tr(ItemDb.definition(item_id).name_key)


func _row_starting(screen: GearScreen, text: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			return button
	return null


func _write_content() -> void:
	var directory: String = RunScratch.path("gear_screen")
	DirAccess.make_dir_recursive_absolute(directory)
	var rare := Rarity.new()
	rare.id = RARE
	rare.name_key = "ui.cancel"
	rare.color = RARE_COLOUR
	ResourceSaver.save(rare, directory.path_join("fixture_screen_rare.tres"))
	RarityDb.content_dir = directory
	RarityDb.rescan()
	_save(directory, "fixture_screen_blade", BLADE, 4.0, RARE)
	_save(directory, "fixture_screen_better", BETTER, 7.0, &"")
	var barred := _piece("fixture_screen_barred", BARRED, 9.0, &"")
	barred.wearers = [&"fixture_someone_else"]
	ResourceSaver.save(barred, directory.path_join("fixture_screen_barred.tres"))
	var hex := _piece("fixture_screen_hex", HEX, 1.0, &"")
	hex.cursed = true
	ResourceSaver.save(hex, directory.path_join("fixture_screen_hex.tres"))
	GearDb.content_dir = directory
	GearDb.rescan()


func _save(directory: String, name: String, item_id: StringName, attack: float, tier: StringName) -> void:
	ResourceSaver.save(_piece(name, item_id, attack, tier), directory.path_join(name + ".tres"))


func _piece(name: String, item_id: StringName, attack: float, tier: StringName) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.slot = &"weapon"
	made.rarity = tier
	made.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, attack, &"")]
	return made


func _wearer() -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"attack": 2.0}
	body.add_child(fighter)
	attach(body)
	for item_id: StringName in [BLADE, BETTER, BARRED, HEX]:
		bag.add(item_id)
	GearSet.fit(body, _def, true)
	GearSet.of(body).wear(BLADE, &"weapon")
	return body
