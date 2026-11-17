extends TestCase
## The passive loadout screen (C9.7): the loadout key opens it for a fighter and nobody else;
## it shows the member's budget, what is chosen, what is learned, what the worn gear is
## teaching and what is held from elsewhere; pressing a learned row chooses it and a chosen
## row takes it out; a row that cannot be chosen is greyed out with the reason; the bottom
## line describes the row under the cursor; and a second member can be stepped to.
##
## OWNS: assertions about `LoadoutScreen` and `LoadoutHost`.
## MUST NOT: name a game's passives, gear or fighters, or wait for frames. The gear and passive
## files are written to this run's scratch directory, over the fixture items.

const COAT: StringName = FixtureContent.WORN_ITEM
const HERO: StringName = &"fixture_screen_hero"
const FRIEND: StringName = &"fixture_screen_friend"
const SMALL: StringName = &"passive/fixture_screen_small"
const LARGE: StringName = &"passive/fixture_screen_large"
const TWIN: StringName = &"passive/fixture_screen_twin"
const LENT: StringName = &"passive/fixture_screen_lent"
const NAMES: Dictionary[StringName, String] = {
	SMALL: "ui.pause.resume", LARGE: "ui.pause.save", TWIN: "ui.menu.load", LENT: "ui.menu.quit",
}
const DESC_KEY: String = "ui.pause.hint"

var _stack: UiRoot
var _host: LoadoutHost
var _body: Node3D
var _def: CombatantDef


func run() -> void:
	plan(12)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_def = _definition(HERO)
	_body = _wearer(HERO, _def)
	_stack = UiRoot.new()
	attach(_stack)
	_host = LoadoutHost.new()
	_host.loadout = ActionLoadout.new()
	_host.loadout.fighter = _def
	attach(_host)
	_opening()
	_choosing()
	_showing()
	_members()
	_stack.close_all()
	_host.free()
	_stack.free()
	_body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	PassiveDb.content_dir = PassiveDb.PASSIVE_DIR
	PassiveDb.rescan()
	Flags.clear_all()


func _opening() -> void:
	var bystander := Node3D.new()
	attach(bystander)
	equal("the host will not open for someone who is not a fighter",
		[_host.toggle(_stack, bystander), _stack.depth()], [false, 0])
	bystander.free()
	var opened: bool = _host.toggle(_stack, _body)
	var top: UiScreen = _stack.top()
	equal("the loadout key opens the screen and stops the world",
		[opened, top.screen_id if top != null else &"", top.pauses_world if top != null else false],
		[true, LoadoutScreen.SCREEN_ID, true])
	var screen: LoadoutScreen = top as LoadoutScreen
	var texts: Array[String] = screen.row_texts()
	equal("the first line is the member and the budget; nothing is chosen or learned yet",
		[texts[0], texts.has(tr(LoadoutScreen.NONE_CHOSEN_KEY)), texts.has(tr(LoadoutScreen.NONE_LEARNED_KEY))],
		[_budget_line(_def, 0), true, true])
	equal("what the worn piece teaches is listed with the fights won so far",
		[texts.has(_lesson_line(SMALL, 0, 1)), texts.has(_lesson_line(LARGE, 0, 2))], [true, true])


func _choosing() -> void:
	var screen: LoadoutScreen = _stack.top() as LoadoutScreen
	PassiveLoadout.practise(HERO)
	PassiveLoadout.teach(HERO, LARGE)
	PassiveLoadout.teach(HERO, TWIN)
	screen.refresh()
	equal("a learned passive is a row with its cost, and its lesson leaves the list",
		[_row(screen, SMALL) != null, _row(screen, SMALL).disabled, screen.row_texts().has(_lesson_line(SMALL, 1, 1))],
		[true, false, false])
	_row(screen, SMALL).pressed.emit()
	equal("pressing it chooses it, and the budget line moves",
		[PassiveLoadout.chosen(HERO), screen.row_texts()[0]], [[SMALL], _budget_line(_def, 2)])
	var large: Button = _row(screen, LARGE)
	var twin: Button = _row(screen, TWIN)
	equal("one over the budget is greyed out with the reason, and one of a kind already held too",
		[large.disabled, large.text.contains(tr(PassiveLoadout.OVER_BUDGET_KEY)),
			twin.disabled, twin.text.contains(tr(PassiveLoadout.SAME_GROUP_KEY))],
		[true, true, true, true])
	_row(screen, SMALL).pressed.emit()
	equal("pressing a chosen row takes it out, and the others can be chosen again",
		[PassiveLoadout.chosen(HERO).size(), _row(screen, LARGE).disabled, _row(screen, TWIN).disabled],
		[0, false, false])


