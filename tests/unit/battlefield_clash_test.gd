extends TestCase
## Battlefields against each other, the clash side (C6.9d): a newcomer that overlaps a standing
## battlefield in the same layer and clock is judged by its `clash` rule and `refinement`; a
## different layer or a far caster never clashes; a stat can scale the refinement; and a `closed`
## battlefield holds the fighters inside at its edge, where an open one lets them walk out.
##
## OWNS: assertions about `BattlefieldClash`, the new battlefield fields, and `BattlefieldWall`
## as `BattlefieldRun` uses them.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const STRONG: StringName = &"status/fixture_clash_strong"
const WEAK: StringName = &"status/fixture_clash_weak"
const GUARD: StringName = &"status/fixture_clash_guard"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _rival: Combatant
var _ally: Combatant
var _kit_all: PowerKit
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(14)
	Flags.clear_all()
	_rng.seed = 7
	_kit_all = _kit()
	_problems()
	_clashes()
	_radius()
	_stat()
	_closed()
	_world.free()
	Flags.clear_all()


# A negative refinement is a problem; a clean battlefield with the same settings is not.
func _problems() -> void:
	var clean: BattlefieldMechanism = _field(STRONG, 2.0, BattlefieldMechanism.Clash.STRONGER_WINS)
	var bad: BattlefieldMechanism = _field(STRONG, -1.0, BattlefieldMechanism.Clash.STRONGER_WINS)
	equal("a negative refinement is one problem more than the same battlefield with none",
		bad.problems("fixture").size() - clean.problems("fixture").size(), 1)


# Two battlefields in the same layer, clock and reach, overlapping: the clash rule decides.
func _clashes() -> void:
	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "weak")
	equal("a weaker battlefield raised into a stronger one is shattered and the stronger stands",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "weak").standing()], [true, false])
	equal("the shattered battlefield's status is gone", StatusSet.of(_rival.get_parent()).stacks(WEAK), 0)

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "weak")
	_use(_rival, "strong")
	equal("a stronger newcomer ends the weaker standing battlefield, and stands",
		[_run_of(_me, "weak").standing(), _run_of(_rival, "strong").standing()], [false, true])

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "equal")
	equal("equal refinement ends both", [_run_of(_me, "strong").standing(),
		_run_of(_rival, "equal").standing()], [false, false])

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "over")
	equal("an overwriting newcomer ends the older one whatever its strength, and stands",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "over").standing()], [false, true])

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "both")
	equal("a both-end newcomer ends itself and the older one",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "both").standing()], [false, false])

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "stand")
	equal("a both-stand newcomer leaves the older one standing and stands itself",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "stand").standing()], [true, true])

	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "strong")
	_use(_rival, "terrain")
	equal("battlefields in different layers never clash",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "terrain").standing()], [true, true])


# A radius only clashes when the casters are close enough to overlap.
func _radius() -> void:
	_fresh(Vector3(0.0, 0.0, -3.0))
	_use(_me, "reach")
	_use(_rival, "reach_weak")
	equal("two radius-2 battlefields three metres apart do not overlap, so both stand",
		[_run_of(_me, "reach").standing(), _run_of(_rival, "reach_weak").standing()], [true, true])

	_fresh(Vector3(0.0, 0.0, -1.0))
	_use(_me, "reach")
	_use(_rival, "reach_weak")
	equal("the same two one metre apart overlap, so the weaker is shattered",
		[_run_of(_me, "reach").standing(), _run_of(_rival, "reach_weak").standing()], [true, false])


# A caster's stat scales its refinement: a weaker battlefield made stronger by a stat wins.
func _stat() -> void:
	_fresh(Vector3(0.0, 0.0, -3.0))
	_rival.sheet.set_base(&"fixture_clash_mind", 2.0)
	_use(_me, "strong")
	_use(_rival, "scaled")
	equal("a refinement scaled by a stat of 2 (1 times 3) beats a flat 2",
		[_run_of(_me, "strong").standing(), _run_of(_rival, "scaled").standing()], [false, true])


# A closed battlefield holds a fighter who walks out at its edge; an open one lets it go.
func _closed() -> void:
	_fresh(Vector3(0.0, 0.0, -8.0))
	_use(_me, "barrier")
	_body(_ally).position = Vector3(8.0, 0.0, 0.0)
	_tick(0.1)
	equal("a closed battlefield walks a fighter who tries to leave back to its edge, and keeps the status on it",
		[snappedf(_body(_ally).position.x, 0.01), StatusSet.of(_rival.get_parent()).stacks(GUARD),
		StatusSet.of(_ally.get_parent()).stacks(GUARD)], [3.0, 0, 1])

	_fresh(Vector3(0.0, 0.0, -8.0))
	_use(_me, "window")
	_body(_ally).position = Vector3(8.0, 0.0, 0.0)
	_tick(0.1)
	equal("an open battlefield does not hold a fighter who walks out, and takes its status off",
		[snappedf(_body(_ally).position.x, 0.01), StatusSet.of(_ally.get_parent()).stacks(GUARD)],
		[8.0, 0])


