extends TestCase
## The passive loadout (C9.4): a worn piece teaches passives through won fights, the player
## chooses learned ones within a skill-cost budget, and the choice is held under `loadout`.
##
## OWNS: assertions about `PassiveLoadout`, `PassiveLesson`, `GearDefinition.teaches`,
## `CombatantDef.passive_budget` and `Rewards.learned`.
## MUST NOT: name a game's passives, gear or fighters, or wait for frames. The gear and passive
## files are written to this run's scratch directory, over the fixture items.

const COAT: StringName = FixtureContent.WORN_ITEM
const HERO: StringName = &"fixture_loadout_hero"
const SMALL: StringName = &"passive/fixture_loadout_small"
const LARGE: StringName = &"passive/fixture_loadout_large"
const TWIN: StringName = &"passive/fixture_loadout_twin"

var _body: Node3D
var _def: CombatantDef


func run() -> void:
	plan(15)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_def = CombatantDef.new()
	_def.combatant_id = HERO
	_def.passive_budget = 3
	_def.passive_budget_per_level = 2
	_body = _wearer()
	_shapes()
	_lessons()
	_choices()
	_kept()
	_body.free()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	PassiveDb.content_dir = PassiveDb.PASSIVE_DIR
	PassiveDb.rescan()
	Flags.clear_all()


func _shapes() -> void:
	var bad := PassiveLesson.new()
	bad.fights = -1
	equal("a lesson with no passive and fewer than zero fights has two problems",
		bad.problems("here").size(), 2)
	equal("a piece that teaches is sound", GearDb.for_item(COAT).problems().size(), 0)
	_def.passive_budget = -1
	var before: int = _def.problems("here").size()
	_def.passive_budget = 3
	equal("a budget below zero is a problem", before - _def.problems("here").size(), 1)


func _lessons() -> void:
	var none: Rewards = Rewards.give(0, [], [_def], null)
	equal("a win with the piece off teaches nothing and counts nothing",
		[none.learned.size(), PassiveLoadout.progress(HERO, COAT, SMALL)], [0, 0])
	GearSet.of(_body).wear(COAT)
	var first: Rewards = Rewards.give(0, [], [_def], null)
	equal("the first win with it on teaches the one-fight lesson and counts towards the other",
		[first.learned, PassiveLoadout.progress(HERO, COAT, LARGE)], [{HERO: [SMALL]}, 1])
	var second: Array[StringName] = PassiveLoadout.practise(HERO)
	var third: Array[StringName] = PassiveLoadout.practise(HERO)
	equal("the second win teaches the two-fight lesson, and a third teaches nothing more",
		[second, third, PassiveLoadout.progress(HERO, COAT, LARGE)], [[LARGE], [], 2])
	GearSet.of(_body).take_off(COAT)
	equal("what was learned stays learned with the piece off",
		PassiveLoadout.known(HERO), [LARGE, SMALL])


func _choices() -> void:
	equal("a passive not learned, and one that does not exist, are refused",
		[PassiveLoadout.refusal(_body, _def, TWIN), PassiveLoadout.refusal(_body, _def, &"passive/none")],
		[PassiveLoadout.Refusal.NOT_LEARNED, PassiveLoadout.Refusal.NO_SUCH_PASSIVE])
	var took: bool = PassiveLoadout.choose(_body, _def, SMALL)
	equal("a learned passive within the budget is chosen, held under the loadout, and its status is on",
		[took, _sources(), _stacks(SMALL), PassiveLoadout.spent(HERO)], [true, [PassiveLoadout.SOURCE], 1, 2])
	equal("one over the budget is refused, and one already chosen too",
		[PassiveLoadout.refusal(_body, _def, LARGE), PassiveLoadout.refusal(_body, _def, SMALL)],
		[PassiveLoadout.Refusal.OVER_BUDGET, PassiveLoadout.Refusal.ALREADY_CHOSEN])
	Flags.set_flag(StringName(Party.LEVEL_PREFIX + String(HERO)), 2)
	equal("a party level adds to the budget, and then it fits",
		[PassiveLoadout.budget(_def), PassiveLoadout.choose(_body, _def, LARGE), PassiveLoadout.chosen(HERO)],
		[5, true, [LARGE, SMALL]])
	PassiveLoadout.teach(HERO, TWIN)
	var same: PassiveLoadout.Refusal = PassiveLoadout.refusal(_body, _def, TWIN)
	var dropped: bool = PassiveLoadout.drop(_body, SMALL)
	equal("a passive of a group already held is refused; with the other dropped it is not, and "
			+ "the dropped one's status is off",
		[same, dropped, PassiveLoadout.refusal(_body, _def, TWIN), _stacks(SMALL), PassiveLoadout.spent(HERO)],
		[PassiveLoadout.Refusal.SAME_GROUP, true, PassiveLoadout.Refusal.NONE, 0, 3])
	var keys: Array[String] = []
	for why: PassiveLoadout.Refusal in [PassiveLoadout.Refusal.NONE, PassiveLoadout.Refusal.NOT_LEARNED,
			PassiveLoadout.Refusal.ALREADY_CHOSEN, PassiveLoadout.Refusal.OVER_BUDGET,
			PassiveLoadout.Refusal.SAME_GROUP]:
		keys.append(PassiveLoadout.refusal_key(why))
	equal("each refusal the player can meet has its own words",
		[keys[0], keys.slice(1).has(""), keys.size()], ["", false, 5])


func _kept() -> void:
	_body.free()
	_body = _wearer()
	equal("a fighter built again holds what was chosen", [_sources(), _stacks(LARGE)],
		[[PassiveLoadout.SOURCE], 1])
	Flags.clear_all()
	Events.game_started.emit()
	equal("a new game clears what was learned and chosen",
		[_sources(), PassiveLoadout.known(HERO).size(), _stacks(LARGE)], [[], 0, 0])


func _sources() -> Array[StringName]:
	var passives: PassiveSet = PassiveSet.of(_body)
	return passives.sources() if passives != null else ([] as Array[StringName])


func _stacks(passive_id: StringName) -> int:
	return StatusSet.of(_body).stacks(PassiveDb.passive(passive_id).held.id)


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
	bag.add(COAT)
	GearSet.fit(body, _def, true)
	return body


func _passive(id: StringName, cost: int, group: StringName) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = id
	made.name_key = "ui.cancel"
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
	var directory: String = RunScratch.path("passive_loadout")
	for sub: String in ["gear", "passives"]:
		DirAccess.make_dir_recursive_absolute(directory.path_join(sub))
	for made: PassiveSkill in [_passive(SMALL, 2, &"fixture_group"), _passive(LARGE, 3, &""),
			_passive(TWIN, 1, &"fixture_group")]:
		ResourceSaver.save(made, directory.path_join("passives/%s.tres" % String(made.id).get_file()))
	PassiveDb.content_dir = directory.path_join("passives")
	PassiveDb.rescan()
	var kind := GearType.new()
	kind.type_id = &"gear_type/fixture_loadout_coat"
	kind.name_key = "ui.cancel"
	kind.slots = [&"body"]
	var coat := GearDefinition.new()
	coat.id = StringName(GearDb.ID_PREFIX + "fixture_loadout_coat")
	coat.item_id = COAT
	coat.type = kind
	ResourceSaver.save(coat, directory.path_join("gear/fixture_loadout_coat.tres"))
	GearDb.content_dir = directory.path_join("gear")
	GearDb.rescan()
	# The lessons go on the loaded piece, naming the very passives the catalogue holds.
	GearDb.for_item(COAT).teaches = [_lesson(SMALL, 1), _lesson(LARGE, 2)]
