extends TestCase
## Barriers (C6.6a): a barrier is a form that guards. While it is up, a hit about to land is
## nullified or reduced; a bypass tag gets through; an absorbed element is drunk into a pool; a
## cost is paid per block, and the barrier comes down when it cannot be; an ALLIES barrier guards
## allies on the same clock; and a barrier with no status is always up.
##
## OWNS: assertions about `BarrierMechanism`, `BarrierRun`, `PowerSet.guard` and the guard hook
## in `Combatant.receive`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const WALL: StringName = &"status/fixture_barrier_wall"
const PAID: StringName = &"status/fixture_barrier_paid"
const FOE: StringName = &"fixture_barrier_foe"

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _powers: Dictionary[String, Power] = {}
var _me: Combatant
var _ally: Combatant
var _foe: Combatant


func run() -> void:
	plan(21)
	Flags.clear_all()
	_rng.seed = 11
	_me = _fighter(&"fixture_barrier_guard", &"player", _kit())
	_ally = _fighter(&"fixture_barrier_ally", &"player", null)
	_foe = _fighter(FOE, &"enemy", null)
	_shapes()
	_stopping()
	_paying()
	_absorbing()
	_covering()
	_always_up()
	_weakness()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _shapes() -> void:
	var barrier := BarrierMechanism.new()
	equal("a barrier's kind is barrier, the base runs it, and one with no status is no problem",
		[barrier.kind(), PowerMechanisms.make(barrier) is BarrierRun, barrier.problems("fixture").size()],
		[&"barrier", true, 0])
	barrier.factor = 1.5
	barrier.cost_per_block = 2
	barrier.absorb_elements = [&"fire"]
	equal("a share outside 0 to 1, a cost from no pool, and absorbing into no pool are problems",
		barrier.problems("fixture").size(), 3)
	barrier.cost_per_block = -1
	equal("a negative cost per block is a problem", barrier.problems("fixture").size(), 3)


func _stopping() -> void:
	equal("with the barrier down, a hit lands whole", _strike(_me, 10.0), -10)
	_use("wall")
	var hit: DamageResult = _result(10.0)
	equal("with it up, a hit takes nothing and is marked blocked",
		[_me.receive(hit, FOE), hit.blocked, _stacks(WALL)], [0, true, 1])
	equal("a heal is never stopped", _strike(_me, -5.0), 5)
	_pool(_me, &"mp", 3)
	PowerSet.of(_me.get_parent()).tick_seconds(2.0)
	equal("its upkeep empties the pool, and then it is down",
		[Vitals.of(_me.get_parent()).current(&"mp"), _stacks(WALL), _strike(_me, 10.0)], [0, 0, -10])
	_pool(_me, &"mp", 20)
	_use("soft")
	hit = _result(10.0)
	equal("a reducing barrier leaves its share, and the hit still counts as landed",
		[_me.receive(hit, FOE), hit.blocked], [-4, false])
	_use("stance")
	equal("entering another form of its group brings the barrier down", _strike(_me, 10.0), -10)


func _paying() -> void:
	_pool(_me, &"mp", 7)
	_use("paid")
	equal("each block is paid for", [_strike(_me, 10.0), _strike(_me, 10.0), _mp()], [0, 0, 1])
	equal("a hit with a bypass tag goes through, and costs nothing",
		[_strike(_me, 10.0, &"", [&"domain"]), _mp()], [-10, 1])
	var sure: DamageResult = _foe.hit(_ally, 5.0, &"", _rng, true, [&"blade"])
	equal("a hit carries its skill's tags, and sure_hit when it cannot miss",
		sure.tags, [&"blade", &"sure_hit"])
	equal("a block it cannot pay for brings the barrier down, and the hit lands whole",
		[_strike(_me, 10.0), _stacks(PAID), _mp()], [-10, 0, 1])


func _absorbing() -> void:
	_pool(_me, &"charge", 0)
	_use("drink")
	equal("an absorbed element takes nothing and is stored in the pool",
		[_strike(_me, 10.0, &"fire"), Vitals.of(_me.get_parent()).current(&"charge")], [0, 10])
	equal("any other element lands whole through a barrier that only absorbs",
		_strike(_me, 10.0, &"ice"), -10)


func _covering() -> void:
	equal("a barrier for itself does not guard an ally", _strike(_ally, 10.0), -10)
	_use("cover")
	equal("a barrier for allies guards an ally, and never a foe",
		[_strike(_ally, 10.0), _strike(_me, 10.0), _strike(_foe, 10.0)], [-5, -5, -10])
	_ally.real_time = false
	equal("it does not guard an ally living on another clock", _strike(_ally, 10.0), -10)
	_ally.real_time = true
	Vitals.of(_me.get_parent()).set_to(&"hp", 0)
	equal("a fallen guard guards nobody", _strike(_ally, 10.0), -10)
	Vitals.of(_me.get_parent()).revive(50)


