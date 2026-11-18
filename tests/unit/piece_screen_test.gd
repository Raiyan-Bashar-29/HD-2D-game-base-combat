extends TestCase
## The piece screen (C10.3): the gear screen's "Work on" row opens the worn piece; a gem from
## the bag goes into a socket and its stat change reaches the wearer; taking it out needs a
## remover when one is named and gives the gem back; the upgrade row pays and raises the level;
## at the cap the awaken row turns the piece into the next one. A refused row is greyed with why.
##
## OWNS: assertions about `PieceScreen` and the gear screen's "Work on" row.
## MUST NOT: name a game's gear, gems or fighters, or wait for frames. The gear and gem files
## are written to this run's scratch directory, over the fixture items.

const HERO: StringName = &"fixture_piece_hero"
const PIECE: StringName = FixtureContent.WORN_ITEM
const AWAKENED: StringName = FixtureContent.UNIQUE_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEM: StringName = FixtureContent.STACK_ITEM
const REMOVER: StringName = FixtureContent.HELD_ITEM

var _stack: UiRoot
var _body: Node3D
var _def: CombatantDef


func run() -> void:
	plan(8)
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
	var screen: PieceScreen = _opening()
	_sockets(screen)
	_upgrades(screen)
	_stack.close_all()
	_stack.free()
	_body.free()
	ProjectSettings.set_setting(GearSockets.REMOVER_SETTING, "")
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	Flags.clear_all()


func _opening() -> PieceScreen:
	var gear_screen: GearScreen = GearScreen.for_members([_body] as Array[Node], [_def] as Array[CombatantDef])
	_stack.open(gear_screen)
	gear_screen.slot = &"weapon"
	gear_screen.refresh()
	_row(gear_screen, tr(GearScreen.WORK_ON_KEY).format({"item": _name(PIECE)})).pressed.emit()
	var screen: PieceScreen = _stack.top() as PieceScreen
	equal("the gear screen's work-on row opens the worn piece, at level 0 of 3 with two empty sockets",
		[screen != null and screen.piece_id == PIECE, _shows(screen, _level(0)),
			_row(screen, _socket(1, tr(PieceScreen.EMPTY_KEY))) != null,
			_row(screen, _socket(2, tr(PieceScreen.EMPTY_KEY))) != null], [true, true, true, true])
	return screen


func _sockets(screen: PieceScreen) -> void:
	var bag: Inventory = Inventory.of(_body)
	_row(screen, _put()).pressed.emit()
	equal("putting a gem in uses it from the bag and its stat change reaches the wearer",
		[GearSockets.gems(PIECE), bag.count_of(GEM), Combatant.of(_body).sheet.value(&"strength")],
		[[GEM, &""] as Array[StringName], 2, 5.0])
	_row(screen, _put()).pressed.emit()
	var put: Button = _row(screen, _put())
	equal("with both sockets full the put row is greyed with why",
		[put.disabled, put.text.contains(tr("combat.piece.socket_refusal.no_free_socket"))], [true, true])
	ProjectSettings.set_setting(GearSockets.REMOVER_SETTING, String(REMOVER))
	screen.refresh()
	var first: Button = _row(screen, _socket(1, _name(GEM)))
	equal("taking a gem out needs a remover once one is named",
		[first.disabled, first.text.contains(tr("combat.piece.socket_refusal.no_remover"))], [true, true])
	bag.add(REMOVER)
	screen.refresh()
	_row(screen, _socket(1, _name(GEM))).pressed.emit()
	equal("with one, the gem comes back out and the remover is used up",
		[GearSockets.gems(PIECE), bag.count_of(GEM), bag.count_of(REMOVER)],
		[[&"", GEM] as Array[StringName], 2, 0])


func _upgrades(screen: PieceScreen) -> void:
	var bag: Inventory = Inventory.of(_body)
	var cost: String = PieceScreen.cost_text({ORE: 1} as Dictionary[StringName, int])
	var up: Button = _row(screen, tr(PieceScreen.UPGRADE_KEY).format({"cost": cost}))
	equal("the upgrade row shows the cost and is greyed while the bag cannot pay",
		[up != null, up.disabled if up != null else false,
			up.text.contains(tr("combat.piece.upgrade_refusal.cost")) if up != null else false], [true, true, true])
	bag.add(ORE, 4)
	screen.refresh()
	for i: int in 3:
		_row(screen, tr(PieceScreen.UPGRADE_KEY).format({"cost": cost})).pressed.emit()
	var capped: Button = _row(screen, tr(PieceScreen.UPGRADE_KEY).format({"cost": tr(PieceScreen.FREE_KEY)}))
	equal("three presses pay three levels; at the cap the row is greyed",
		[GearUpgrades.level(PIECE), bag.count_of(ORE), _shows(screen, _level(3)), capped.disabled], [3, 1, true, true])
	_row(screen, tr(PieceScreen.AWAKEN_KEY).format({"item": _name(AWAKENED), "cost": cost})).pressed.emit()
	equal("the awaken row turns the piece into the next one, and the screen shows it",
		[bag.has(PIECE), bag.has(AWAKENED), bag.count_of(ORE), screen.piece_id], [false, true, 0, AWAKENED])


func _level(reached: int) -> String:
	return tr(PieceScreen.LEVEL_KEY).format({"item": _name(PIECE), "level": reached, "cap": 3})


func _socket(number: int, gem: String) -> String:
	return tr(PieceScreen.SOCKET_KEY).format({"number": number, "gem": gem})


func _put() -> String:
	return tr(PieceScreen.PUT_KEY).format({"gem": _name(GEM)})


func _name(item_id: StringName) -> String:
	return tr(ItemDb.definition(item_id).name_key)


func _row(screen: MenuScreen, text: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			return button
	return null


func _shows(screen: MenuScreen, text: String) -> bool:
	for line: String in screen.row_texts():
		if line.begins_with(text):
			return true
	return false


func _write_content() -> void:
	var directory: String = RunScratch.path("piece_screen")
	for sub: String in ["gear", "gems"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var piece: GearDefinition = _piece("fixture_piece_coat", PIECE)
	piece.sockets = 2
	piece.upgrade = UpgradeTrack.new()
	piece.upgrade.levels = [_step(), _step(), _step()]
	piece.upgrade.awaken_into = AWAKENED
	piece.upgrade.awaken_items = {ORE: 1}
	ResourceSaver.save(piece, directory.path_join("gear/fixture_piece_coat.tres"))
	ResourceSaver.save(_piece("fixture_piece_crown", AWAKENED), directory.path_join("gear/fixture_piece_crown.tres"))
	var gem := GemDefinition.new()
	gem.id = StringName(GemDb.ID_PREFIX + "fixture_piece_gem")
	gem.item_id = GEM
	gem.modifiers = [StatModifier.of(&"strength", StatModifier.Op.ADD, 5.0, &"")]
	ResourceSaver.save(gem, directory.path_join("gems/fixture_piece_gem.tres"))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	GemDb.content_dir = directory.path_join("gems")
	GemDb.rescan()


func _step() -> UpgradeLevel:
	var made := UpgradeLevel.new()
	made.items = {ORE: 1}
	made.stat_bonus = 0.5
	return made


func _piece(name: String, item_id: StringName) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.slot = &"weapon"
	return made


func _wearer() -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0}
	body.add_child(fighter)
	attach(body)
	bag.add(PIECE)
	bag.add(GEM, 3)
	GearSet.fit(body, _def, true)
	GearSet.of(body).wear(PIECE, &"weapon")
	return body
