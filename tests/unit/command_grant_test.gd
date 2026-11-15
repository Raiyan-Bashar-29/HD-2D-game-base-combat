extends TestCase
## Command and grant (C6.11): the M8 and M12 shapes and their problems; OBEY turns a foe to the
## user's side and a battle counts it out; the once flag, a canceller, reach and sight refuse
## an order; STOP, FORGET (gone in the field, standing aside in a battle) and FALL (refused by
## an immune trait); a grant gives statuses to the aimed ally or to the whole side, and lends a
## kit that its receiver lets go when the clock runs out or the user's kit comes off.
##
## OWNS: assertions about `CommandMechanism`, `CommandRun`, `GrantMechanism`, `GrantRun`,
## `StatusSet.obeyed`, `Combatant.side` and the obeying rule in `Battle`.
## MUST NOT: name a game's kits, powers or characters.

const OBEY: StringName = &"status/fixture_order_obey"
const STOP: StringName = &"status/fixture_order_stop"
const CANCEL: StringName = &"status/fixture_order_cancel"
const GIFT_A: StringName = &"status/fixture_grant_a"
const GIFT_B: StringName = &"status/fixture_grant_b"
const GIFT_C: StringName = &"status/fixture_grant_c"
const FAMILY: String = "fixture_order"

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _ally: Combatant
var _front: Combatant
var _other: Combatant
var _behind: Combatant
var _far: Combatant
var _boss: Combatant
var _powers: Dictionary[String, Power] = {}
var _lent_power: Power


func run() -> void:
	plan(13)
	Flags.clear_all()
	_rng.seed = 5
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_order_me", &"player", Vector3.ZERO, _kit())
	_ally = _fighter(&"fixture_order_ally", &"player", Vector3(2.0, 0.0, 0.0), null)
	_front = _fighter(&"fixture_order_front", &"enemy", Vector3(0.0, 0.0, -3.0), null)
	_other = _fighter(&"fixture_order_other", &"enemy", Vector3(1.0, 0.0, -3.0), null)
	_behind = _fighter(&"fixture_order_behind", &"enemy", Vector3(0.0, 0.0, 3.0), null)
	_far = _fighter(&"fixture_order_far", &"enemy", Vector3(0.0, 0.0, -40.0), null)
	_boss = _fighter(&"fixture_order_boss", &"enemy", Vector3(-1.0, 0.0, -3.0), null)
	_boss.traits = [&"boss"]
	_obey()
	_refusals()
	_fall_and_forget()
	_battle()
	_grant()
	Battle.running = null
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var command := CommandMechanism.new()
	command.order = CommandMechanism.Order.OBEY
	command.status = _status(OBEY, [], true, false)
	var grant := GrantMechanism.new()
	grant.gifts = [_status(GIFT_A, [], false, false)]
	equal("the kinds are command and grant, the base runs both, and clean ones have no problems",
		[command.kind(), grant.kind(), PowerMechanisms.make(command) is CommandRun,
			PowerMechanisms.make(grant) is GrantRun, command.problems("f").size(), grant.problems("f").size()],
		[&"command", &"grant", true, true, 0, 0])
	var stop := CommandMechanism.new()
	var wrong := CommandMechanism.new()
	wrong.order = CommandMechanism.Order.OBEY
	wrong.status = _status(STOP, [], false, true)
	wrong.reach = -1.0
	var empty := GrantMechanism.new()
	var lend := GrantMechanism.new()
	lend.kit = PowerKit.new()
	lend.lasts = 0.0
	lend.radius = -1.0
	equal("STOP with no status, OBEY with a status that does not obey, a negative reach, a grant of nothing, a kit for no time",
		[stop.problems("f").size(), wrong.problems("f").size(), empty.problems("f").size(), lend.problems("f").size()],
		[1, 2, 1, 2])


func _obey() -> void:
	_use("obey", _front)
	equal("an obeying foe fights for the user's side: it may strike its old side and not the user",
		[_front.side(), _front.can_target(_other, FactionTable.Target.ENEMY),
			_front.can_target(_me, FactionTable.Target.ENEMY), _me.can_target(_front, FactionTable.Target.ALLY),
			Flags.get_bool(StringName(FAMILY + "/fixture_order_front"))],
		[&"player", true, false, true, true])


func _refusals() -> void:
	var statuses: StatusSet = StatusSet.of(_front.get_parent())
	statuses.cure(OBEY)
	_use("stop", _front)
	equal("once the obey is cured the foe is a foe again, and the once flag refuses a second order",
		[_front.side(), statuses.stacks(STOP)], [&"enemy", 0])
	statuses.apply(_status(CANCEL, [&"fixture_canceller"], false, false))
	_use("stop", _front)
	var after_cancel: bool = Flags.get_bool(StringName(FAMILY + "/fixture_order_front"))
	statuses.cure(CANCEL)
	_use("stop", _front)
	equal("a canceller refuses the order and lifts the flag, so the next order works",
		[after_cancel, statuses.stacks(STOP)], [false, 1])
	_use("stop", _behind)
	_use("stop", _far)
	equal("in the field a foe behind the user or out of reach is refused",
		[StatusSet.of(_behind.get_parent()).stacks(STOP), StatusSet.of(_far.get_parent()).stacks(STOP)], [0, 0])