func _always_up() -> void:
	var heat := BarrierMechanism.new()
	heat.mode = BarrierMechanism.Mode.REDUCE
	heat.factor = 1.0
	heat.absorb_elements = [&"fire"]
	heat.store_pool = &"hp"
	var passive: Power = _power("heat", heat)
	passive.passive = true
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_barrier_heat"
	kit.name_key = "fixture.kit"
	kit.powers = [passive]
	var sun: Combatant = _fighter(&"fixture_barrier_sun", &"enemy", kit)
	var fire: DamageResult = _result(10.0)
	fire.element = &"fire"
	_pool(sun, &"hp", 50)
	equal("a barrier with no status is always up: the absorbed element heals",
		[sun.receive(fire, FOE), Vitals.of(sun.get_parent()).current(&"hp")], [0, 60])


# A fire skill on a fighter weak to fire: stopped whole, it chips no shield; landed, it does.
func _weakness() -> void:
	_me.weak_to = [&"fire"]
	var flame := Skill.new()
	flame.id = &"skill/fixture_barrier_flame"
	flame.name_key = "fixture.skill"
	flame.power = 4.0
	flame.element = &"fire"
	flame.sure_hit = true
	var shield: Vitals = Vitals.of(_me.get_parent())
	_pool(_me, &"shield", 2)
	_use("wall")
	SkillUse.apply(_foe, flame, [_me], _rng)
	var guarded: int = shield.current(&"shield")
	_use("wall")
	SkillUse.apply(_foe, flame, [_me], _rng)
	equal("a hit stopped whole finds no weakness; one that lands does",
		[guarded, shield.current(&"shield")], [2, 1])


# Lands a made-up hit of `amount` on `target`, from hp 50. Returns the hp change.
func _strike(target: Combatant, amount: float, element: StringName = &"",
		tags: Array[StringName] = []) -> int:
	var hit: DamageResult = _result(amount)
	hit.element = element
	hit.tags = tags
	return target.receive(hit, FOE)


func _result(amount: float) -> DamageResult:
	for fighter: Combatant in [_me, _ally, _foe]:
		_pool(fighter, &"hp", 50)
	var hit := DamageResult.new()
	hit.amount = amount
	return hit


func _pool(fighter: Combatant, pool: StringName, value: int) -> void:
	Vitals.of(fighter.get_parent()).set_to(pool, value)


func _mp() -> int:
	return Vitals.of(_me.get_parent()).current(&"mp")


func _stacks(id: StringName) -> int:
	return StatusSet.of(_me.get_parent()).stacks(id)


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


func _kit() -> PowerKit:
	var wall: BarrierMechanism = _barrier(WALL, BarrierMechanism.Mode.NULLIFY)
	wall.drain_pool = &"mp"
	wall.drain_per_second = 2.0
	var soft: BarrierMechanism = _barrier(&"status/fixture_barrier_soft", BarrierMechanism.Mode.REDUCE)
	soft.factor = 0.4
	var paid: BarrierMechanism = _barrier(PAID, BarrierMechanism.Mode.NULLIFY)
	paid.cost_pool = &"mp"
	paid.cost_per_block = 3
	paid.bypass_tags = [&"domain"]
	var drink: BarrierMechanism = _barrier(&"status/fixture_barrier_drink", BarrierMechanism.Mode.REDUCE)
	drink.factor = 1.0
	drink.absorb_elements = [&"fire"]
	drink.store_pool = &"charge"
	var cover: BarrierMechanism = _barrier(&"status/fixture_barrier_cover", BarrierMechanism.Mode.REDUCE)
	cover.scope = BarrierMechanism.Scope.ALLIES
	var stance := FormMechanism.new()
	stance.status = _status(&"status/fixture_barrier_stance")
	stance.exclusive_group = &"guard"
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_barrier"
	kit.name_key = "fixture.kit"
	kit.powers = [_power("wall", wall), _power("soft", soft), _power("paid", paid),
		_power("drink", drink), _power("cover", cover), _power("stance", stance)]
	return kit


func _barrier(id: StringName, mode: BarrierMechanism.Mode) -> BarrierMechanism:
	var barrier := BarrierMechanism.new()
	barrier.status = _status(id)
	barrier.exclusive_group = &"guard"
	barrier.mode = mode
	return barrier


func _power(short: String, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_barrier_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
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
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 20.0, &"max_charge": 100.0,
		&"max_shield": 2.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	attach(actor)
	_actors.append(actor)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
