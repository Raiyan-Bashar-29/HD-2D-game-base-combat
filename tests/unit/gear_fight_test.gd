extends TestCase
## Gear in a fight (C7.1b): a fighter's definition lists the gear it starts with; a battle, the
## field and a party switch all give the fighter its worn set; a starting piece is the fighter's
## own and need not be in the bag; a foe's gear is never saved; and a game names its slot list in
## a project setting.
##
## OWNS: assertions about `GearSet.fit`, `CombatantDef.gear`, and the worn set in `BattleSetup`,
## `ActionHost` and `FieldParty`.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const SLOT: int = 3
const BASE_ATTACK: float = 2.0
const BLADE: StringName = FixtureContent.STACK_ITEM
const SECOND_BLADE: StringName = FixtureContent.WORN_ITEM
const HELM: StringName = FixtureContent.SPARE_ITEM
const HERO: StringName = &"fixture_gear_hero"
const MATE: StringName = &"fixture_gear_mate"
const FOE: StringName = &"fixture_gear_foe"

var _directory: String
var _holder: Node
var _player: PlayerController


func run() -> void:
	plan(23)
	SaveFixture.activate()
	Fixtures.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Flags.clear_all()
	_write_gear()
	_definitions()
	_in_battle()
	_in_the_field()
	_slot_list()
	SaveSystem.delete_slot(SLOT)
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _definitions() -> void:
	var def: CombatantDef = _def(HERO, &"player", [BLADE])
	equal("a fighter starting with real gear has no problems", def.problems("fixture").size(), 0)
	def.gear = [BLADE, FixtureContent.ABSENT_ITEM]
	equal("starting with an item that has no gear file is a problem", def.problems("fixture").size(), 1)


func _in_battle() -> void:
	_holder = Node.new()
	attach(_holder)
	var battle: Battle = _battle()
	var hero: GearSet = GearSet.of(battle.party[0].get_parent())
	equal("a party member starts wearing its starting piece, with its stats on",
		[hero.worn(&"weapon"), battle.party[0].sheet.value(&"attack")], [BLADE, BASE_ATTACK + 4.0])
	equal("and that is written down, so it is saved", Flags.get_string(hero.key(BLADE)), "weapon")
	var plain: GearSet = GearSet.of(battle.party[1].get_parent())
	equal("a party member with no starting gear still has a worn set, empty",
		[plain != null, plain.worn_ids().size()], [true, 0])
	var foe: GearSet = GearSet.of(battle.enemies[0].get_parent())
	equal("a foe wears its starting piece too",
		[foe.worn(&"weapon"), battle.enemies[0].sheet.value(&"attack")], [SECOND_BLADE, BASE_ATTACK + 7.0])
	equal("but nothing about a foe's gear is written down",
		[Flags.with_prefix("gear/" + String(FOE)).size(), Flags.with_prefix("gear_started/" + String(FOE)).size()],
		[0, 0])
	equal("a foe with no starting gear has no worn set", GearSet.of(battle.enemies[1].get_parent()), null)
	equal("the party member takes the piece off", hero.take_off(BLADE), true)
	_end(battle)
	battle = _battle()
	hero = GearSet.of(battle.party[0].get_parent())
	equal("the next battle does not put it back: the player's choice stands",
		[hero.worn_ids().size(), battle.party[0].sheet.value(&"attack")], [0, BASE_ATTACK])
	equal("the foe wears its piece again", GearSet.of(battle.enemies[0].get_parent()).worn(&"weapon"),
		SECOND_BLADE)
	equal("a starting piece can be put back on with no bag", hero.wear(BLADE), true)
	_end(battle)
	_holder.free()


