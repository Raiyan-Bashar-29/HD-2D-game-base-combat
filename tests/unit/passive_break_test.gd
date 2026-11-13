extends TestCase
## A piece that breaks, and adapting resistance (C9.5b): the effect BREAK_PIECE, the event
## SKILL_DONE, and a GIVE_STATUS that picks its status by the element of the hit.
##
## OWNS: assertions about `GearBreak`, `PassiveEffect.Kind.BREAK_PIECE`,
## `PassiveEffect.per_element` and `PassiveTrigger.Event.SKILL_DONE`.
## MUST NOT: name a game's gear, passives or fighters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const E := PassiveTrigger.Event
const K := PassiveEffect.Kind
const COAT: StringName = FixtureContent.WORN_ITEM
const CROWN: StringName = FixtureContent.UNIQUE_ITEM
const FOE: StringName = &"fixture_break_foe"
const TRUMP: StringName = &"fixture_trump"
const FIRE: StringName = &"fixture_fire"
const ICE: StringName = &"fixture_ice"

var _bodies: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(9)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_content()
	_content()
	_saves_once()
	_cursed_and_innate()
	_not_a_piece()
	_trump_card()
	_adapts()
	for body: Node in _bodies:
		body.free()
	_bodies.clear()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var none: PassiveEffect = _effect(K.GIVE_STATUS)
	var listed: PassiveEffect = _effect(K.GIVE_STATUS)
	listed.per_element = {FIRE: _resist(FIRE)}
	var far: PassiveEffect = _effect(K.BREAK_PIECE)
	far.target = PassiveEffect.Target.OTHER
	equal("a GIVE_STATUS with a status per element is sound; one with neither, and a "
			+ "BREAK_PIECE aimed at somebody else, are flagged", [listed.problems("x").size(),
		none.problems("x").size(), far.problems("x").size(), _effect(K.BREAK_PIECE).problems("x").size()],
		[0, 1, 1, 0])


func _saves_once() -> void:
	_coat().passives = [_passive("fixture_break_plate", [_waits(E.LETHAL_HIT,
		[_effect(K.SURVIVE), _effect(K.BREAK_PIECE)])])]
	var me: Combatant = _wearer(&"fixture_break_saved")
	var body: Node = me.get_parent()
	GearSet.of(body).wear(COAT)
	var worn: Array = [me.sheet.value(&"attack"), _sources(body).size()]
	me.receive(_hit(500.0), FOE)
	equal("a lethal hit is survived and the piece that saved its wearer breaks: it is off, out "
			+ "of the bag, and its stats and passives are gone",
		[worn, _hp(me), GearSet.of(body).worn_ids(), Inventory.of(body).has(COAT),
			me.sheet.value(&"attack"), _sources(body).size()], [[7.0, 1], 1, [], false, 2.0, 0])
	me.receive(_hit(500.0), FOE)
	equal("with the piece gone the next lethal hit fells the wearer", _hp(me), 0)


func _cursed_and_innate() -> void:
	_coat().cursed = true
	var me: Combatant = _wearer(&"fixture_break_cursed")
	GearSet.of(me.get_parent()).wear(COAT)
	me.receive(_hit(500.0), FOE)
	_coat().cursed = false
	var foe: Combatant = _wearer(&"fixture_break_innate", false)
	var gear: GearSet = GearSet.of(foe.get_parent())
	gear.innate = [COAT]
	gear.wear(COAT)
	var on: int = gear.worn_ids().size()
	foe.receive(_hit(500.0), FOE)
	equal("a cursed piece breaks too, and so does the starting piece of a fighter with no bag",
		[GearSet.of(me.get_parent()).worn_ids(), on, gear.worn_ids(), gear.innate, _hp(foe)],
		[[], 1, [], [], 1])


func _not_a_piece() -> void:
	var me: Combatant = _wearer(&"fixture_break_own")
	var body: Node = me.get_parent()
	GearSet.of(body).wear(CROWN)
	var def := CombatantDef.new()
	def.passives = [_passive("fixture_break_own", [_waits(E.LETHAL_HIT,
		[_effect(K.SURVIVE), _effect(K.BREAK_PIECE)])])]
	PassiveLending.own(body, def)
	me.receive(_hit(500.0), FOE)
	equal("BREAK_PIECE on a passive the character owns breaks nothing",
		[_hp(me), GearSet.of(body).worn_ids(), Inventory.of(body).has(CROWN)], [1, [CROWN], true])


