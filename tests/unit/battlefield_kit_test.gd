extends TestCase
## A battlefield that lends its caster a kit (C6.9e): the kit goes on when the field rises, is held
## while it stands, and comes off when it ends however it ends. A battlefield that loses a clash
## never puts its kit on.
##
## OWNS: assertions about `BattlefieldMechanism.caster_kit`, and `PowerSet.hold_kit` and
## `release_kit` as `BattlefieldRun` uses them.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const STRONG: StringName = &"status/fixture_kit_strong"
const WEAK: StringName = &"status/fixture_kit_weak"
const BONUS: StringName = &"fixture_kit_bonus"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _rival: Combatant
var _lent: PowerKit
var _lent_power: Power
var _field_power: Power
var _weak_power: Power


func run() -> void:
	plan(7)
	Flags.clear_all()
	_rng.seed = 7
	_problems()
	_holds()
	_ends()
	_clash()
	if _world != null:
		_world.free()
	Flags.clear_all()


# A caster kit with no kit id is one problem more than the same kit with one.
func _problems() -> void:
	var clean := BattlefieldMechanism.new()
	clean.effects = [BattlefieldEffect.new()]
	clean.caster_kit = _named_kit(&"kit/fixture_kit_named")
	var bad := BattlefieldMechanism.new()
	bad.effects = [BattlefieldEffect.new()]
	bad.caster_kit = _named_kit(&"")
	equal("a caster kit with no kit id is one problem more than a named one",
		bad.problems("fixture").size() - clean.problems("fixture").size(), 1)


# Raised, the caster holds the kit's power and its stat bonus, and a tick keeps them.
func _holds() -> void:
	_fresh()
	PowerUse.use(_me, _field_power, [], _rng, NOON)
	equal("a raised battlefield puts its caster kit's power on the caster",
		PowerSet.of(_me.get_parent()).has(_lent_power), true)
	equal("the caster kit's stat bonus is on while the battlefield stands", _me.sheet.value(BONUS), 3.0)
	PowerSet.of(_me.get_parent()).tick_seconds(0.1)
	equal("the caster kit is still held after a tick",
		PowerSet.of(_me.get_parent()).has(_lent_power), true)


# Taking the battlefield's own kit off ends the field, and the caster kit comes off with it.
func _ends() -> void:
	_fresh()
	PowerUse.use(_me, _field_power, [], _rng, NOON)
	PowerSet.of(_me.get_parent()).unequip()
	equal("ending the battlefield takes the caster kit's power off",
		PowerSet.of(_me.get_parent()).has(_lent_power), false)
	equal("ending the battlefield takes the caster kit's stat bonus off", _me.sheet.value(BONUS), 0.0)


# A battlefield that loses a clash is never raised, so its caster never gets the kit.
func _clash() -> void:
	_fresh()
	PowerUse.use(_me, _field_power, [], _rng, NOON)
	PowerUse.use(_rival, _weak_power, [], _rng, NOON)
	equal("a battlefield that loses a clash never puts its caster kit on",
		PowerSet.of(_rival.get_parent()).has(_lent_power), false)


# --- fixtures -----------------------------------------------------------------------------------

# A fresh world: `_me` at the origin with the strong battlefield, `_rival` three metres off with the
# weak one. Both battlefields lend the same caster kit.
func _fresh() -> void:
	if _world != null:
		_world.free()
	_world = Node3D.new()
	attach(_world)
	_lent = _kit(&"kit/fixture_kit_lent", [_lent_power_of()], [_bonus()])
	_field_power = _power("fixture_kit_field", _field(STRONG, 2.0))
	_weak_power = _power("fixture_kit_weak", _field(WEAK, 1.0))
	_me = _fighter(&"fixture_kit_me", &"player", Vector3.ZERO, _kit(&"kit/fixture_kit_me", [_field_power], []))
	_rival = _fighter(&"fixture_kit_rival", &"enemy", Vector3(0.0, 0.0, -3.0),
		_kit(&"kit/fixture_kit_rival", [_weak_power], []))


func _lent_power_of() -> Power:
	_lent_power = Power.new()
	_lent_power.power_id = &"power/fixture_kit_lent"
	_lent_power.name_key = "fixture.power"
	return _lent_power


func _bonus() -> StatModifier:
	return StatModifier.of(BONUS, StatModifier.Op.ADD, 3.0, &"fixture_kit_lent")


# A battlefield of the given status and refinement, lending `_lent` to its caster while it stands.
func _field(id: StringName, refinement: float) -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	field.status = _status(id)
	field.effects = [BattlefieldEffect.new()]
	field.refinement = refinement
	field.caster_kit = _lent
	return field


func _named_kit(kit_id: StringName) -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = kit_id
	kit.name_key = "fixture.kit"
	return kit


func _kit(kit_id: StringName, powers: Array[Power], bonuses: Array[StatModifier]) -> PowerKit:
	var kit := _named_kit(kit_id)
	kit.powers = powers
	kit.stat_bonuses = bonuses
	return kit


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = 0.0
	return status


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
	PowerSet.of(actor).equip(kit)
	return fighter
