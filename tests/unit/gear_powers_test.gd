extends TestCase
## Special gear (C7.3): a worn piece lends the wearer a kit of hero powers; several kits live on
## one fighter at once; a power can need a piece, or a kind of piece, to be worn; and a piece can
## carry its own pool.
##
## OWNS: assertions about `GearDefinition.kit`, `PowerSet.lend`, `kits`, `powers` and `status`,
## `GearSet` handing kits over, `GearSet.wearing`, `Power.requires_gear` and its menu words.
## MUST NOT: name a game's gear, items or characters, or wait for frames. The gear files are
## written to this run's scratch directory, over the fixture items.

const WAND: StringName = FixtureContent.STACK_ITEM
const CHARM: StringName = FixtureContent.WORN_ITEM
const HELM: StringName = FixtureContent.SPARE_ITEM
const WAND_TYPE: StringName = &"gear_type/fixture_wand"
const AURA: StringName = &"status/fixture_wand_aura"
const BOLT: StringName = &"power/fixture_wand_bolt"
const SPARK: StringName = &"power/fixture_charm_spark"
const OWN: StringName = &"power/fixture_own"
const HERO: StringName = &"fixture_wand_hero"

var _directory: String


func run() -> void:
	plan(26)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_write_gear()
	_content()
	_lending()
	_several_kits()
	_needing_gear()
	_in_battle()
	GearDb.content_dir = GearDb.GEAR_DIR
	GearDb.rescan()
	Flags.clear_all()


func _content() -> void:
	var wand: GearDefinition = GearDb.for_item(WAND)
	equal("a piece with a sound kit has no problems", wand.problems().size(), 0)
	wand.kit.powers.append(Power.new())
	equal("a piece's kit is checked with the piece", wand.problems().size() > 0, true)
	wand.kit.powers.pop_back()


func _lending() -> void:
	var body: Node = _body(false)
	var fighter: Combatant = Combatant.of(body)
	var gear: GearSet = GearSet.of(body)
	equal("a fighter with no powers and nothing worn has no power set", PowerSet.of(body), null)
	gear.wear(WAND)
	var powers: PowerSet = PowerSet.of(body)
	var bolt: Power = GearDb.for_item(WAND).kit.power(BOLT)
	equal("wearing a piece with a kit gives the wearer its powers",
		[powers != null and powers.has(bolt), PowerUse.refusal(fighter, bolt)], [true, PowerUse.Reason.NONE])
	equal("and the kit's stat bonus, its passive, and the piece's own pool",
		[fighter.sheet.value(&"attack"), StatusSet.of(body).stacks(AURA), Vitals.of(body).maximum(&"charge")],
		[5.0, 1, 5])
	equal("a status the piece's kit grants is found for a load", PowerSet.passive_of(body, AURA) != null, true)
	var foe: Node = _body(false)
	Combatant.of(foe).faction = &"enemy"
	var aimed: Array[Combatant] = [Combatant.of(foe)]
	equal("the lent power is used like any other",
		[PowerUse.use(fighter, bolt, aimed, RandomNumberGenerator.new()), Vitals.of(foe).current(&"hp") < 40],
		[true, true])
	gear.refresh()
	equal("a refresh, as after a load, leaves a worn kit alone: its cooldown keeps counting",
		powers.cooldown_left(BOLT), 3.0)
	_whole_body()
	gear.take_off(WAND)
	equal("taking the piece off takes the powers away",
		[powers.has(bolt), PowerUse.refusal(fighter, bolt), powers.cooldown_left(BOLT)],
		[false, PowerUse.Reason.NOT_EQUIPPED, 0.0])
	equal("and the bonus, the passive and the pool",
		[fighter.sheet.value(&"attack"), StatusSet.of(body).stacks(AURA), Vitals.of(body).maximum(&"charge")],
		[2.0, 0, 0])
	body.free()
	foe.free()


