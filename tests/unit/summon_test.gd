extends TestCase
## Owned fighters (C8.10a). A summon's shape and problems; a use brings one fighter per entry
## beside the user, on the user's side, and puts `owner_status` on the user; a power that
## forbids that status is refused while any is out; `cap` keeps the newest; a lifetime runs out;
## the user falling, the area unloading or the kit coming off sends all away; a summon fights the user's foe, and
## gives no reward when it falls; an untouchable one is never picked; a `moves_each` of 1 sends
## one away once its first move ends (C8.10c).
##
## OWNS: assertions about `SummonMechanism`, `SummonRun`, `OwnedFighter` and
## `Power.forbids_statuses`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics: `act` is called by
## hand.

const NOON: float = 12.0
const DT: float = 0.1

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _summon := SummonMechanism.new()
var _call: Power
var _gated: Power
var _rewards: int = 0


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 3
	_world = Node3D.new()
	attach(_world)
	_shape()
	var me: Combatant = _fighter(&"fixture_summoner", &"side_a", Vector3.ZERO, _kit())
	var foe: Combatant = _fighter(&"fixture_summon_foe", &"side_b", Vector3(0, 0, -20), null)
	_coming(me, foe)
	_leaving(me)
	_fighting(me, foe)
	_rules(me, foe)
	_world.free()
	Flags.clear_all()


func _shape() -> void:
	var bad := SummonMechanism.new()
	bad.fighters = [_def(&"fixture_helper_a")]
	bad.cap = -1
	var good: SummonMechanism = _mechanism(0.0, 0)
	equal("a summon's kind, its executor, it aims at nobody; no brain and a negative cap are problems",
		[good.kind(), PowerMechanisms.make(good) is SummonRun, good.aims_at_foes(), good.problems("f").size(),
			bad.problems("f").size()], [&"summon", true, false, 0, 2])


func _coming(me: Combatant, foe: Combatant) -> void:
	_use(me, _call)
	var out: Array[OwnedFighter] = _out()
	var near: bool = out.size() == 2
	for one: OwnedFighter in out:
		near = near and is_equal_approx(_flat(one.global_position).length(), 1.5) and one.owner_body == me.get_parent()
	equal("a use brings one fighter per entry, 1.5 m beside the user, knowing their owner and power",
		[near, out[0].power_id, Combatant.of(out[0]).side()], [true, _call.power_id, &"side_a"])
	var mine: Combatant = Combatant.of(out[0])
	equal("they fight the user's foe and not the user; the user holds the summon's status",
		[mine.can_target(foe, FactionTable.Target.ENEMY), mine.can_target(me, FactionTable.Target.ENEMY),
			StatusSet.of(me.get_parent()).stacks(_summon.owner_status.id)], [true, false, 1])
	equal("a power that forbids that status is refused while they are out, with its own words",
		[PowerUse.refusal(me, _gated, NOON), PowerMenu.reason_key(me, _gated)],
		[PowerUse.Reason.FORBIDDEN, PowerMenu.FORBIDDEN_KEY])
	var first: OwnedFighter = out[0]
	_use(me, _call)
	equal("a use over the cap of 2 sends the oldest away and keeps the newest",
		[_out().size(), _out().has(first)], [2, false])


func _leaving(me: Combatant) -> void:
	var run: SummonRun = PowerSet.of(me.get_parent()).executor(_call.power_id) as SummonRun
	_summon.lifetime = 5.0
	_use(me, _call)
	run.tick(4.0)
	var midway: int = _out().size()
	run.tick(2.0)
	equal("a lifetime of 5 s: there at 4 s, gone at 6 s; the status is off and the forbidden power is free",
		[midway, _out().size(), StatusSet.of(me.get_parent()).stacks(_summon.owner_status.id),
			PowerUse.refusal(me, _gated, NOON)], [2, 0, 0, PowerUse.Reason.NONE])
	_summon.lifetime = 0.0
	_use(me, _call)
	Events.combatant_defeated.emit(me.combatant_id)
	var after_fall: int = _out().size()
	_use(me, _call)
	Events.area_unloading.emit(&"fixture_area")
	var after_area: int = _out().size()
	_use(me, _call)
	PowerSet.of(me.get_parent()).unequip()
	equal("the user falling sends all away, and so do leaving the area and the kit coming off",
		[after_fall, after_area, _out().size()], [0, 0, 0])