func _showing() -> void:
	var screen: LoadoutScreen = _stack.top() as LoadoutScreen
	_row(screen, LARGE).focus_entered.emit()
	equal("the bottom line describes the row under the cursor", screen.detail.text, tr(DESC_KEY))
	PassiveLending.give(_body, &"fixture_source", [PassiveDb.passive(LENT)])
	screen.refresh()
	var texts: Array[String] = screen.row_texts()
	equal("a passive held from elsewhere is listed under its own heading, not as a row",
		[texts.has(tr(LoadoutScreen.GIVEN_KEY)), texts.has(tr(NAMES[LENT])), _row(screen, LENT)],
		[true, true, null])
	equal("a second press of the loadout key closes the screen",
		[_host.toggle(_stack, _body), _stack.depth()], [true, 0])


func _members() -> void:
	var other := UiScreen.new()
	other.screen_id = &"fixture_other"
	_stack.open(other)
	var refused: bool = _host.toggle(_stack, _body)
	_stack.close_all()
	var friend_def: CombatantDef = _definition(FRIEND)
	var friend: Node3D = _wearer(FRIEND, friend_def)
	var screen: LoadoutScreen = LoadoutScreen.for_members([_body, friend], [_def, friend_def])
	_stack.open(screen)
	var before: String = screen.row_texts()[0]
	_row_named(screen, tr(LoadoutScreen.NEXT_KEY)).pressed.emit()
	equal("the host will not open over another screen; with two members a row steps to the next",
		[refused, before, screen.row_texts()[0]], [false, _budget_line(_def, 0), _budget_line(friend_def, 0)])
	_stack.close_all()
	friend.free()


func _budget_line(def: CombatantDef, spent: int) -> String:
	return tr(LoadoutScreen.BUDGET_KEY).format({"name": tr(def.name_key), "spent": spent,
		"budget": def.passive_budget})


func _lesson_line(passive_id: StringName, count: int, fights: int) -> String:
	return tr(LoadoutScreen.LESSON_KEY).format({"name": tr(NAMES[passive_id]), "count": count,
		"fights": fights})


## The row of `passive_id`, or null.
func _row(screen: LoadoutScreen, passive_id: StringName) -> Button:
	var passive: PassiveSkill = PassiveDb.passive(passive_id)
	return _row_named(screen, tr(LoadoutScreen.ROW_KEY).format({"name": tr(NAMES[passive_id]),
		"cost": passive.cost}))


## The first row whose text starts with `text`, or null.
func _row_named(screen: LoadoutScreen, text: String) -> Button:
	for child: Node in screen.rows.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion() and button.text.begins_with(text):
			return button
	return null


func _definition(id: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.pause.title" if id == HERO else "ui.pause.main_menu"
	def.passive_budget = 3
	return def


func _wearer(id: StringName, def: CombatantDef) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	body.add_child(bag)
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.base_stats = {&"max_hp": 40.0, &"attack": 2.0}
	body.add_child(fighter)
	attach(body)
	if id == HERO:
		bag.add(COAT)
	GearSet.fit(body, def, true)
	if id == HERO:
		GearSet.of(body).wear(COAT)
	return body


func _passive(id: StringName, cost: int, group: StringName) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = id
	made.name_key = NAMES[id]
	made.desc_key = DESC_KEY
	made.cost = cost
	made.group = group
	made.held = StatusEffect.new()
	made.held.id = StringName(StatusDb.ID_PREFIX + String(id).get_file())
	return made


func _lesson(passive_id: StringName, fights: int) -> PassiveLesson:
	var made := PassiveLesson.new()
	made.passive = PassiveDb.passive(passive_id)
	made.fights = fights
	return made


func _write_content() -> void:
	var directory: String = RunScratch.path("loadout_screen")
	for sub: String in ["gear", "passives"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	for made: PassiveSkill in [_passive(SMALL, 2, &"fixture_group"), _passive(LARGE, 3, &""),
			_passive(TWIN, 1, &"fixture_group"), _passive(LENT, 0, &"")]:
		ResourceSaver.save(made, directory.path_join("passives/%s.tres" % String(made.id).get_file()))
	PassiveDb.content_dir = directory.path_join("passives")
	PassiveDb.rescan()
	var kind := GearType.new()
	kind.type_id = &"gear_type/fixture_screen_coat"
	kind.name_key = "ui.cancel"
	kind.slots = [&"body"]
	var coat := GearDefinition.new()
	coat.id = StringName(GearDb.ID_PREFIX + "fixture_screen_coat")
	coat.item_id = COAT
	coat.type = kind
	ResourceSaver.save(coat, directory.path_join("gear/fixture_screen_coat.tres"))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	# The lessons go on the loaded piece, naming the very passives the catalogue holds.
	GearDb.for_item(COAT).teaches = [_lesson(SMALL, 1), _lesson(LARGE, 2)]
