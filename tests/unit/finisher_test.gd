extends TestCase
## Finishers in the field (C6.8): the M2 shape and its problems; a strike with no charge lands at
## once on the aimed foe, or on every foe within reach; a charge fills over fight time, holding
## its charging status, and then lands; a stopped fight holds the charge; a second use while
## charging changes nothing; a hit breaks a fragile charge, and a strong enough hit any charge;
## the flourish stops the fight before the strike lands; the power grows with a pool, which is
## then emptied; and the kit coming off drops a charge. The battle reading is
## `finisher_battle_test`.
##
## OWNS: assertions about `FinisherMechanism`, `FinisherRun` and `Flourish` in the field.
## MUST NOT: name a game's kits, powers or characters, or wait for physics frames.

const NOON: float = 12.0
const CHARGING: StringName = &"status/fixture_finisher_charging"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _foe: Combatant
var _second: Combatant
var _far: Combatant
var _ally: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(14)
	Flags.clear_all()
	_rng.seed = 3
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_finisher_me", &"player", Vector3.ZERO, _kit())
	_foe = _fighter(&"fixture_finisher_foe", &"enemy", Vector3(0.0, 0.0, -3.0), null)
	_second = _fighter(&"fixture_finisher_second", &"enemy", Vector3(0.0, 0.0, -5.0), null)
	_far = _fighter(&"fixture_finisher_far", &"enemy", Vector3(0.0, 0.0, -20.0), null)
	_ally = _fighter(&"fixture_finisher_ally", &"player", Vector3(0.0, 0.0, -2.0), null)
	_at_once()
	_charge()
	_breaks()
	_flourish()
	_pool_and_end()
	_world.free()
	CombatClock.reset()
	Flags.clear_all()


func _shapes() -> void:
	var finisher: FinisherMechanism = _finisher(0.0)
	equal("a finisher's kind is finisher, the base runs it, it aims at foes, and a clean one has no problems",
		[finisher.kind(), PowerMechanisms.make(finisher) is FinisherRun, finisher.aims_at_foes(),
			finisher.problems("fixture").size()],
		[&"finisher", true, true, 0])
	finisher.strike = null
	finisher.flourish = -1.0
	finisher.all_foes = true
	finisher.reach = 0.0
	finisher.break_damage = 5
	equal("no strike, a negative flourish, every foe within no reach and a break with no charge are problems",
		finisher.problems("fixture").size(), 4)


func _at_once() -> void:
	_use("quick")
	equal("with no charge the strike lands at once on the aimed foe alone",
		[_hp(_foe) < 100, _hp(_second), _hp(_ally)], [true, 100, 100])
	_heal()
	_use("wide")
	equal("striking every foe lands on each foe within reach, not on one too far or on an ally",
		[_hp(_foe) < 100, _hp(_second) < 100, _hp(_far), _hp(_ally)], [true, true, 100, 100])
	_heal()


func _charge() -> void:
	_use("quick")
	var once: int = 100 - _hp(_foe)
	_heal()
	_use("charged")
	_use("charged")
	var held: int = _stacks()
	_tick(0.5)
	var halfway: int = _hp(_foe)
	CombatClock.set_scale(0.0)
	_powers_of()._physics_process(5.0)
	CombatClock.reset()
	equal("a charge holds its status and strikes nobody yet, and a stopped fight holds it",
		[held, halfway, _run("charged").charging()], [1, 100, true])
	_tick(0.6)
	equal("when the charge is full it lands once, however often it was used, and the status comes off",
		[100 - _hp(_foe), _stacks(), _run("charged").charging()], [once, 0, false])
	_heal()


func _breaks() -> void:
	_use("fragile")
	_foe.hit(_me, 3.0, &"", _rng)
	_tick(2.0)
	equal("a hit that hurts breaks a fragile charge, and nothing lands", [_stacks(), _hp(_foe)], [0, 100])
	_heal()
	_use("sturdy")
	Events.combatant_damaged.emit(_me.combatant_id, _foe.combatant_id, 10, false)
	var kept: bool = _run("sturdy").charging()
	Events.combatant_damaged.emit(_me.combatant_id, _foe.combatant_id, 40, false)
	_tick(2.0)
	equal("a sturdy charge shrugs off a small hit and breaks on a strong one",
		[kept, _run("sturdy").charging(), _stacks(), _hp(_foe)], [true, false, 0, 100])
	_heal()