func _fighting(me: Combatant, foe: Combatant) -> void:
	PowerSet.of(me.get_parent()).equip(_kit())
	_use(me, _call)
	var one: OwnedFighter = _out()[0]
	var foe_body: Node3D = foe.get_parent() as Node3D
	foe_body.global_position = one.global_position + Vector3(0, 0, -1)
	var state: ActionDecider.State = one.act(DT)
	for child: Node in one.get_children():
		if child is Hitbox:
			(child as Hitbox).strike(_hurtbox(foe_body))
	var hp: int = Vitals.of(foe_body).current(&"hp")
	Events.field_enemy_defeated.connect(_on_reward)
	Vitals.of(one).change(&"hp", -999)
	one.act(DT)
	Events.field_enemy_defeated.disconnect(_on_reward)
	equal("a summon starts its move at the user's foe and the hit lands; fallen, it gives no reward",
		[state, hp < 100, _rewards], [ActionDecider.State.ATTACK, true, 0])


func _rules(me: Combatant, foe: Combatant) -> void:
	PowerSet.of(me.get_parent()).equip(_kit())
	_summon.untouchable = true
	_summon.moves_each = 1
	_use(me, _call)
	var one: OwnedFighter = _out()[0]
	var foe_body: Node3D = foe.get_parent() as Node3D
	foe_body.global_position = one.global_position + Vector3(0, 0, -1)
	var picked: Hurtbox = Aggro.pick(foe_body)
	equal("an untouchable summon is out of the hurtbox group, so its user's foe picks the user",
		[_hurtbox(one).is_in_group(Hurtbox.GROUP), _hurtbox(one).monitorable, picked == _hurtbox(me.get_parent())],
		[false, false, true])
	var run: SummonRun = PowerSet.of(me.get_parent()).executor(_call.power_id) as SummonRun
	var steps: int = 0
	one.act(DT)
	var started: int = one.moves_done
	run.tick(DT)
	var during: bool = _out().has(one)
	while not one.idle() and steps < 100:
		one.act(DT)
		steps += 1
	run.tick(DT)
	equal("a summon of one move stays through it and leaves once it ends",
		[started, during, _out().has(one)], [1, true, false])
	_summon.untouchable = false
	_summon.moves_each = 0


func _on_reward(_who: StringName, _experience: int, _loot: Array[StringName]) -> void:
	_rewards += 1


func _out() -> Array[OwnedFighter]:
	var out: Array[OwnedFighter] = []
	for node: Node in _world.get_tree().get_nodes_in_group(OwnedFighter.GROUP):
		if not node.is_queued_for_deletion():
			out.append(node as OwnedFighter)
	return out


func _mechanism(lifetime: float, cap: int) -> SummonMechanism:
	var made := SummonMechanism.new()
	made.fighters = [_def(&"fixture_helper_a"), _def(&"fixture_helper_b")]
	var jab := ActionMove.new()
	jab.id = &"move/fixture_helper_jab"
	jab.power = 3.0
	var entry := ActionBrainEntry.new()
	entry.move = jab
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	brain.moves = [entry]
	made.brains = [brain, brain]
	made.lifetime = lifetime
	made.cap = cap
	var status := StatusEffect.new()
	status.id = &"status/fixture_helpers_out"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 9999.0
	made.owner_status = status
	return made


func _kit() -> PowerKit:
	if _call == null:
		_summon = _mechanism(0.0, 2)
		_call = _power("call", _summon)
		_gated = _power("gated", null)
		_gated.forbids_statuses = [_summon.owner_status.id]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_summon"
	kit.powers = [_call, _gated]
	return kit


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_summon_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _use(user: Combatant, power: Power) -> bool:
	return PowerUse.use(user, power, [], _rng, NOON)


func _def(id: StringName) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"side_z"
	def.base_stats = {&"max_hp": 20.0, &"attack": 4.0, &"defence": 1.0}
	return def


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
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
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	var hurtbox := Hurtbox.new()
	hurtbox.timeline = MoveTimeline.new()
	actor.add_child(hurtbox)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