# A body put together first and added to the scene whole, already wearing the piece by its flag.
func _whole_body() -> void:
	var body := Node3D.new()
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_wand_whole"
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	body.add_child(fighter)
	var gear := GearSet.new()
	gear.innate = [WAND]
	body.add_child(gear)
	Flags.set_flag(gear.key(WAND), "weapon")
	attach(body)
	var powers: PowerSet = PowerSet.of(body)
	equal("a body that enters the scene already wearing the piece gets its powers",
		powers != null and _ids(powers.powers()) == [BOLT], true)
	body.free()
	Flags.clear_all()


func _several_kits() -> void:
	var body: Node = _body(true)
	var fighter: Combatant = Combatant.of(body)
	var gear: GearSet = GearSet.of(body)
	var powers: PowerSet = PowerSet.of(body)
	var own: PowerKit = _kit(&"kit/fixture_own", [OWN])
	own.powers[0].cooldown = 2.0
	powers.equip(own)
	gear.wear(CHARM)
	gear.wear(HELM)
	gear.wear(WAND)
	equal("the fighter's own powers come first, then gear's in slot order, the weapon first",
		_ids(powers.powers()), [OWN, BOLT, SPARK])
	equal("the quick slots and the menu list them the same way",
		[_ids(PowerSlots.powers(fighter)), PowerMenu.commands(fighter).size()], [[OWN, BOLT, SPARK], 3])
	powers.start_cooldown(own.powers[0])
	powers.start_cooldown(GearDb.for_item(CHARM).kit.power(SPARK))
	gear.take_off(WAND)
	equal("taking one piece off leaves the other kits' cooldowns running",
		[powers.cooldown_left(OWN), powers.cooldown_left(SPARK), _ids(powers.powers())],
		[2.0, 4.0, [OWN, SPARK]])
	gear.wear(WAND)
	powers.unequip()
	equal("taking the fighter's own kit off leaves gear's kits on",
		[_ids(powers.powers()), StatusSet.of(body).stacks(AURA), fighter.sheet.value(&"attack")],
		[[BOLT, SPARK], 1, 5.0])
	powers.equip(own)
	equal("and putting it back lists it first again", _ids(powers.powers()), [OWN, BOLT, SPARK])
	equal("a piece with no kit lends none", powers.kits().size(), 3)
	body.free()


func _needing_gear() -> void:
	var body: Node = _body(true)
	var fighter: Combatant = Combatant.of(body)
	var gear: GearSet = GearSet.of(body)
	var own: PowerKit = _kit(&"kit/fixture_own", [OWN, &"power/fixture_kind"])
	own.powers[0].requires_gear = WAND
	own.powers[1].requires_gear = WAND_TYPE
	PowerSet.of(body).equip(own)
	equal("a power that needs a piece is refused while it is not worn",
		[PowerUse.refusal(fighter, own.powers[0]), PowerUse.refusal(fighter, own.powers[1])],
		[PowerUse.Reason.GEAR, PowerUse.Reason.GEAR])
	var key: String = PowerMenu.reason_key(fighter, own.powers[0])
	equal("and the menu has words for why", [key, tr(key) != key], [PowerMenu.GEAR_KEY, true])
	gear.wear(HELM)
	equal("another piece does not count", GearSet.wearing(body, WAND), false)
	gear.wear(WAND)
	equal("worn, the piece allows the power that names it, and the one that names its kind",
		[PowerUse.refusal(fighter, own.powers[0]), PowerUse.refusal(fighter, own.powers[1])],
		[PowerUse.Reason.NONE, PowerUse.Reason.NONE])
	equal("a fighter with no worn set wears nothing", GearSet.wearing(Node.new(), WAND), false)
	body.free()