func _in_the_field() -> void:
	Flags.clear_all()
	var lead: ActionLoadout = _loadout(HERO, [BLADE])
	lead.companions = [_loadout(MATE, [SECOND_BLADE])]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, lead)
	var line: Array[PartyFollower] = FieldParty.spawn(_player, lead)
	var mine: GearSet = GearSet.of(_player)
	var bag: Inventory = Inventory.of(_player)
	equal("the field player wears its starting piece, though the bag does not hold it",
		[mine.worn(&"weapon"), bag.has(BLADE), Combatant.of(_player).sheet.value(&"attack")],
		[BLADE, false, BASE_ATTACK + 4.0])
	bag.add(HELM)
	mine.wear(HELM)
	equal("a change in the bag leaves a starting piece on", mine.worn_ids(), [HELM, BLADE])
	bag.remove(HELM)
	equal("while a carried piece that left the bag comes off", mine.worn_ids(), [BLADE])
	equal("a follower wears its own starting piece",
		[GearSet.of(line[0]).worn(&"weapon"), Combatant.of(line[0]).sheet.value(&"attack")],
		[SECOND_BLADE, BASE_ATTACK + 7.0])
	equal("a switch happens", FieldParty.switch(_player), true)
	equal("each member's gear went with them",
		[GearSet.of(line[0]) == mine, GearSet.of(_player).worn(&"weapon"),
			Combatant.of(_player).sheet.value(&"attack"), Combatant.of(line[0]).sheet.value(&"attack")],
		[true, SECOND_BLADE, BASE_ATTACK + 7.0, BASE_ATTACK + 4.0])
	bag.add(HELM)
	equal("and the bag changing does not strip the member who now leads",
		GearSet.of(_player).worn(&"weapon"), SECOND_BLADE)
	_saving(mine, line[0])
	for follower: PartyFollower in FieldParty.followers(_player):
		follower.free()
	_player.free()


# `mine` is the first leader's worn set, which the switch left on `body`.
func _saving(mine: GearSet, body: Node) -> void:
	mine.take_off(BLADE)
	SaveSystem.save_to_slot(SLOT)
	mine.wear(BLADE)
	SaveSystem.load_from_slot(SLOT)
	equal("a starting piece taken off stays off after a load",
		[mine.worn_ids().size(), Combatant.of(body).sheet.value(&"attack")], [0, BASE_ATTACK])
	Flags.clear_all()
	Events.game_started.emit()
	equal("a new game puts the starting pieces on again",
		[mine.worn(&"weapon"), Combatant.of(body).sheet.value(&"attack")], [BLADE, BASE_ATTACK + 4.0])


func _slot_list() -> void:
	var path: String = _directory.path_join("fixture_rules.tres")
	var narrow := GearRules.new()
	narrow.slots = [&"weapon"]
	ResourceSaver.save(narrow, path)
	ProjectSettings.set_setting(GearSet.RULES_SETTING, path)
	var body := Node.new()
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	body.add_child(fighter)
	var gear: GearSet = GearSet.fit(body, _def(HERO, &"player", []), true)
	attach(body)
	equal("a game's slot list, named in the project setting, is the one a fighter uses",
		[gear.rules.slots, gear.refusal(HELM)], [[&"weapon"], GearSet.Refusal.NO_SLOT])
	ProjectSettings.set_setting(GearSet.RULES_SETTING, null)
	equal("with no setting the nine default slots are used", GearSet.configured_rules().slots.size(), 9)
	body.free()


func _battle() -> Battle:
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_gear"
	encounter.enemies = [_def(FOE, &"enemy", [SECOND_BLADE]), _def(&"fixture_gear_bare", &"enemy", [])]
	var party: Array[CombatantDef] = [_def(HERO, &"player", [BLADE]), _def(MATE, &"player", [])]
	return BattleSetup.build(encounter, party, _holder, RandomNumberGenerator.new())


# Frees the battle's fighters at once; `release` only queues them, and a test never waits.
func _end(battle: Battle) -> void:
	BattleSetup.release(battle)
	for actor: Node in _holder.get_children():
		actor.free()


func _def(id: StringName, side: StringName, gear: Array[StringName]) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.cancel"
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"speed": 3.0, &"attack": BASE_ATTACK, &"defence": 1.0}
	def.gear = gear
	return def


func _loadout(id: StringName, gear: Array[StringName]) -> ActionLoadout:
	var loadout := ActionLoadout.new()
	loadout.fighter = _def(id, &"player", gear)
	loadout.fighter.level_curve = LevelCurve.new()
	loadout.moves = MoveSet.new()
	return loadout


func _write_gear() -> void:
	_directory = RunScratch.path("gear_fight")
	DirAccess.make_dir_recursive_absolute(_directory)
	var blade := _type("fixture_blade", &"weapon")
	_save("fixture_blade", BLADE, blade, 4.0)
	_save("fixture_blade_two", SECOND_BLADE, blade, 7.0)
	_save("fixture_helm", HELM, _type("fixture_plate", &"head"), 0.0)
	GearDb.content_dir = _directory
	GearDb.rescan()


func _type(name: String, slot: StringName) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = [slot]
	return made


func _save(name: String, item_id: StringName, kind: GearType, attack: float) -> void:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	if attack != 0.0:
		made.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, attack, &"")]
	ResourceSaver.save(made, _directory.path_join(name + ".tres"))
