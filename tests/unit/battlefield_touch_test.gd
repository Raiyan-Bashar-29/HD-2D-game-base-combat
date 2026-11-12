extends TestCase
## What a battlefield does to the fighters inside it in the field (C6.9b): the new shapes and
## their problems; a skill used on each fighter as it comes in and as it leaves (rising and ending
## too, and walking in and out of an aura); a skill on a clock that grows each tick and passes
## over the fallen; pull and push; and immunity by a held tag and by `resist_field_<name>`. The
## battle reading is in `battlefield_battle_test`.
##
## OWNS: assertions about `BattlefieldEffect`'s C6.9b fields and what `BattlefieldRun` does with
## them in the field.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const BURST: StringName = &"status/fixture_touch_burst"
const HALO: StringName = &"status/fixture_touch_halo"
const STORM: StringName = &"status/fixture_touch_storm"
const VORTEX: StringName = &"status/fixture_touch_vortex"
const GUARDED: StringName = &"status/fixture_touch_guarded"
const BOUND: StringName = &"status/fixture_touch_bound"
const WARD: StringName = &"status/fixture_touch_ward"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _ally: Combatant
var _foe: Combatant
var _far: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(10)
	Flags.clear_all()
	_rng.seed = 3
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_touch_me", &"player", Vector3.ZERO, _kit())
	_ally = _fighter(&"fixture_touch_ally", &"player", Vector3(2.0, 0.0, 0.0), null)
	_foe = _fighter(&"fixture_touch_foe", &"enemy", Vector3(0.0, 0.0, -3.0), null)
	_far = _fighter(&"fixture_touch_far", &"enemy", Vector3(0.0, 0.0, -20.0), null)
	_reset()
	_enter_and_exit()
	_walking()
	_clock()
	_movement()
	_immunity()
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var clean := BattlefieldEffect.new()
	clean.tick = _restore(&"fixture_touch_clean", 1.0)
	clean.tick_seconds = 1.0
	clean.pull = 1.0
	clean.immune_tags = [&"fixture_touch_ward"]
	var no_clock := BattlefieldEffect.new()
	no_clock.tick = _restore(&"fixture_touch_no_clock", 1.0)
	var no_tick := BattlefieldEffect.new()
	no_tick.statuses = [_status(BOUND)]
	no_tick.tick_turns = 2
	no_tick.push = -1.0
	no_tick.immune_tags = [&""]
	equal("a tick with a clock, a pull and an immune tag are clean; a tick with no clock is a problem",
		[clean.problems("fixture").size(), no_clock.problems("fixture").size()], [0, 1])
	equal("a clock with no tick, a negative push and an empty immune tag are problems",
		no_tick.problems("fixture").size(), 3)


func _enter_and_exit() -> void:
	_use("burst")
	equal("as it rises its on_enter skill lands on its group and nobody else",
		[_hp(_foe) < 100, _hp(_far) < 100, _hp(_ally), _hp(_me), _mp(_foe)], [true, true, 100, 100, 0])
	_use("burst")
	equal("as it ends its on_exit skill lands on its group",
		[_mp(_foe), _mp(_far), _mp(_ally), _run("burst").standing()], [3, 3, 0, false])
	_reset()


func _walking() -> void:
	_use("halo")
	var first: Array[int] = [_mp(_ally), _mp(_foe), _mp(_far), _mp(_me)]
	_body(_ally).position = Vector3(9.0, 0.0, 0.0)
	_tick(0.1)
	var out: int = _mp(_ally)
	_body(_ally).position = Vector3(2.0, 0.0, 0.0)
	_tick(0.1)
	equal("walking into an aura lands its on_enter skill, walking out its on_exit",
		[first, out, _mp(_ally)], [[1, 1, 0, 0], 3, 4])
	_use("halo")
	_reset()


func _clock() -> void:
	_use("storm")
	_tick(0.4)
	var early: int = _mp(_ally)
	_tick(0.2)
	var one: int = _mp(_ally)
	_tick(1.0)
	equal("its tick lands each time its clock comes round, each one stronger than the last",
		[early, one, _mp(_ally), _mp(_me)], [0, 2, 9, 0])
	Vitals.of(_ally.get_parent()).set_to(&"hp", 0)
	var fallen: int = _mp(_ally)
	_tick(0.5)
	equal("the fallen are passed over, the standing are not", [_mp(_ally), _mp(_foe) > 0], [fallen, true])
	Vitals.of(_ally.get_parent()).revive(100)
	_use("storm")
	_reset()


func _movement() -> void:
	_use("vortex")
	_tick(0.5)
	var drawn: float = snappedf(_body(_foe).position.z, 0.01)
	var driven: float = snappedf(_body(_ally).position.x, 0.01)
	_tick(5.0)
	equal("pull draws a foe toward the caster and never past it, push drives an ally away, and the caster stays",
		[drawn, driven, snappedf(_body(_foe).position.z, 0.01), _body(_me).position], [-2.0, 2.5, 0.0, Vector3.ZERO])
	_use("vortex")
	_reset()