func _in_battle() -> void:
	Flags.clear_all()
	var holder := Node.new()
	attach(holder)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_wand"
	encounter.enemies = [_def(&"fixture_wand_foe", &"enemy", [WAND], 1.0)]
	var party: Array[CombatantDef] = [_def(HERO, &"player", [WAND], 9.0)]
	var battle: Battle = BattleSetup.build(encounter, party, holder, RandomNumberGenerator.new())
	equal("in a battle a party member with no kit of its own has its weapon's powers on the menu",
		_ids(PowerSet.of(battle.party[0].get_parent()).powers()), [BOLT])
	equal("and so has a foe", PowerMenu.commands(battle.enemies[0]).size(), 1)
	var bolt := BattleCommand.for_power(GearDb.for_item(WAND).kit.power(BOLT))
	battle.next_turn()
	equal("the lent power is a battle command",
		[battle.act(bolt, [battle.enemies[0]]), Vitals.of(battle.enemies[0].get_parent()).current(&"hp") < 40],
		[true, true])
	BattleSetup.release(battle)
	for actor: Node in holder.get_children():
		actor.free()
	holder.free()
	# A second battle finds the piece already worn (it was written down), so the set is built
	# with the piece on from its first moment.
	holder = Node.new()
	attach(holder)
	battle = BattleSetup.build(encounter, party, holder, RandomNumberGenerator.new())
	equal("a fighter built already wearing the piece has its powers too",
		_ids(PowerSet.of(battle.party[0].get_parent()).powers()), [BOLT])
	BattleSetup.release(battle)
	for actor: Node in holder.get_children():
		actor.free()
	holder.free()


func _ids(powers: Array[Power]) -> Array[StringName]:
	var out: Array[StringName] = []
	for power: Power in powers:
		out.append(power.power_id)
	return out


# A fighter with a worn set that writes nothing down, and a power set when `with_powers`.
func _body(with_powers: bool) -> Node:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = HERO
	fighter.base_stats = {&"max_hp": 40.0, &"max_mp": 40.0, &"attack": 2.0, &"defence": 1.0}
	body.add_child(fighter)
	if with_powers:
		body.add_child(PowerSet.new())
	attach(body)
	var gear := GearSet.new()
	gear.kept = false
	body.add_child(gear)
	return body


func _def(id: StringName, side: StringName, gear: Array[StringName], speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "ui.cancel"
	def.faction = side
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 40.0, &"speed": speed, &"attack": 4.0, &"defence": 1.0}
	def.gear = gear
	return def


func _kit(id: StringName, power_ids: Array[StringName]) -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = id
	kit.name_key = "ui.cancel"
	for power_id: StringName in power_ids:
		var skill := Skill.new()
		skill.id = StringName(String(power_id).replace("power/", "skill/"))
		skill.name_key = "ui.cancel"
		skill.power = 4.0
		skill.sure_hit = true
		var power := Power.new()
		power.power_id = power_id
		power.name_key = "ui.cancel"
		power.skill = skill
		kit.powers.append(power)
	return kit


func _write_gear() -> void:
	_directory = RunScratch.path("gear_powers")
	DirAccess.make_dir_recursive_absolute(_directory)
	_save("fixture_wand", WAND, _type("fixture_wand", &"weapon"))
	_save("fixture_charm", CHARM, _type("fixture_charm", &"accessory_1"))
	_save("fixture_helm", HELM, _type("fixture_cap", &"head"))
	GearDb.content_dir = _directory
	GearDb.rescan()
	# The kits are put on the loaded pieces here, so the test holds the very objects.
	var wand: GearDefinition = GearDb.for_item(WAND)
	wand.modifiers = [StatModifier.of(&"max_charge", StatModifier.Op.ADD, 5.0, &"")]
	wand.kit = _kit(&"kit/fixture_wand", [BOLT])
	wand.kit.powers[0].cooldown = 3.0
	wand.kit.stat_bonuses = [StatModifier.of(&"attack", StatModifier.Op.ADD, 3.0, &"anything")]
	var aura := StatusEffect.new()
	aura.id = AURA
	aura.name_key = "ui.cancel"
	aura.duration = 0.0
	wand.kit.passives = [aura]
	var charm: GearDefinition = GearDb.for_item(CHARM)
	charm.kit = _kit(&"kit/fixture_charm", [SPARK])
	charm.kit.powers[0].cooldown = 4.0


func _type(name: String, slot: StringName) -> GearType:
	var made := GearType.new()
	made.type_id = StringName("gear_type/" + name)
	made.name_key = "ui.cancel"
	made.slots = [slot]
	return made


func _save(name: String, item_id: StringName, kind: GearType) -> void:
	var made := GearDefinition.new()
	made.id = StringName(GearDb.ID_PREFIX + name)
	made.item_id = item_id
	made.type = kind
	ResourceSaver.save(made, _directory.path_join(name + ".tres"))
