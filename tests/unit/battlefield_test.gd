extends TestCase
## Battlefields in the field (C6.9a): the M4 shape and its problems; raising one puts each
## effect's modifiers and statuses on its group (the caster's side, the other side, everyone but
## the caster) and ending it, however it ends, takes them off; a radius that follows the caster;
## a time limit and its aftermath; the upkeep; the caster falling; the kit coming off; fighters
## that arrive or are freed while it stands; and the `damage_dealt` stat. The battle reading is
## `battlefield_battle_test`.
##
## OWNS: assertions about `BattlefieldMechanism`, `BattlefieldEffect` and `BattlefieldRun` in the
## field, and about `damage_dealt` in `VulnerabilityStage`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const DOMAIN: StringName = &"status/fixture_field_domain"
const BOUND: StringName = &"status/fixture_field_bound"
const AURA: StringName = &"status/fixture_field_aura"
const BURNOUT: StringName = &"status/fixture_field_burnout"
const UPKEEP: StringName = &"status/fixture_field_upkeep"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _ally: Combatant
var _foe: Combatant
var _far: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(15)
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_field_me", &"player", Vector3.ZERO, _kit())
	_ally = _fighter(&"fixture_field_ally", &"player", Vector3(2.0, 0.0, 0.0), null)
	_foe = _fighter(&"fixture_field_foe", &"enemy", Vector3(0.0, 0.0, -3.0), null)
	_far = _fighter(&"fixture_field_far", &"enemy", Vector3(0.0, 0.0, -20.0), null)
	_groups()
	_endings()
	_arrivals()
	_reach()
	_time_and_upkeep()
	_damage_dealt()
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var field: BattlefieldMechanism = _field(DOMAIN)
	field.effects = [_effect(BattlefieldEffect.Who.OTHER_SIDE, &"", BOUND)]
	equal("a battlefield's kind is battlefield, the base runs it, a clean one has no problems, and its effect's status is the kit's",
		[field.kind(), PowerMechanisms.make(field) is BattlefieldRun, field.problems("fixture").size(),
			field.statuses().size()], [&"battlefield", true, 0, 2])
	var bad: BattlefieldMechanism = _field(DOMAIN)
	bad.effects = [BattlefieldEffect.new(), null]
	var stage := FormMechanism.new()
	stage.status = _status(BOUND)
	bad.cycle = [stage]
	bad.radius = -1.0
	equal("an effect that changes nothing, an empty effect, a cycle and a negative radius are problems",
		bad.problems("fixture").size(), 4)
	bad.effects = []
	bad.cycle = []
	bad.radius = 0.0
	equal("a battlefield with no effects is a problem", bad.problems("fixture").size(), 1)


func _groups() -> void:
	_use("domain")
	equal("raising it: the caster holds its status, and the caster's side has the modifier",
		[_run("domain").standing(), _stacks(_me, DOMAIN), _attack(_me), _attack(_ally)], [true, 1, 9.0, 9.0])
	equal("the other side holds its status, near or far, and nobody else does",
		[_stacks(_foe, BOUND), _stacks(_far, BOUND), _stacks(_ally, BOUND), _stacks(_me, BOUND), _attack(_foe)],
		[1, 1, 0, 0, 6.0])
	equal("everyone but the caster has the third effect's modifier",
		[_defence(_me), _defence(_ally), _defence(_foe), _defence(_far)], [1.0, 0.0, 0.0, 0.0])
	_use("domain")
	equal("using it again ends it, and everything it put on comes off",
		[_run("domain").standing(), _attack(_me), _attack(_ally), _stacks(_foe, BOUND), _defence(_me)],
		[false, 6.0, 6.0, 0, 0.0])


func _endings() -> void:
	_use("domain")
	StatusSet.of(_me.get_parent()).cure(DOMAIN)
	equal("its status cured from outside ends it at once, with no tick",
		[_run("domain").standing(), _stacks(_foe, BOUND), _attack(_ally)], [false, 0, 6.0])
	_use("domain")
	StatusSet.of(_me.get_parent()).cure(BURNOUT)
	Vitals.of(_me.get_parent()).set_to(&"hp", 0)
	equal("the caster falling ends it, with no aftermath",
		[_run("domain").standing(), _stacks(_foe, BOUND), _stacks(_me, BURNOUT)], [false, 0, 0])
	Vitals.of(_me.get_parent()).set_to(&"hp", 100)
	_use("domain")
	var powers: PowerSet = PowerSet.of(_me.get_parent())
	var kit: PowerKit = powers.kit
	powers.unequip()
	equal("the kit coming off ends it", [_stacks(_foe, BOUND), _attack(_ally), _stacks(_me, DOMAIN)],
		[0, 6.0, 0])
	powers.equip(kit)