# --- fixtures -----------------------------------------------------------------------------------

# A fresh world: `_me` at the origin, `_rival` at `rival_at`, `_ally` two metres along x.
func _fresh(rival_at: Vector3) -> void:
	if _world != null:
		_world.free()
	_world = Node3D.new()
	attach(_world)
	_me = _fighter(&"fixture_clash_me", &"player", Vector3.ZERO, _kit_all)
	_rival = _fighter(&"fixture_clash_rival", &"enemy", rival_at, _kit_all)
	_ally = _fighter(&"fixture_clash_ally", &"player", Vector3(2.0, 0.0, 0.0), null)


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_clash"
	kit.powers = [
		_power("strong", _field(STRONG, 2.0, BattlefieldMechanism.Clash.STRONGER_WINS)),
		_power("weak", _field(WEAK, 1.0, BattlefieldMechanism.Clash.STRONGER_WINS)),
		_power("equal", _field(&"status/fixture_clash_equal", 2.0, BattlefieldMechanism.Clash.STRONGER_WINS)),
		_power("over", _field(&"status/fixture_clash_over", 1.0, BattlefieldMechanism.Clash.OVERWRITE)),
		_power("both", _field(&"status/fixture_clash_both", 0.0, BattlefieldMechanism.Clash.BOTH_END)),
		_power("stand", _field(&"status/fixture_clash_stand", 0.0, BattlefieldMechanism.Clash.BOTH_STAND)),
		_power("terrain", _terrain()),
		_power("reach", _reach(&"status/fixture_clash_reach", 2.0)),
		_power("reach_weak", _reach(&"status/fixture_clash_reach_weak", 1.0)),
		_power("scaled", _scaled()),
		_power("barrier", _barrier(true)),
		_power("window", _barrier(false)),
	]
	return kit


# A battlefield with the given status id, refinement and clash rule, in the domain layer.
func _field(id: StringName, refinement: float, clash: BattlefieldMechanism.Clash) -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	field.status = _status(id)
	field.effects = [BattlefieldEffect.new()]
	field.refinement = refinement
	field.clash = clash
	return field


func _terrain() -> BattlefieldMechanism:
	var field: BattlefieldMechanism = _field(&"status/fixture_clash_terrain", 0.0,
		BattlefieldMechanism.Clash.STRONGER_WINS)
	field.layer = BattlefieldMechanism.Layer.TERRAIN
	return field


# A radius-limited battlefield of the given refinement, in the domain layer.
func _reach(id: StringName, refinement: float) -> BattlefieldMechanism:
	var field: BattlefieldMechanism = _field(id, refinement, BattlefieldMechanism.Clash.STRONGER_WINS)
	field.radius = 2.0
	return field


# A battlefield whose refinement is scaled by the caster's `fixture_clash_mind` stat.
func _scaled() -> BattlefieldMechanism:
	var field: BattlefieldMechanism = _field(&"status/fixture_clash_scaled", 1.0,
		BattlefieldMechanism.Clash.STRONGER_WINS)
	field.refinement_stat = &"fixture_clash_mind"
	return field


# A radius-3 battlefield whose one effect holds GUARD on everyone inside; closed or open.
func _barrier(closed: bool) -> BattlefieldMechanism:
	var effect := BattlefieldEffect.new()
	effect.who = BattlefieldEffect.Who.EVERYONE
	effect.statuses = [_status(GUARD)]
	var field: BattlefieldMechanism = _field(&"status/fixture_clash_barrier" if closed else &"status/fixture_clash_window",
		0.0, BattlefieldMechanism.Clash.STRONGER_WINS)
	field.radius = 3.0
	field.closed = closed
	field.effects = [effect]
	return field


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_clash_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
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
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(who: Combatant, short: String) -> bool:
	return PowerUse.use(who, _powers[short], [], _rng, NOON)


func _run_of(who: Combatant, short: String) -> BattlefieldRun:
	return PowerSet.of(who.get_parent()).executor(_powers[short].power_id) as BattlefieldRun


func _tick(seconds: float) -> void:
	PowerSet.of(_me.get_parent()).tick_seconds(seconds)


func _body(fighter: Combatant) -> Node3D:
	return fighter.get_parent() as Node3D