func _flourish() -> void:
	_use("finale")
	_tick(0.6)
	var moment: Flourish = _moment()
	equal("when the charge is full the fight stands still, the strike held back",
		[moment != null, CombatClock.scale, _hp(_foe)], [true, 0.0, 100])
	moment.wait(0.5)
	var still: float = CombatClock.scale
	moment.wait(0.6)
	equal("after the flourish the fight runs again and the strike lands",
		[still, CombatClock.scale, moment.over(), _hp(_foe) < 100], [0.0, 1.0, true, true])
	_heal()
	CombatClock.set_scale(0.5)
	var early := Flourish.new()
	early.seconds = 9.0
	_world.add_child(early)
	var stopped: float = CombatClock.scale
	early.free()
	equal("a flourish freed early gives the fight back the speed it had", [stopped, CombatClock.scale], [0.0, 0.5])
	CombatClock.reset()


func _pool_and_end() -> void:
	_use("gauged")
	var full: int = 100 - _hp(_foe)
	var gauge: int = Vitals.of(_me.get_parent()).current(&"fixture_gauge")
	_heal()
	_use("gauged")
	equal("a fuller pool makes a harder strike, and the strike empties it",
		[full > 100 - _hp(_foe), gauge], [true, 0])
	_heal()
	_use("charged")
	var powers: PowerSet = _powers_of()
	var kit: PowerKit = powers.kit
	powers.unequip()
	equal("the kit coming off drops a charge and its status", _stacks(), 0)
	powers.equip(kit)
	_tick(2.0)
	equal("and nothing lands later", _hp(_foe), 100)


func _kit() -> PowerKit:
	var wide: FinisherMechanism = _finisher(0.0)
	wide.all_foes = true
	wide.reach = 8.0
	var charged: FinisherMechanism = _finisher(1.0)
	charged.charging = _charging(false)
	var fragile: FinisherMechanism = _finisher(1.0)
	fragile.charging = _charging(true)
	var sturdy: FinisherMechanism = _finisher(1.0)
	sturdy.charging = _charging(false)
	sturdy.break_damage = 30
	var finale: FinisherMechanism = _finisher(0.5)
	finale.flourish = 1.0
	var gauged: FinisherMechanism = _finisher(0.0)
	gauged.drain_pool = &"fixture_gauge"
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_finisher"
	kit.powers = [_power("quick", _finisher(0.0)), _power("wide", wide), _power("charged", charged),
		_power("fragile", fragile), _power("sturdy", sturdy), _power("finale", finale), _power("gauged", gauged)]
	var rule := PowerScaling.new()
	rule.source = PowerScaling.Source.POOL_FRACTION
	rule.affects = PowerScaling.Affects.POWER
	rule.pool = &"fixture_gauge"
	rule.factor = 2.0
	_powers["gauged"].scaling = [rule]
	return kit


func _finisher(charge: float) -> FinisherMechanism:
	var finisher := FinisherMechanism.new()
	finisher.charge_time = charge
	finisher.strike = ActionMove.new()
	finisher.strike.startup = 0.0
	finisher.strike.active = 0.1
	finisher.strike.recovery = 0.0
	finisher.strike.power = 6.0
	finisher.strike.hitbox_size = Vector3(0.5, 0.5, 0.5)
	return finisher


func _charging(fragile: bool) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = CHARGING
	status.name_key = "fixture.status"
	status.breaks_on_hit = fragile
	return status


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_finisher_" + short)
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
	fighter.base_stats = {&"max_hp": 100.0, &"max_fixture_gauge": 100.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


func _tick(seconds: float) -> void:
	_powers_of().tick_seconds(seconds)


func _powers_of() -> PowerSet:
	return PowerSet.of(_me.get_parent())


func _run(short: String) -> FinisherRun:
	return _powers_of().executor(_powers[short].power_id) as FinisherRun


func _moment() -> Flourish:
	for node: Node in _world.get_children():
		if node is Flourish and not node.is_queued_for_deletion():
			return node as Flourish
	return null


func _stacks() -> int:
	return StatusSet.of(_me.get_parent()).stacks(CHARGING)


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


# Every fighter back to full hp.
func _heal() -> void:
	for fighter: Combatant in [_me, _foe, _second, _far, _ally]:
		Vitals.of(fighter.get_parent()).set_to(&"hp", 100)