func _arrivals() -> void:
	_use("domain")
	var late: Combatant = _fighter(&"fixture_field_late", &"enemy", Vector3(1.0, 0.0, -1.0), null)
	var before: int = _stacks(late, BOUND)
	_tick(0.1)
	var after: int = _stacks(late, BOUND)
	late.get_parent().free()
	_tick(0.1)
	equal("a fighter that arrives is let in on the next tick, and one freed is let go quietly",
		[before, after, _run("domain").standing(), _stacks(_foe, BOUND)], [0, 1, true, 1])
	_use("domain")


func _reach() -> void:
	_use("aura")
	var first: Array[float] = [_defence(_foe), _defence(_far), _defence(_ally)]
	_body(_foe).position = Vector3(0.0, 0.0, -10.0)
	_tick(0.1)
	var walked_out: float = _defence(_foe)
	_body(_me).position = Vector3(0.0, 0.0, -18.0)
	_tick(0.1)
	equal("an aura covers the fighters within its radius, lets go of one that walks out, and follows its caster",
		[first, walked_out, _defence(_far), _defence(_foe)], [[-1.0, 0.0, -1.0], 0.0, -1.0, 0.0])
	_body(_me).position = Vector3.ZERO
	_body(_foe).position = Vector3(0.0, 0.0, -3.0)
	_tick(0.1)


func _time_and_upkeep() -> void:
	StatusSet.of(_me.get_parent()).cure(BURNOUT)
	_tick(1.0)
	var standing: bool = _run("aura").standing()
	_tick(2.0)
	equal("an aura of three seconds ends by its own rules, and its aftermath goes on",
		[standing, _run("aura").standing(), _stacks(_me, AURA), _stacks(_me, BURNOUT), _defence(_ally)],
		[true, false, 0, 1, 0.0])
	var vitals: Vitals = Vitals.of(_me.get_parent())
	vitals.set_to(&"mp", 2)
	_use("upkeep")
	_tick(1.0)
	var paying: Array = [_run("upkeep").standing(), vitals.current(&"mp")]
	_tick(1.0)
	equal("the upkeep drains its pool by the second, and at empty the battlefield falls",
		[paying, _run("upkeep").standing(), _stacks(_foe, BOUND)], [[true, 1], false, 0])


func _damage_dealt() -> void:
	var from := StatSheet.new()
	from.add(StatModifier.of(&"damage_dealt", StatModifier.Op.ADD, 0.5, &"fixture"))
	var result := DamageResult.new()
	result.amount = 10.0
	VulnerabilityStage.new().apply(DamageRequest.of(from, StatSheet.new(), 10.0), result, _rng)
	equal("damage_dealt on the attacker makes its hits land harder", result.amount, 15.0)


func _kit() -> PowerKit:
	var domain: BattlefieldMechanism = _field(DOMAIN)
	domain.aftermath = _status(BURNOUT)
	domain.effects = [_effect(BattlefieldEffect.Who.CASTER_SIDE, &"attack", &""),
		_effect(BattlefieldEffect.Who.OTHER_SIDE, &"", BOUND),
		_effect(BattlefieldEffect.Who.CASTER, &"defence", &"")]
	var aura: BattlefieldMechanism = _field(AURA)
	aura.radius = 5.0
	aura.seconds = 3.0
	aura.aftermath = _status(BURNOUT)
	var lowering: BattlefieldEffect = _effect(BattlefieldEffect.Who.EVERYONE_BUT_CASTER, &"defence", &"")
	lowering.modifiers[0].value = -1.0
	aura.effects = [lowering]
	var upkeep: BattlefieldMechanism = _field(UPKEEP)
	upkeep.drain_pool = &"mp"
	upkeep.drain_per_second = 1.0
	upkeep.effects = [_effect(BattlefieldEffect.Who.OTHER_SIDE, &"", BOUND)]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_field"
	kit.powers = [_power("domain", domain), _power("aura", aura), _power("upkeep", upkeep)]
	return kit


func _field(status_id: StringName) -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	field.status = _status(status_id)
	return field


func _effect(who: BattlefieldEffect.Who, stat: StringName, status_id: StringName) -> BattlefieldEffect:
	var effect := BattlefieldEffect.new()
	effect.who = who
	if stat != &"":
		effect.modifiers = [StatModifier.of(stat, StatModifier.Op.ADD, 3.0 if stat == &"attack" else 1.0, &"")]
	if status_id != &"":
		effect.statuses = [_status(status_id)]
	return effect


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_field_" + short)
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
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 10.0, &"attack": 6.0, &"defence": 0.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


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


func _attack(fighter: Combatant) -> float:
	return fighter.sheet.value(&"attack")


func _defence(fighter: Combatant) -> float:
	return fighter.sheet.value(&"defence")
