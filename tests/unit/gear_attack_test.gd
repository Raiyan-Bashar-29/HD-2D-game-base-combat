extends TestCase
## The worn weapon on attacks (C7.1c): a worn piece lends the wearer's plain attack an element
## and weakness tags, in a battle and in the field, and a piece can take up more than one slot
## (a two-handed sword and the off hand).
##
## OWNS: assertions about `GearDefinition`'s and `GearType`'s `element`, `attack_tags` and
## `blocks`, what `GearSet` lends to its `Combatant`, and the plain attack in `Battle` and
## `Hurtbox` reading it.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const LANCE: StringName = FixtureContent.STACK_ITEM
const HELM: StringName = FixtureContent.WORN_ITEM
const SHIELD: StringName = FixtureContent.SPARE_ITEM
const GREAT: StringName = FixtureContent.UNIQUE_ITEM
const FLAME: StringName = &"fixture_flame"
const FROST: StringName = &"fixture_frost"
const PIERCE: StringName = &"fixture_pierce"
const HERO: StringName = &"fixture_lancer"
const FOE: StringName = &"fixture_lance_foe"

var _directory: String


func run() -> void:
	plan(21)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_gear()
	_content()
	_lending()
	_blocking()
	_in_battle()
	_in_the_field()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var lance: GearDefinition = GearDb.for_item(LANCE)
	equal("a piece with no element of its own lends its type's", lance.strike_element(), FLAME)
	lance.element = FROST
	equal("its own element wins over the type's", lance.strike_element(), FROST)
	lance.element = &""
	lance.attack_tags = [PIERCE, &"fixture_long"]
	equal("the type's tags and its own are joined, each once", lance.all_attack_tags(),
		[PIERCE, &"fixture_long"])
	lance.attack_tags = []
	var great: GearDefinition = GearDb.for_item(GREAT)
	equal("a piece takes up the slots its type blocks", great.all_blocks(), [&"offhand"])
	equal("the fixture pieces have no problems", [lance.problems().size(), great.problems().size()], [0, 0])
	great.blocks = [&"weapon", &""]
	equal("blocking its own slot, or a slot with no name, is a problem", great.problems().size(), 2)
	great.blocks = []
	var kind := _type("fixture_bad", &"weapon")
	kind.attack_tags = [&""]
	kind.blocks = [&"weapon"]
	equal("a type is checked the same way", kind.problems("fixture").size(), 2)


func _lending() -> void:
	var body: Node = _body(HERO, [&"fixture_fist"])
	var fighter: Combatant = Combatant.of(body)
	var gear: GearSet = GearSet.of(body)
	equal("with nothing worn the plain attack has no element and the fighter's own tags",
		[fighter.strike_element(&""), fighter.strike_tags()], [&"", [&"fixture_fist"]])
	gear.wear(LANCE)
	equal("a worn weapon lends its element and its tags",
		[fighter.strike_element(&""), fighter.strike_tags()], [FLAME, [&"fixture_fist", PIERCE]])
	equal("a move that names its own element keeps it", fighter.strike_element(FROST), FROST)
	gear.wear(HELM)
	equal("the weapon speaks first: a helm's element does not replace it", fighter.lent_element, FLAME)
	gear.take_off(LANCE)
	equal("with the weapon off, the next piece's element is lent and the weapon's tags are gone",
		[fighter.lent_element, fighter.strike_tags()], [FROST, [&"fixture_fist"]])
	gear.wear(LANCE)
	fighter.lent_element = &""
	gear.refresh()
	equal("a refresh, as after a load, lends again", fighter.lent_element, FLAME)
	body.free()


func _blocking() -> void:
	var body: Node = _body(HERO, [])
	var fighter: Combatant = Combatant.of(body)
	var gear: GearSet = GearSet.of(body)
	gear.wear(SHIELD)
	gear.wear(HELM)
	gear.wear(GREAT)
	equal("a two-handed weapon empties the off hand, and leaves the rest on",
		[gear.worn(&"offhand"), gear.worn(&"weapon"), gear.worn(&"head")], [&"", GREAT, HELM])
	equal("the piece that came off took its stats with it", fighter.sheet.value(&"defence"), 1.0)
	gear.wear(SHIELD)
	equal("a piece put in the blocked slot takes the two-handed weapon off",
		[gear.worn(&"offhand"), gear.worn(&"weapon"), fighter.sheet.value(&"defence")], [SHIELD, &"", 4.0])
	body.free()


