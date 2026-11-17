extends TestCase
## The defences that need no power (C9.5a): an invincible status, mercy time after a hit, the
## overshield and its refill, and the `healing_taken` stat.
##
## OWNS: assertions about `HitGuard`, `StatusEffect.invincible` and `pierced_by`, the three
## clocks on `Combatant`, and `Vitals.HEALING_STAT`.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

const FOE: StringName = &"fixture_guard_foe"
const DT: float = 0.1

var _actors: Array[Node] = []
var _blocked: int = 0
var _told: Array[int] = []


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	Events.attack_blocked.connect(_on_blocked)
	Events.combatant_damaged.connect(_on_damaged)
	_invincible()
	_mercy()
	_overshield()
	_refill()
	_in_a_battle()
	_in_the_field()
	_healing()
	Events.attack_blocked.disconnect(_on_blocked)
	Events.combatant_damaged.disconnect(_on_damaged)
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _invincible() -> void:
	var star := StatusEffect.new()
	star.id = &"status/fixture_guard_star"
	star.unit = StatusEffect.Unit.SECONDS
	star.duration = 2.0
	star.pierced_by = [&"fixture_true"]
	equal("pierced_by with no invincible mark is flagged, and with it is sound",
		[star.problems().size(), _marked(star).problems().size()], [1, 0])
	var me: Combatant = _fighter(&"fixture_guard_star", {&"max_hp": 100.0})
	StatusSet.of(me.get_parent()).apply(star)
	var hit: DamageResult = _hit(10.0)
	equal("a hit on an invincible fighter takes nothing and is announced as blocked",
		[me.receive(hit, FOE), hit.blocked, _blocked, _hp(me)], [0, true, 1, 100])
	equal("a heal still lands, and so does a hit carrying a tag that pierces",
		[me.receive(_hit(-5.0), FOE), me.receive(_hit(10.0, [&"fixture_true"]), FOE), _blocked],
		[0, -10, 1])
	StatusSet.of(me.get_parent()).tick_seconds(2.0)
	equal("when the status runs out the next hit lands", me.receive(_hit(10.0), FOE), -10)


func _mercy() -> void:
	var me: Combatant = _fighter(&"fixture_guard_mercy", {&"max_hp": 100.0, &"mercy_time": 1.5})
	var first: int = me.receive(_hit(10.0), FOE)
	var second: int = me.receive(_hit(10.0), FOE)
	HitGuard.pass_time(me, 1.0)
	var third: int = me.receive(_hit(10.0), FOE)
	HitGuard.pass_time(me, 0.5)
	equal("after a hit that hurt, hits do nothing until the mercy time has passed",
		[first, second, third, me.receive(_hit(10.0), FOE)], [-10, 0, 0, -10])


func _overshield() -> void:
	var me: Combatant = _fighter(&"fixture_guard_shell", {&"max_hp": 12.0, &"max_overshield": 15.0})
	_told.clear()
	me.receive(_hit(10.0), FOE)
	equal("the overshield takes a hit before the hp does", [_hp(me), _shell(me)], [12, 5])
	me.receive(_hit(10.0), FOE)
	equal("what it cannot hold reaches the hp, and each hit is told whole",
		[_hp(me), _shell(me), _told], [7, 0, [10, 10]])
	Vitals.of(me.get_parent()).set_to(HitGuard.POOL, 6)
	me.receive(_hit(12.0), FOE)
	equal("a hit the overshield softened below the hp left does not fell the fighter", _hp(me), 1)


func _refill() -> void:
	var me: Combatant = _fighter(&"fixture_guard_refill", {&"max_hp": 50.0, &"max_overshield": 20.0,
		&"overshield_regen": 4.0, &"overshield_delay": 3.0})
	me.receive(_hit(20.0), FOE)
	HitGuard.pass_time(me, 2.0)
	var early: int = _shell(me)
	HitGuard.pass_time(me, 1.0)
	HitGuard.pass_time(me, 1.6)
	var later: int = _shell(me)
	HitGuard.pass_time(me, 0.1)
	HitGuard.pass_time(me, 10.0)
	equal("an overshield left alone for its delay refills by its rate, whole points only, "
			+ "up to its size", [early, later, _shell(me)], [0, 6, 20])
	me.receive(_hit(5.0), FOE)
	HitGuard.pass_time(me, 2.9)
	equal("and a new hit makes it wait again", _shell(me), 15)


func _in_a_battle() -> void:
	var me: Combatant = _fighter(&"fixture_guard_turns", {&"max_hp": 50.0, &"speed": 9.0,
		&"max_overshield": 10.0, &"overshield_regen": 3.0, &"mercy_time": 1.0})
	var foe: Combatant = _fighter(&"fixture_guard_rival", {&"max_hp": 50.0, &"speed": 1.0}, &"side_b")
	me.receive(_hit(10.0), FOE)
	var battle := Battle.new([me], [foe])
	battle.start()
	battle.next_turn()
	equal("in a battle a turn of the fighter's own refills the overshield and ends the mercy "
			+ "time", [battle.current() == me, _shell(me), me.mercy_left], [true, 3, 0.0])


func _in_the_field() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_actors.append(player)
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_guard_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_overshield": 10.0, &"overshield_regen": 10.0,
		&"mercy_time": 0.25}
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	var fighter: ActionFighter = ActionHost.equip(player, loadout)
	var me: Combatant = Combatant.of(player)
	me.receive(_hit(10.0), FOE)
	for i: int in 5:
		fighter.drive(DT, false, false)
	equal("in the field the fighter's own frames count both clocks",
		[me.mercy_left, _shell(me)], [0.0, 5])


func _healing() -> void:
	var me: Combatant = _fighter(&"fixture_guard_heal", {&"max_hp": 100.0})
	var vitals: Vitals = Vitals.of(me.get_parent())
	vitals.set_to(&"hp", 40)
	me.sheet.add(StatModifier.of(Vitals.HEALING_STAT, StatModifier.Op.ADD, 0.5, &"fixture_guard"))
	var more: int = vitals.change(&"hp", 10)
	me.sheet.remove_from(&"fixture_guard")
	me.sheet.add(StatModifier.of(Vitals.HEALING_STAT, StatModifier.Op.ADD, -1.0, &"fixture_guard"))
	equal("healing_taken scales a heal, and at -1 nothing heals, not even an absorbed hit",
		[more, vitals.change(&"hp", 10), me.receive(_hit(-10.0), FOE)], [55, 55, 0])
	equal("a hit and a pool set outright are not scaled",
		[vitals.change(&"hp", -5), vitals.set_to(&"hp", 80)], [50, 80])


func _marked(effect: StatusEffect) -> StatusEffect:
	effect.invincible = true
	return effect


func _hit(amount: float, tags: Array[StringName] = []) -> DamageResult:
	var result := DamageResult.new()
	result.amount = amount
	result.tags = tags
	return result


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _shell(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(HitGuard.POOL)


func _fighter(id: StringName, stats: Dictionary[StringName, float],
		side: StringName = &"side_a") -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant


func _on_blocked(_who: StringName, _by: StringName) -> void:
	_blocked += 1


func _on_damaged(_who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	_told.append(amount)