func _trump_card() -> void:
	var spent: PassiveTrigger = _waits(E.SKILL_DONE, [_effect(K.BREAK_PIECE)])
	spent.tag = TRUMP
	var marks: PassiveEffect = _effect(K.POOL_FLAT)
	marks.pool = &"mp"
	marks.amount = -1.0
	_coat().passives = [_passive("fixture_break_trump", [spent, _waits(E.HIT_DEALT, [marks])])]
	var me: Combatant = _wearer(&"fixture_break_trump")
	var body: Node = me.get_parent()
	var foe: Combatant = _wearer(&"fixture_break_target", false, &"side_b")
	GearSet.of(body).wear(COAT)
	var targets: Array[Combatant] = [foe]
	SkillUse.apply(me, _skill([]), targets, _rng)
	equal("a skill without the tag leaves the piece on",
		[GearSet.of(body).worn_ids(), _mp(me)], [[COAT], 98])
	SkillUse.apply(me, _skill([TRUMP]), targets, _rng)
	equal("the trump card lands while the piece is still on (its dealt-hit passive wakes), and "
			+ "only then does the piece break",
		[_mp(me), GearSet.of(body).worn_ids(), Inventory.of(body).has(COAT)], [97, [], false])
	SkillUse.apply(me, _skill([TRUMP]), targets, _rng)
	equal("after that the piece's passives wake no more", _mp(me), 97)


func _adapts() -> void:
	var learns: PassiveEffect = _effect(K.GIVE_STATUS)
	learns.per_element = {FIRE: _resist(FIRE), ICE: _resist(ICE)}
	var me: Combatant = _wearer(&"fixture_break_adapts")
	var body: Node = me.get_parent()
	var def := CombatantDef.new()
	def.passives = [_passive("fixture_break_adapts", [_waits(E.HIT_TAKEN, [learns])])]
	PassiveLending.own(body, def)
	var foe: Combatant = _wearer(&"fixture_break_burner", false, &"side_b")
	var first: int = foe.hit(me, 1.0, FIRE, _rng, true).total()
	var second: int = foe.hit(me, 1.0, FIRE, _rng, true).total()
	foe.hit(me, 1.0, &"fixture_wind", _rng, true)
	var statuses: StatusSet = StatusSet.of(body)
	var before: Array = [statuses.stacks(_resist_id(FIRE)), statuses.stacks(_resist_id(ICE)),
		statuses.held().size()]
	foe.hit(me, 1.0, ICE, _rng, true)
	equal("a hit teaches resistance to its own element: the second fire hit does nothing, an "
			+ "element not listed teaches nothing, and an ice hit teaches ice",
		[first > 0, second, before, statuses.stacks(_resist_id(ICE))], [true, 0, [1, 0, 1], 1])


func _sources(body: Node) -> Array[StringName]:
	var passives: PassiveSet = PassiveSet.of(body)
	return passives.sources() if passives != null else ([] as Array[StringName])


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _mp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"mp")


func _coat() -> GearDefinition:
	return GearDb.for_item(COAT)


func _hit(amount: float) -> DamageResult:
	var result := DamageResult.new()
	result.amount = amount
	return result


func _effect(kind: PassiveEffect.Kind) -> PassiveEffect:
	var made := PassiveEffect.new()
	made.kind = kind
	return made


func _waits(event: PassiveTrigger.Event, effects: Array[PassiveEffect]) -> PassiveTrigger:
	var made := PassiveTrigger.new()
	made.event = event
	made.effects = effects
	return made


func _passive(name: String, triggers: Array[PassiveTrigger]) -> PassiveSkill:
	var made := PassiveSkill.new()
	made.id = StringName(PassiveDb.ID_PREFIX + name)
	made.name_key = "ui.cancel"
	made.triggers = triggers
	return made


func _resist_id(element: StringName) -> StringName:
	return StringName(StatusDb.ID_PREFIX + "fixture_break_" + String(element))


# A status that takes the whole of `element`'s damage away while it is held.
func _resist(element: StringName) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = _resist_id(element)
	made.name_key = "ui.cancel"
	made.modifiers = [StatModifier.of(StringName("resist_" + String(element)), StatModifier.Op.ADD, 1.0, &"")]
	return made


func _skill(tags: Array[StringName]) -> Skill:
	var made := Skill.new()
	made.power = 1.0
	made.sure_hit = true
	made.tags = tags
	return made


# A fighter with gear slots; with `carries`, a bag holding the two pieces as well.
func _wearer(id: StringName, carries: bool = true, side: StringName = &"side_a") -> Combatant:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var bag := Inventory.new()
	if carries:
		body.add_child(bag)
	else:
		bag.free()
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 99.0, &"attack": 2.0}
	body.add_child(fighter)
	attach(body)
	_bodies.append(body)
	Vitals.of(body).set_to(&"mp", 99)
	var gear := GearSet.new()
	gear.kept = carries
	body.add_child(gear)
	if carries:
		bag.add(COAT)
		bag.add(CROWN)
	return fighter


func _write_content() -> void:
	var directory: String = RunScratch.path("passive_break")
	DirAccess.make_dir_recursive_absolute(directory)
	var coat: GearDefinition = _piece("fixture_break_coat", COAT, &"body")
	coat.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 5.0, &"")]
	ResourceSaver.save(coat, directory.path_join("fixture_break_coat.tres"))
	ResourceSaver.save(_piece("fixture_break_crown", CROWN, &"head"),
		directory.path_join("fixture_break_crown.tres"))
	GearDb.content_dir = directory
	GearDb.rescan()


func _piece(name: String, item_id: StringName, slot: StringName) -> GearDefinition:
	var kind := GearType.new()
	kind.type_id = StringName("gear_type/" + name)
	kind.name_key = "ui.cancel"
	kind.slots = [slot]
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	return made