func _immunity() -> void:
	StatusSet.of(_far.get_parent()).apply(_tagged(WARD, &"fixture_touch_ward"))
	_use("guarded")
	equal("a fighter holding an immune tag is left out of that effect, the others are not",
		[_stacks(_far, BOUND), _stacks(_foe, BOUND), _hp(_far), _hp(_foe) < 100], [0, 1, 100, true])
	_use("guarded")
	StatusSet.of(_far.get_parent()).cure(WARD)
	_reset()
	var resist: StringName = &"resist_field_fixture_touch_guarded"
	_foe.sheet.add(StatModifier.of(resist, StatModifier.Op.ADD, 1.0, &"fixture_touch"))
	_use("guarded")
	var shut_out: Array[int] = [_stacks(_foe, BOUND), _hp(_foe), _stacks(_far, BOUND)]
	_foe.sheet.remove_from(&"fixture_touch")
	_tick(0.1)
	var let_in: int = _stacks(_foe, BOUND)
	_far.sheet.add(StatModifier.of(resist, StatModifier.Op.ADD, 1.0, &"fixture_touch"))
	_tick(0.1)
	equal("resist_field_<name> at 1 keeps a fighter out of the whole battlefield, and gaining it lets one out",
		[shut_out, let_in, _stacks(_far, BOUND)], [[0, 100, 1], 1, 0])
	_far.sheet.remove_from(&"fixture_touch")
	_use("guarded")


func _kit() -> PowerKit:
	var burst: BattlefieldMechanism = _field(BURST)
	var blast := BattlefieldEffect.new()
	blast.on_enter = _strike(&"fixture_touch_blast")
	blast.on_exit = _restore(&"fixture_touch_after", 3.0)
	burst.effects = [blast]
	var halo: BattlefieldMechanism = _field(HALO)
	halo.radius = 5.0
	var doors := BattlefieldEffect.new()
	doors.who = BattlefieldEffect.Who.EVERYONE_BUT_CASTER
	doors.on_enter = _restore(&"fixture_touch_in", 1.0)
	doors.on_exit = _restore(&"fixture_touch_out", 2.0)
	halo.effects = [doors]
	var storm: BattlefieldMechanism = _field(STORM)
	var rain := BattlefieldEffect.new()
	rain.who = BattlefieldEffect.Who.EVERYONE_BUT_CASTER
	rain.tick = _restore(&"fixture_touch_rain", 2.0)
	rain.tick_seconds = 0.5
	rain.tick_grows = 0.5
	storm.effects = [rain]
	var vortex: BattlefieldMechanism = _field(VORTEX)
	var pull := BattlefieldEffect.new()
	pull.pull = 2.0
	var push := BattlefieldEffect.new()
	push.who = BattlefieldEffect.Who.CASTER_SIDE
	push.push = 1.0
	vortex.effects = [pull, push]
	var guarded: BattlefieldMechanism = _field(GUARDED)
	var bind := BattlefieldEffect.new()
	bind.statuses = [_status(BOUND)]
	bind.on_enter = _strike(&"fixture_touch_bind")
	bind.immune_tags = [&"fixture_touch_ward"]
	guarded.effects = [bind]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_touch"
	kit.powers = [_power("burst", burst), _power("halo", halo), _power("storm", storm),
		_power("vortex", vortex), _power("guarded", guarded)]
	return kit


func _field(status_id: StringName) -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	field.status = _status(status_id)
	return field


# A sure hit for 5 power.
func _strike(id: StringName) -> Skill:
	var skill := Skill.new()
	skill.id = id
	skill.name_key = "fixture.skill"
	skill.power = 5.0
	skill.sure_hit = true
	return skill


# Gives `amount` mp: easy to count exactly.
func _restore(id: StringName, amount: float) -> Skill:
	var gift := SkillEffect.new()
	gift.kind = SkillEffect.Kind.RESTORE
	gift.amount = amount
	var skill := Skill.new()
	skill.id = id
	skill.name_key = "fixture.skill"
	skill.target = FactionTable.Target.ALLY
	skill.effects = [gift]
	return skill


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _tagged(id: StringName, tag: StringName) -> StatusEffect:
	var status: StatusEffect = _status(id)
	status.tags = [tag]
	return status


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_touch_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 10.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


# Every fighter back where it began, at full hp and no mp.
func _reset() -> void:
	var places: Array[Vector3] = [Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, -3.0),
		Vector3(0.0, 0.0, -20.0)]
	var fighters: Array[Combatant] = [_me, _ally, _foe, _far]
	for i: int in fighters.size():
		_body(fighters[i]).position = places[i]
		Vitals.of(fighters[i].get_parent()).set_to(&"hp", 100)
		Vitals.of(fighters[i].get_parent()).set_to(&"mp", 0)


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


func _run(short: String) -> BattlefieldRun:
	return PowerSet.of(_me.get_parent()).executor(_powers[short].power_id) as BattlefieldRun


func _tick(seconds: float) -> void:
	PowerSet.of(_me.get_parent()).tick_seconds(seconds)


func _body(fighter: Combatant) -> Node3D:
	return fighter.get_parent() as Node3D


func _stacks(fighter: Combatant, id: StringName) -> int:
	return StatusSet.of(fighter.get_parent()).stacks(id)


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _mp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"mp")
