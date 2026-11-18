extends TestCase
## Review fixes, gear and the menus (C10.36a): a follower's piece, worked on from the player's
## bag, lends its gem and its level at once; awakening or taking apart a piece gives back the gem
## in the socket its level added; an awakened follower's piece is swapped in its slot; the gear
## screen redraws when the piece screen closes; the HUD's doom count follows the seconds; the
## party line reads a field member's hp with its gear counted.
##
## OWNS: assertions about the C10.36a fixes to `GearUpgrades.awaken`, `Crafting`, `GearSet`,
## `GearScreen`, `CombatHud` and `PartyScreen`.
## MUST NOT: name a game's gear, gems or fighters, or wait for frames. The gear, gem and recipe
## files go to this run's scratch directory, over the fixture items.

const HERO: StringName = &"fixture_review_hero"
const FOLLOWER: StringName = &"fixture_review_follower"
const PIECE: StringName = FixtureContent.WORN_ITEM
const AWAKENED: StringName = FixtureContent.UNIQUE_ITEM
const ORE: StringName = FixtureContent.SPARE_ITEM
const GEM: StringName = FixtureContent.STACK_ITEM

var _stack: UiRoot
var _hero: Node3D
var _follower: Node3D
var _def: CombatantDef


func run() -> void:
	plan(7)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_def = _member(FOLLOWER)
	_hero = _body(_member(HERO), true)
	_follower = _body(_def, false)
	var was: Node3D = Director.player
	Director.player = _hero
	_stack = UiRoot.new()
	attach(_stack)
	_follower_piece()
	_stack.close_all()
	_stack.free()
	Director.player = was
	_dismantling()
	_doom()
	_party_line()
	_hero.free()
	_follower.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	GemDb.content_dir = GemDb.GEM_DIR
	GemDb.rescan()
	RecipeDb.content_dir = RecipeDb.RECIPE_DIR
	RecipeDb.rescan()
	Flags.clear_all()


# The gear screen shows the follower; its weapon is worked on from the player's bag.
func _follower_piece() -> void:
	var gear_screen: GearScreen = GearScreen.for_members([_follower] as Array[Node], [_def] as Array[CombatantDef])
	_stack.open(gear_screen)
	gear_screen.slot = &"weapon"
	gear_screen.refresh()
	_row(gear_screen, _work_on(PIECE)).pressed.emit()
	var screen: PieceScreen = _stack.top() as PieceScreen
	var sheet: StatSheet = Combatant.of(_follower).sheet
	_row(screen, _put()).pressed.emit()
	var with_gem: float = sheet.value(&"strength")
	_row(screen, tr(PieceScreen.UPGRADE_KEY).format({"cost": _cost()})).pressed.emit()
	equal("a follower's piece worked on from the player's bag lends its gem and its level at once",
		[with_gem, sheet.value(&"strength")], [5.0, 105.0])
	_row(screen, _put()).pressed.emit()
	_row(screen, tr(PieceScreen.AWAKEN_KEY).format({"item": _name(AWAKENED), "cost": _cost()})).pressed.emit()
	equal("awakening gives back the gem in the socket the level added too, and forgets every socket",
		[Inventory.of(_hero).count_of(GEM), Flags.with_prefix("socket/%s/" % PIECE).size()], [3, 0])
	var gear: GearSet = GearSet.of(_follower)
	equal("awakening a follower's piece wears the new one in its slot and takes the old one off",
		[gear.worn(&"weapon"), gear.slot_of(PIECE), sheet.value(&"strength")], [AWAKENED, &"", 0.0])
	_stack.close_top()
	equal("back from the piece screen, the gear screen shows the awakened piece and not the old one",
		[_row(gear_screen, _work_on(AWAKENED)) != null, _row(gear_screen, _work_on(PIECE)) == null], [true, true])


# The player takes apart a piece raised to the level that adds a socket, both sockets filled.
func _dismantling() -> void:
	var bag: Inventory = Inventory.of(_hero)
	bag.add(PIECE)
	GearUpgrades.upgrade(bag, PIECE)
	GearSockets.socket(bag, PIECE, GEM)
	GearSockets.socket(bag, PIECE, GEM)
	var done: bool = Crafting.dismantle(bag, PIECE)
	equal("taking a piece apart gives back the gem in the socket its level added, and forgets every socket",
		[done, bag.count_of(GEM), Flags.with_prefix("socket/%s/" % PIECE).size(), GearUpgrades.level(PIECE)],
		[true, 3, 0, 0])