func _in_battle() -> void:
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_lance"
	var immune: CombatantDef = _def(FOE, &"enemy", [LANCE], 1.0)
	immune.base_stats[StringName("resist_" + String(FLAME))] = 1.0
	var weak: CombatantDef = _def(&"fixture_lance_weak", &"enemy", [], 1.0)
	weak.base_stats[&"max_shield"] = 3.0
	weak.weak_to = [PIERCE, FLAME]
	encounter.enemies = [immune, weak]
	var party: Array[CombatantDef] = [_def(HERO, &"player", [LANCE], 9.0)]
	var battle: Battle = BattleSetup.build(encounter, party, holder, RandomNumberGenerator.new())
	for fighter: Combatant in battle.party + battle.enemies:
		fighter.formula = _formula()
	var attack := BattleCommand.new()
	battle.next_turn()
	battle.act(attack, [battle.enemies[0]])
	equal("in a battle the plain attack is a hit of the weapon's element: a foe immune to it takes nothing",
		Vitals.of(battle.enemies[0].get_parent()).current(&"hp"), 40)
	equal("a foe's unsaved set lends too", battle.enemies[0].lent_element, FLAME)
	while battle.next_turn() != battle.party[0]:
		battle.act(attack, [battle.party[0]])
	battle.act(attack, [battle.enemies[1]])
	var target: Vitals = Vitals.of(battle.enemies[1].get_parent())
	equal("another foe is hurt, and a weakness to the weapon's tag or element chips its shield once",
		[target.current(&"hp") < 40, target.current(&"shield")], [true, 2])
	BattleSetup.release(battle)
	for actor: Node in holder.get_children():
		actor.free()
	holder.free()


func _in_the_field() -> void:
	Flags.clear_all()
	var hero: Node = _body(HERO, [])
	GearSet.of(hero).wear(LANCE)
	var foe: Node = _body(FOE, [])
	var target: Combatant = Combatant.of(foe)
	target.faction = &"enemy"
	target.weak_to = [PIERCE]
	target.sheet.set_base(StringName("resist_" + String(FLAME)), 1.0)
	var hurtbox := Hurtbox.new()
	foe.add_child(hurtbox)
	var move := ActionMove.new()
	move.power = 3.0
	var rng := RandomNumberGenerator.new()
	hurtbox.take(Combatant.of(hero), move, rng, Vector3.ZERO)
	var vitals: Vitals = Vitals.of(foe)
	equal("in the field a move with no element takes the weapon's, and its tag chips the shield",
		[vitals.current(&"hp"), vitals.current(&"shield")], [40, 2])
	move.element = FROST
	hurtbox.take(Combatant.of(hero), move, rng, Vector3.ZERO)
	equal("a move with its own element keeps it, so the same foe is hurt",
		vitals.current(&"hp") < 40, true)
	hero.free()
	foe.free()


# A bare fighter in the tree: vitals, a combatant and an unsaved worn set, with no bag.
func _body(id: StringName, tags: Array[StringName]) -> Node:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.base_stats = {&"max_hp": 40.0, &"max_shield": 3.0, &"attack": 2.0, &"defence": 1.0}
	fighter.attack_tags = tags
	fighter.formula = _formula()
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.kept = false
	body.add_child(gear)
	attach(body)
	return body


# Attack against defence, then the element: no roll, so a test knows the number.
func _formula() -> DamageFormula:
	var formula := DamageFormula.new()
	formula.stages = [AttackDefenceStage.new(), ElementStage.new()]
	return formula


func _def(id: StringName, side: StringName, gear: Array[StringName], speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.cancel"
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"speed": speed, &"attack": 4.0, &"defence": 1.0}
	def.gear = gear
	return def


func _write_gear() -> void:
	_directory = RunScratch.path("gear_attack")
	DirAccess.make_dir_recursive_absolute(_directory)
	var lance := _type("fixture_lance", &"weapon")
	lance.element = FLAME
	lance.attack_tags = [PIERCE]
	_save("fixture_lance", LANCE, lance, &"", 0.0)
	_save("fixture_helm", HELM, _type("fixture_plate", &"head"), FROST, 0.0)
	_save("fixture_shield", SHIELD, _type("fixture_guard", &"offhand"), &"", 3.0)
	var great := _type("fixture_great", &"weapon")
	great.blocks = [&"offhand"]
	_save("fixture_great", GREAT, great, &"", 0.0)
	GearDb.content_dir = _directory
	GearDb.rescan()


func _type(name: String, slot: StringName) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = [slot]
	return made


func _save(name: String, item_id: StringName, kind: GearType, element: StringName, defence: float) -> void:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	made.element = element
	if defence != 0.0:
		made.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, defence, &"")]
	ResourceSaver.save(made, _directory.path_join(name + ".tres"))
