extends TestCase
## The timed block (C6.6b): a barrier whose press is the timing. A hit just after the guard goes
## up is stopped whole, free, and stored; a later one is a paid, reduced block; in a battle a
## block is perfect until the guard's own next turn; and a hit stopped whole is announced as
## blocked, never as 0 damage.
##
## OWNS: assertions about `BarrierMechanism.Mode.TIMED_BLOCK`, `TimedWindow.inside`,
## `BarrierRun`'s timing and `Events.attack_blocked`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const FOE: StringName = &"fixture_tblock_foe"

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _timed: Power
var _wall: Power
var _me: Combatant
var _blocked: Array[StringName] = []
var _damaged: int = 0


func run() -> void:
	plan(8)
	Flags.clear_all()
	_rng.seed = 12
	_me = _fighter(&"fixture_tblock_guard", &"player", _kit())
	_fighter(FOE, &"enemy", null)
	_shapes()
	_in_the_field()
	_in_a_battle()
	_announced()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _shapes() -> void:
	var timed := BarrierMechanism.new()
	timed.mode = BarrierMechanism.Mode.TIMED_BLOCK
	equal("a timed block with no timing and no status is two problems", timed.problems("fixture").size(), 2)
	var window: TimedWindow = (_timed.mechanism as BarrierMechanism).timing
	equal("a window holds its two edges and nothing outside them",
		[window.inside(0.0), window.inside(0.2), window.inside(0.21), window.inside(-0.1)],
		[true, true, false, false])


func _in_the_field() -> void:
	var powers: PowerSet = PowerSet.of(_me.get_parent())
	_use(_timed)
	powers.tick_seconds(0.1)
	var hit: DamageResult = _result(10.0)
	equal("a hit just after the guard goes up is stopped whole, free, and stored",
		[_me.receive(hit, FOE), hit.blocked, _pool(&"mp"), _pool(&"charge")], [0, true, 20, 10])
	powers.tick_seconds(0.3)
	hit = _result(10.0)
	equal("a later hit is a late block: it pays, and its share lands",
		[_me.receive(hit, FOE), hit.blocked, _pool(&"mp"), _pool(&"charge")], [-3, false, 15, 10])
	_use(_timed)
	_use(_timed)
	equal("raising the guard again starts the timing again",
		[_me.receive(_result(10.0), FOE), _pool(&"charge")], [0, 20])
	_use(_timed)


# A battle has no seconds: the block is perfect until the guard's own next turn.
func _in_a_battle() -> void:
	_me.real_time = false
	_use(_timed)
	var first: int = _me.receive(_result(10.0), FOE)
	PowerSet.of(_me.get_parent()).tick_turn()
	equal("in a battle, a block is perfect until the guard's next turn, and late after it",
		[first, _me.receive(_result(10.0), FOE)], [0, -3])
	_use(_timed)
	_me.real_time = true


func _announced() -> void:
	Events.attack_blocked.connect(_on_blocked)
	Events.combatant_damaged.connect(_on_damaged)
	_use(_wall)
	_me.receive(_result(10.0), FOE)
	equal("a hit stopped whole is announced as blocked, not as damage",
		[_blocked, _damaged], [[_me.combatant_id], 0])
	_use(_wall)
	_me.receive(_result(10.0), FOE)
	equal("a hit that lands is announced as damage", [_blocked.size(), _damaged], [1, 1])
	Events.attack_blocked.disconnect(_on_blocked)
	Events.combatant_damaged.disconnect(_on_damaged)


func _on_blocked(who: StringName, _by: StringName) -> void:
	_blocked.append(who)


func _on_damaged(_who: StringName, _by: StringName, _amount: int, _critical: bool) -> void:
	_damaged += 1


# A made-up hit of `amount`, with the guard back at hp 50.
func _result(amount: float) -> DamageResult:
	Vitals.of(_me.get_parent()).set_to(&"hp", 50)
	var hit := DamageResult.new()
	hit.amount = amount
	return hit


func _pool(pool: StringName) -> int:
	return Vitals.of(_me.get_parent()).current(pool)


func _use(power: Power) -> bool:
	return PowerUse.use(_me, power, [], _rng, NOON)


func _kit() -> PowerKit:
	var timed := BarrierMechanism.new()
	timed.status = _status(&"status/fixture_tblock_timed")
	timed.mode = BarrierMechanism.Mode.TIMED_BLOCK
	timed.timing = TimedWindow.new()
	timed.timing.opens = 0.0
	timed.timing.closes = 0.2
	timed.factor = 0.3
	timed.cost_pool = &"mp"
	timed.cost_per_block = 5
	timed.store_pool = &"charge"
	var wall := BarrierMechanism.new()
	wall.status = _status(&"status/fixture_tblock_wall")
	_timed = _power("timed", timed)
	_wall = _power("wall", wall)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_tblock"
	kit.name_key = "fixture.kit"
	kit.powers = [_timed, _wall]
	return kit


func _power(short: String, mechanism: BarrierMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_tblock_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _fighter(id: StringName, faction: StringName, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 20.0, &"max_charge": 100.0, &"start_charge": 0.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	attach(actor)
	_actors.append(actor)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
