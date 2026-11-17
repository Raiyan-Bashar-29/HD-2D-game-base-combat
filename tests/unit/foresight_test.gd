extends TestCase
## Foresight (C6.10): the M7 shape and its problems; DODGE turns a foe's landing hit into a
## miss while rewrites last; the field gap between rewrites; entering an area fills them again;
## FORCE turns the holder's miss into a hit; observe makes a skill that landed once miss; reveal
## in a battle and on lock-on; and nothing works outside the power's hours.
##
## OWNS: assertions about `ForesightMechanism`, `ForesightRun` and `Foresight`.
## MUST NOT: name a game's kits, powers or characters.

const WEAK: StringName = &"fixture_foresight_weak"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _foe: Combatant


func run() -> void:
	plan(10)
	Flags.clear_all()
	_rng.seed = 7
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_foresight_me", &"player", Vector3.ZERO)
	_foe = _fighter(&"fixture_foresight_foe", &"enemy", Vector3(0.0, 0.0, -2.0))
	_dodge()
	_force_and_observe()
	_reveal()
	_hours()
	PowerSet.of(_me.get_parent()).equip(null)
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var sight := ForesightMechanism.new()
	sight.observe = true
	equal("a foresight's kind is foresight, the base runs it, and a clean one has no problems",
		[sight.kind(), PowerMechanisms.make(sight) is ForesightRun, sight.problems("f").size()],
		[&"foresight", true, 0])
	var bad := ForesightMechanism.new()
	bad.rewrites = 2
	bad.rewrite_gap = -1.0
	equal("rewrites that may neither dodge nor force, a negative gap, and foreseeing nothing are problems",
		[bad.problems("f").size(), ForesightMechanism.new().problems("f").size()], [2, 1])


func _dodge() -> void:
	_wear(_sight(2, true, false, 0.0))
	var hits: Array[bool] = [_lands(_foe, _me), _lands(_foe, _me), _lands(_foe, _me)]
	equal("each rewrite turns a foe's landing hit into a miss; with none left the hit lands",
		hits, [false, false, true])
	_wear(_sight(2, true, false, 2.0))
	var first: bool = _lands(_foe, _me)
	var soon: bool = _lands(_foe, _me)
	PowerSet.of(_me.get_parent()).tick_seconds(2.0)
	equal("in the field a rewrite waits out the gap after the last one", [first, soon, _lands(_foe, _me)],
		[false, true, false])
	_lands(_foe, _me)
	PowerSet.of(_me.get_parent()).tick_seconds(2.0)
	var spent: bool = _lands(_foe, _me)
	Events.area_entered.emit(&"area/fixture_foresight")
	equal("entering an area fills the rewrites again", [spent, _lands(_foe, _me)], [true, false])


func _force_and_observe() -> void:
	_wear(_sight(1, false, true, 0.0))
	_foe.sheet.set_base(&"evasion", 1.0)
	equal("a rewrite strikes the holder's miss again as a sure hit, once",
		[_lands(_me, _foe), _lands(_me, _foe)], [true, false])
	_foe.sheet.set_base(&"evasion", 0.0)
	var watch: ForesightMechanism = _sight(0, false, false, 0.0)
	watch.observe = true
	_wear(watch)
	equal("a skill that landed once misses the observer after, and another still lands",
		[_lands(_foe, _me, &"skill/fixture_a"), _lands(_foe, _me, &"skill/fixture_a"),
			_lands(_foe, _me, &"skill/fixture_b"), _lands(_foe, _me)], [true, false, true, true])


func _reveal() -> void:
	var seer: ForesightMechanism = _sight(0, false, false, 0.0)
	seer.reveal = true
	_wear(seer)
	_foe.weak_to = [WEAK]
	var lock := LockOn.new()
	_me.get_parent().add_child(lock)
	var before: bool = Weakness.revealed(_foe, WEAK)
	PowerSet.of(_me.get_parent()).tick_seconds(0.1)
	var unlocked: bool = Weakness.revealed(_foe, WEAK)
	lock.target = _hurtbox(_foe)
	PowerSet.of(_me.get_parent()).tick_seconds(0.1)
	equal("in the field the locked-on foe's weaknesses are shown, and only once it is locked",
		[before, unlocked, Weakness.revealed(_foe, WEAK)], [false, false, true])
	lock.free()
	Flags.clear_all()
	_me.real_time = false
	var battle := Battle.new([_me], [_foe])
	Battle.running = battle
	PowerSet.of(_me.get_parent()).tick_turn()
	Battle.running = null
	_me.real_time = true
	equal("in a battle every foe's weaknesses are shown on the holder's turn", Weakness.revealed(_foe, WEAK), true)


func _hours() -> void:
	var day: ForesightMechanism = _sight(1, true, false, 0.0)
	var power: Power = _wear(day)
	power.active_hours = Vector2(6.0, 18.0)
	Clock.set_time(1, 22)
	var night: bool = _lands(_foe, _me)
	Clock.set_time(1, 12)
	equal("outside its hours foresight does nothing; inside them it rewrites", [night, _lands(_foe, _me)],
		[true, false])


func _sight(count: int, dodge: bool, force: bool, gap: float) -> ForesightMechanism:
	var sight := ForesightMechanism.new()
	sight.rewrites = count
	sight.dodge = dodge
	sight.force = force
	sight.rewrite_gap = gap
	return sight


# Puts a fresh kit holding one foresight power on the holder; returns the power.
func _wear(sight: ForesightMechanism) -> Power:
	var power := Power.new()
	power.power_id = &"power/fixture_foresight"
	power.name_key = "fixture.power"
	power.mechanism = sight
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_foresight"
	kit.powers = [power]
	PowerSet.of(_me.get_parent()).equip(kit)
	return power


# One hit of `from` on `to`, with `key` as what is striking; true when it landed.
func _lands(from: Combatant, to: Combatant, key: StringName = &"") -> bool:
	Foresight.striking = key
	var result: DamageResult = from.hit(to, 1.0, &"", _rng)
	Foresight.striking = &""
	Vitals.of(to.get_parent()).set_to(&"hp", 100)
	return not result.missed


func _fighter(id: StringName, faction: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AccuracyStage.new(), AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	return fighter


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null