# A ten-second doom on the player, then two and a half seconds with no event to redraw it.
func _doom() -> void:
	var hud := CombatHud.new()
	attach(hud)
	hud.subject = _hero
	var doom := StatusEffect.new()
	doom.id = &"status/fixture_review_doom"
	doom.name_key = "fixture.doom"
	doom.unit = StatusEffect.Unit.SECONDS
	doom.duration = 10.0
	doom.fatal = true
	var statuses: StatusSet = StatusSet.of(_hero)
	statuses.apply(doom)
	hud.refresh()
	var before: bool = hud.text.contains(_doom_text(10))
	statuses.tick_seconds(2.5)
	hud._process(0.0)
	equal("the HUD's doom count follows the seconds with no event to redraw it",
		[before, hud.text.contains(_doom_text(8))], [true, true])
	statuses.cure(doom.id)
	hud.free()


# The follower wears the awakened piece, which raises its maximum hp by a quarter.
func _party_line() -> void:
	GearSet.of(_follower).wear(AWAKENED, &"weapon")
	Flags.set_flag(StringName(Vitals.PREFIX + String(FOLLOWER) + "/hp"), 45)
	var level: int = Party.level_of(FOLLOWER)
	equal("the party line reads a field member's hp and maximum, its gear counted",
		PartyScreen.member_line(_def, _follower), tr(PartyScreen.MEMBER_KEY).format({"name": tr(_def.name_key),
			"level": level, "exp": Party.experience_of(FOLLOWER), "next": _def.level_curve.exp_for(level + 1),
			"hp": 45, "max": 50}))


func _doom_text(left: int) -> String:
	return tr(CombatHud.DOOM_KEY).format({"name": tr("fixture.doom"), "left": left})


func _work_on(item_id: StringName) -> String:
	return tr(GearScreen.WORK_ON_KEY).format({"item": _name(item_id)})


func _put() -> String:
	return tr(PieceScreen.PUT_KEY).format({"gem": _name(GEM)})


func _cost() -> String:
	return PieceScreen.cost_text({ORE: 1} as Dictionary[StringName, int])


func _name(item_id: StringName) -> String:
	return tr(ItemDb.definition(item_id).name_key)


func _row(screen: MenuScreen, text: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			return button
	return null


func _member(id: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0}
	def.level_curve = LevelCurve.new()
	return def


# The player carries the bag; the follower has none, and wears the piece from the player's.
func _body(def: CombatantDef, with_bag: bool) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	if with_bag:
		body.add_child(Inventory.new())
	var fighter := Combatant.new()
	fighter.combatant_id = def.combatant_id
	fighter.base_stats = def.base_stats
	body.add_child(fighter)
	attach(body)
	GearSet.fit(body, def, true)
	if with_bag:
		Inventory.of(body).add(PIECE)
		Inventory.of(body).add(GEM, 3)
		Inventory.of(body).add(ORE, 5)
	else:
		GearSet.of(body).wear(PIECE, &"weapon")
	return body


# A coat with one socket and one level, which adds a socket and strength and awakens into a crown
# that raises the maximum hp; a gem; and a recipe that takes the coat apart.
func _write_content() -> void:
	var directory: String = RunScratch.path("review_a")
	for sub: String in ["gear", "gems", "recipes"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	var piece: GearDefinition = _piece("fixture_review_coat", PIECE)
	piece.sockets = 1
	var step := UpgradeLevel.new()
	step.items = {ORE: 1}
	step.sockets = 1
	step.modifiers = [StatModifier.of(&"strength", StatModifier.Op.ADD, 100.0, &"")]
	piece.upgrade = UpgradeTrack.new()
	piece.upgrade.levels = [step]
	piece.upgrade.awaken_into = AWAKENED
	piece.upgrade.awaken_items = {ORE: 1}
	ResourceSaver.save(piece, directory.path_join("gear/fixture_review_coat.tres"))
	var crown: GearDefinition = _piece("fixture_review_crown", AWAKENED)
	crown.modifiers = [StatModifier.of(&"max_hp", StatModifier.Op.MULTIPLY, 1.25, &"")]
	ResourceSaver.save(crown, directory.path_join("gear/fixture_review_crown.tres"))
	var gem := GemDefinition.new()
	gem.id = StringName(GemDb.ID_PREFIX + "fixture_review_gem")
	gem.item_id = GEM
	gem.modifiers = [StatModifier.of(&"strength", StatModifier.Op.ADD, 5.0, &"")]
	ResourceSaver.save(gem, directory.path_join("gems/fixture_review_gem.tres"))
	var apart := Recipe.new()
	apart.id = StringName(RecipeDb.ID_PREFIX + "fixture_review_apart")
	apart.name_key = "ui.cancel"
	apart.kind = Recipe.Kind.DISMANTLE
	apart.outputs = {ORE: 1}
	apart.piece = PIECE
	ResourceSaver.save(apart, directory.path_join("recipes/fixture_review_apart.tres"))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	GemDb.content_dir = directory.path_join("gems")
	GemDb.rescan()
	RecipeDb.content_dir = directory.path_join("recipes")
	RecipeDb.rescan()


func _piece(name: String, item_id: StringName) -> GearDefinition:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.slot = &"weapon"
	return made
