extends TestCase
## Blinks (C6.12a). In the field: FORWARD moves the user the way it faces; TARGET and
## BEHIND_TARGET land in front of or behind the aimed foe; UP rises; SWAP trades places; with
## no one to aim at a targeted blink goes nowhere; `cancels_recovery` ends the user's move;
## `arrival` lands on the user; a `path_strike` hits a foe on the line and not one beside it.
## In a battle: `sooner` brings the user's next turn forward, and SWAP trades places in the
## turn order.
##
## OWNS: assertions about `BlinkMechanism` and `BlinkRun`.
## MUST NOT: name a game's kits, powers or characters.

const NOON: float = 12.0

var _powers: Dictionary[String, Power] = {}
var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 2
	_world = Node3D.new()
	attach(_world)
	_shape()
	_field()
	_world.free()
	_battle()
	Flags.clear_all()


func _shape() -> void:
	var blink := BlinkMechanism.new()
	var clean: Array = [blink.kind(), PowerMechanisms.make(blink) is BlinkRun, blink.aims_at_foes(),
		blink.problems("fixture").size()]
	blink.to = BlinkMechanism.To.UP
	blink.height = 0.0
	blink.distance = -1.0
	equal("a blink's kind, its executor, a forward blink aims at nobody, and bad numbers are problems",
		[clean, blink.problems("fixture").size()], [[&"blink", true, false, 0], 2])


func _field() -> void:
	var me: Combatant = _fighter(&"fixture_blink_me", &"side_a", Vector3.ZERO, _kit())
	var body: Node3D = me.get_parent() as Node3D
	body.look_at(Vector3(0, 0, -1), Vector3.UP)
	_use(me, "nowhere")
	var stayed: Vector3 = body.global_position
	var foe: Combatant = _fighter(&"fixture_blink_foe", &"side_b", Vector3(0, 0, -6), null)
	var beside: Combatant = _fighter(&"fixture_blink_beside", &"side_b", Vector3(5, 0, -2), null)
	var crossed: Combatant = _fighter(&"fixture_blink_crossed", &"side_b", Vector3(0.2, 0, -2), null)
	_use(me, "forward")
	var forward: Vector3 = body.global_position
	equal("with nobody to aim at a targeted blink stays; FORWARD moves the way the user faces",
		[stayed.is_equal_approx(Vector3.ZERO), forward.is_equal_approx(Vector3(0, 0, -4))], [true, true])
	body.global_position = Vector3.ZERO
	_use(me, "behind", [foe])
	var behind: Vector3 = body.global_position
	body.global_position = Vector3.ZERO
	_use(me, "front", [foe])
	equal("BEHIND_TARGET lands past the foe, TARGET in front of it",
		[behind.is_equal_approx(Vector3(0, 0, -8)), body.global_position.is_equal_approx(Vector3(0, 0, -4))],
		[true, true])
	body.global_position = Vector3.ZERO
	var timeline: MoveTimeline = _hurtbox(body).timeline
	timeline.start(_move(0.0))
	var busy: bool = timeline.busy()
	_use(me, "up")
	equal("UP rises and, cancelling recovery, ends the user's move; the arrival status lands",
		[body.global_position.is_equal_approx(Vector3(0, 3, 0)), busy, timeline.busy(),
			StatusSet.of(body).stacks(&"status/fixture_blink_arrival")], [true, true, false, 1])
	body.global_position = Vector3.ZERO
	body.look_at(Vector3(0, 0, -1), Vector3.UP)
	_use(me, "dash")
	equal("a striking path hits the foe it crosses, not the one beside it",
		[_hp(crossed) < 100, _hp(beside), _hp(foe)], [true, 100, 100])
	body.global_position = Vector3(1, 0, 0)
	_use(me, "swap", [foe])
	equal("SWAP trades places with the aimed foe",
		[body.global_position.is_equal_approx(Vector3(0, 0, -6)),
			(foe.get_parent() as Node3D).global_position.is_equal_approx(Vector3(1, 0, 0))], [true, true])


func _battle() -> void:
	var holder := Node.new()
	attach(holder)
	var hero: CombatantDef = _def(&"fixture_blink_hero", &"side_a", 10.0)
	hero.power_kit = _kit()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_blink"
	encounter.turn_order = Encounter.TurnOrder.CTB
	encounter.enemies = [_def(&"fixture_blink_slow", &"side_b", 5.0)]
	var battle: Battle = BattleSetup.build(encounter, [hero], holder, RandomNumberGenerator.new())
	battle.next_turn()
	var queue: CtbScheduler = battle.scheduler as CtbScheduler
	var running: bool = Battle.running == battle
	var before: float = queue.wait_of(&"fixture_blink_hero")
	battle.act(BattleCommand.for_power(_powers["forward"]), [])
	equal("in a battle a blink brings the user's next turn sooner",
		[running, before - queue.wait_of(&"fixture_blink_hero")], [true, 4.0])
	var again: bool = battle.next_turn() == battle.party[0]
	var mine: float = queue.wait_of(&"fixture_blink_hero")
	var theirs: float = queue.wait_of(&"fixture_blink_slow")
	battle.act(BattleCommand.for_power(_powers["swap"]), [battle.enemies[0]])
	equal("SWAP trades places in the turn order",
		[again, queue.wait_of(&"fixture_blink_hero"), queue.wait_of(&"fixture_blink_slow")], [true, theirs, mine])
	BattleSetup.release(battle)
	holder.free()


func _kit() -> PowerKit:
	var forward := _blink(BlinkMechanism.To.FORWARD)
	forward.sooner = 4.0
	var up := _blink(BlinkMechanism.To.UP)
	up.cancels_recovery = true
	up.arrival = StatusEffect.new()
	up.arrival.id = &"status/fixture_blink_arrival"
	up.arrival.name_key = "ui.cancel"
	up.arrival.unit = StatusEffect.Unit.SECONDS
	up.arrival.duration = 0.5
	up.arrival.invincible = true
	var behind := _blink(BlinkMechanism.To.BEHIND_TARGET)
	behind.distance = 2.0
	var front := _blink(BlinkMechanism.To.TARGET)
	front.distance = 2.0
	var dash := _blink(BlinkMechanism.To.FORWARD)
	dash.path_strike = _move(5.0)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_blink"
	kit.powers = [_power("nowhere", _blink(BlinkMechanism.To.TARGET)), _power("forward", forward),
		_power("up", up), _power("behind", behind), _power("front", front), _power("dash", dash),
		_power("swap", _blink(BlinkMechanism.To.SWAP))]
	return kit


func _blink(to: BlinkMechanism.To) -> BlinkMechanism:
	var made := BlinkMechanism.new()
	made.to = to
	return made


func _move(power: float) -> ActionMove:
	var move := ActionMove.new()
	move.id = &"move/fixture_blink"
	move.name_key = "ui.cancel"
	move.startup = 0.1
	move.active = 0.1
	move.recovery = 0.5
	move.power = power
	return move


func _power(short: String, mechanism: PowerMechanism) -> Power:
	if _powers.has(short):
		return _powers[short]
	var power := Power.new()
	power.power_id = StringName("power/fixture_blink_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _use(user: Combatant, short: String, aimed: Array[Combatant] = []) -> bool:
	PowerSet.of(user.get_parent()).equip(PowerSet.of(user.get_parent()).kit)
	return PowerUse.use(user, _powers[short], aimed, _rng, NOON)


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"attack": 5.0, &"defence": 1.0, &"speed": speed}
	return def


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


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
	Vitals.of(fighter.get_parent()).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