func _fall_and_forget() -> void:
	_use("fall", _boss)
	_use("fall", _behind)
	equal("FALL defeats a foe at once; a foe with the immune trait refuses",
		[Vitals.of(_boss.get_parent()).is_defeated(), Vitals.of(_behind.get_parent()).is_defeated()], [false, true])
	_use("forget", _far)
	var gone: bool = _far.get_parent().is_queued_for_deletion()
	var stray: Combatant = _fighter(&"fixture_order_stray", &"enemy", Vector3(0.0, 0.0, -2.0), null)
	stray.real_time = false
	_use("forget", stray)
	var held: StatusSet = StatusSet.of(stray.get_parent())
	equal("FORGET takes a field foe away undefeated; in a battle the foe stands aside, counted as fallen",
		[gone, Vitals.of(_far.get_parent()).is_defeated(), held.fallen(), held.stacks(CommandRun.FORGOTTEN)],
		[true, false, true, 1])


func _battle() -> void:
	var plain: Battle = Battle.new([_me] as Array[Combatant], [_other] as Array[Combatant])
	plain.start()
	var before: Battle.Outcome = plain.outcome()
	StatusSet.of(_other.get_parent()).apply(_status(OBEY, [], true, false), _rng, _me.combatant_id)
	var turned: Battle = Battle.new([_me] as Array[Combatant], [_other] as Array[Combatant])
	turned.start()
	equal("a battle whose last foe obeys the party is won; one with a foe of its own is not",
		[before, turned.outcome(), StatusSet.of(_other.get_parent()).obeyed()],
		[Battle.Outcome.ONGOING, Battle.Outcome.WON, &"fixture_order_me"])
	Battle.running = null


func _grant() -> void:
	_use("give", _ally)
	_use("give", _front)
	equal("a grant gives its status to the aimed ally, and to the user when the aim is a foe",
		[StatusSet.of(_ally.get_parent()).stacks(GIFT_A), StatusSet.of(_front.get_parent()).stacks(GIFT_A),
			StatusSet.of(_me.get_parent()).stacks(GIFT_A)],
		[1, 0, 1])
	_use("all", null)
	var mine: StatusSet = StatusSet.of(_me.get_parent())
	var theirs: StatusSet = StatusSet.of(_ally.get_parent())
	equal("a grant to the side gives each one of its gifts and lends the kit to each",
		[mine.stacks(GIFT_B) + mine.stacks(GIFT_C), theirs.stacks(GIFT_B) + theirs.stacks(GIFT_C),
			PowerSet.of(_ally.get_parent()).has(_lent_power)],
		[1, 1, true])
	var run_all: PowerExecutor = PowerSet.of(_me.get_parent()).executor(&"power/fixture_grant_all")
	run_all.tick(1.0)
	var still: bool = PowerSet.of(_ally.get_parent()).has(_lent_power)
	run_all.tick(1.5)
	equal("the lent kit stays while its clock runs and is let go when it runs out",
		[still, PowerSet.of(_ally.get_parent()).has(_lent_power)], [true, false])
	_use("all", null)
	PowerSet.of(_me.get_parent()).unequip()
	equal("taking the user's kit off takes every lent kit back",
		PowerSet.of(_ally.get_parent()).has(_lent_power), false)


func _kit() -> PowerKit:
	var obey := _command(CommandMechanism.Order.OBEY, _status(OBEY, [], true, false))
	var stop := _command(CommandMechanism.Order.STOP, _status(STOP, [], false, true))
	var fall := _command(CommandMechanism.Order.FALL, null)
	fall.once_flag = ""
	fall.sight = false
	fall.immune_tag = &"boss"
	var forget := _command(CommandMechanism.Order.FORGET, null)
	forget.once_flag = ""
	forget.sight = false
	forget.reach = 0.0
	var give := GrantMechanism.new()
	give.gifts = [_status(GIFT_A, [], false, false)]
	var all := GrantMechanism.new()
	all.gifts = [_status(GIFT_B, [], false, false), _status(GIFT_C, [], false, false)]
	all.pick_one = true
	all.to_all = true
	all.radius = 10.0
	all.lasts = 2.0
	_lent_power = Power.new()
	_lent_power.power_id = &"power/fixture_grant_lent"
	_lent_power.name_key = "fixture.power"
	all.kit = PowerKit.new()
	all.kit.kit_id = &"kit/fixture_grant_lent"
	all.kit.powers = [_lent_power]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_order"
	kit.powers = [_power("obey", "order", obey), _power("stop", "order", stop), _power("fall", "order", fall),
		_power("forget", "order", forget), _power("give", "grant", give), _power("all", "grant", all)]
	return kit


func _command(order: CommandMechanism.Order, status: StatusEffect) -> CommandMechanism:
	var command := CommandMechanism.new()
	command.order = order
	command.status = status
	command.reach = 30.0
	command.once_flag = FAMILY
	command.canceller_tag = &"fixture_canceller"
	return command


func _status(id: StringName, tags: Array[StringName], obeys: bool, stops: bool) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 30.0
	status.tags = tags
	status.obeys = obeys
	if stops:
		status.blocks = [StatusEffect.Block.SKIP_TURN]
	return status


func _power(short: String, family: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_%s_%s" % [family, short])
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
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 20.0, &"attack": 6.0, &"defence": 1.0, &"speed": 5.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String, aim: Combatant) -> bool:
	var aimed: Array[Combatant] = []
	if aim != null:
		aimed.append(aim)
	return PowerUse.use(_me, _powers[short], aimed, _rng, 12.0)
