extends TestCase
## Forms that play their own moves (C6.5b): while a form is held, the field fighter plays its
## attack chain and dodge in place of its own, a cycle stage plays its own or the cycle's, a
## follower in a form swings the form's chain, a form left mid-roll still rolls, and a form can
## drain a pool for each move started, never for a dodge.
##
## OWNS: assertions about `PowerSet.moves_over`, `FormRun.moves` and `moved`,
## `ActionFighter.current_moves` and the follower's swing in a form.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const DT: float = 0.05
const NOON: float = 12.0

var _rng := RandomNumberGenerator.new()
var _player: PlayerController
var _fighter: ActionFighter
var _foe: Node3D
var _base_first: ActionMove
var _base_dodge: ActionMove
var _form_first: ActionMove
var _form_dodge: ActionMove
var _stage_first: ActionMove
var _cycle_first: ActionMove
var _blade: Power
var _swords: Power


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	_base_first = _move(0.05, 0.1, 0.3, 0.0)
	_base_dodge = _move(0.0, 0.3, 0.1, 0.0)
	_base_dodge.travel_speed = 6.0
	_form_first = _move(0.05, 0.1, 0.3, 0.0)
	_form_dodge = _move(0.0, 0.3, 0.1, 0.0)
	_form_dodge.travel_speed = 6.0
	_stage_first = _move(0.05, 0.1, 0.3, 0.0)
	_cycle_first = _move(0.05, 0.1, 0.3, 0.0)
	var kit: PowerKit = _kit()
	var lead: ActionLoadout = _loadout(&"fixture_moves_lead", kit)
	var mate: ActionLoadout = _loadout(&"fixture_moves_mate", kit)
	lead.companions = [mate]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_player.global_position = Vector3.ZERO
	ActionHost.equip(_player, lead)
	for child: Node in _player.get_children():
		if child is ActionFighter:
			_fighter = child as ActionFighter
	_foe = _enemy()
	_shapes()
	_the_set()
	_the_fighter()
	_draining()
	var follower: PartyFollower = FieldParty.spawn(_player, lead)[0]
	_the_follower(follower, mate)
	for each: PartyFollower in FieldParty.followers(_player):
		each.free()
	_player.free()
	_foe.free()
	Flags.clear_all()


func _shapes() -> void:
	var form := FormMechanism.new()
	form.status = _status(&"status/fixture_moves_shape")
	form.drain_per_action = 1.0
	equal("a drain per action with no pool is a problem", form.problems("fixture").size(), 1)
	form.drain_pool = &"devil"
	form.drain_per_action = -1.0
	equal("a negative drain per action is a problem", form.problems("fixture").size(), 1)


func _the_set() -> void:
	var powers: PowerSet = PowerSet.of(_player)
	var base: MoveSet = _fighter.moves
	equal("out of every form, the fighter plays its own moves", powers.moves_over(base) == base, true)
	_use(_blade)
	var playing: MoveSet = powers.moves_over(base)
	equal("in a form, the form's chain and dodge play, the skills stay, and the set is kept",
		[playing.attack_chain[0] == _form_first, playing.dodge == _form_dodge,
		playing.skills == base.skills, powers.moves_over(base) == playing, playing != base],
		[true, true, true, true, true])
	_use(_swords)
	equal("a cycle stage with its own chain plays it, and the group left the other form",
		[powers.moves_over(base).attack_chain[0] == _stage_first, _stacks(&"status/fixture_moves_blade")],
		[true, 0])
	_use(_swords)
	equal("a stage with no moves of its own plays the cycle's chain, and keeps the fighter's dodge",
		[powers.moves_over(base).attack_chain[0] == _cycle_first, powers.moves_over(base).dodge == _base_dodge],
		[true, true])
	_use(_blade)
	_use(_blade)
	equal("after leaving, the fighter's own moves are back", powers.moves_over(base) == base, true)


func _the_fighter() -> void:
	_use(_blade)
	_fighter.drive(DT, true, false)
	equal("the attack button in a form opens the form's chain", _fighter.timeline.move == _form_first, true)
	_fighter.timeline.cancel()
	_player.velocity = Vector3(1.0, 0.0, 0.0)
	_fighter.facing = Vector3.FORWARD
	_fighter.drive(0.0, false, true)
	equal("the dodge button in a form plays the form's dodge", _fighter.timeline.move == _form_dodge, true)
	# Left mid-roll: the roll is still a roll, along the way the body was moving, not a lunge.
	_use(_blade)
	_fighter.drive(DT, false, false)
	equal("a form left mid-roll still rolls the way the body was going",
		[_fighter.timeline.move == _form_dodge, _player.velocity.x > 0.0, absf(_player.velocity.z) < 0.01],
		[true, true, true])
	_fighter.timeline.cancel()
	_fighter.drive(DT, false, false)


func _draining() -> void:
	var vitals: Vitals = Vitals.of(_player)
	vitals.set_to(&"devil", 10)
	_use(_blade)
	_swing()
	_swing()
	equal("each move started drains its share, a point for two half-point swings",
		vitals.current(&"devil"), 9)
	_fighter.drive(0.0, false, true)
	_fighter.drive(DT, false, false)
	_fighter.timeline.cancel()
	equal("a dodge drains nothing", vitals.current(&"devil"), 9)
	vitals.set_to(&"devil", 1)
	_swing()
	_swing()
	equal("an empty pool ends the form",
		[vitals.current(&"devil"), _stacks(&"status/fixture_moves_blade")], [0, 0])


func _the_follower(follower: PartyFollower, mate: ActionLoadout) -> void:
	follower.rng.seed = 3
	follower.think_every = 1000.0
	mate.field_brain = _brain(_base_first)
	PowerUse.use(Combatant.of(follower), _blade, [], _rng, NOON)
	_foe.global_position = Vector3(0.0, 0.0, -4.0)
	follower.global_position = Vector3(0.0, 0.0, -3.0)
	follower.follow(DT)
	equal("a follower in a form, told to open its chain, swings the form's chain",
		[follower.timeline.move == _form_first, _stacks_on(follower, &"status/fixture_moves_blade")], [true, 1])


# Starts one swing from standing, and lets it be told to the kit.
func _swing() -> void:
	_fighter.timeline.cancel()
	_fighter.drive(DT, true, false)


func _use(power: Power) -> bool:
	return PowerUse.use(Combatant.of(_player), power, [], _rng, NOON)


func _stacks(id: StringName) -> int:
	return _stacks_on(_player, id)


func _stacks_on(body: Node, id: StringName) -> int:
	return StatusSet.of(body).stacks(id)


func _kit() -> PowerKit:
	var blade := FormMechanism.new()
	blade.status = _status(&"status/fixture_moves_blade")
	blade.exclusive_group = &"style"
	blade.attack_chain = [_form_first]
	blade.dodge = _form_dodge
	blade.drain_pool = &"devil"
	blade.drain_per_action = 0.5
	var stage_one := FormMechanism.new()
	stage_one.status = _status(&"status/fixture_moves_sword_1")
	stage_one.attack_chain = [_stage_first]
	var stage_two := FormMechanism.new()
	stage_two.status = _status(&"status/fixture_moves_sword_2")
	var swords := FormMechanism.new()
	swords.cycle = [stage_one, stage_two]
	swords.exclusive_group = &"style"
	swords.attack_chain = [_cycle_first]
	_blade = _power(&"power/fixture_moves_blade", blade)
	_swords = _power(&"power/fixture_moves_swords", swords)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_moves"
	kit.name_key = "fixture.kit"
	kit.powers = [_blade, _swords]
	return kit


func _power(id: StringName, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _loadout(id: StringName, kit: PowerKit) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_devil": 100.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [_base_first]
	made.moves.dodge = _base_dodge
	return made


func _brain(opener: ActionMove) -> ActionBrain:
	var made := ActionBrain.new()
	made.aggro_radius = 6.0
	made.give_up_radius = 10.0
	made.leash_radius = 6.0
	made.attack_range = 1.6
	made.attack_cooldown = 1.0
	made.wander_radius = 0.0
	var entry := ActionBrainEntry.new()
	entry.move = opener
	made.moves.append(entry)
	return made


func _move(startup: float, active: float, recovery: float, chain_after: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = startup
	made.active = active
	made.recovery = recovery
	made.chain_after = chain_after
	made.power = 4.0
	return made


func _enemy() -> Node3D:
	var actor := Node3D.new()
	actor.position = Vector3(0.0, 0.0, -40.0)
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = &"fixture_moves_foe"
	combatant.faction = &"enemy"
	combatant.base_stats = {&"max_hp": 50.0, &"defence": 1.0}
	actor.add_child(combatant)
	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	actor.add_child(hurtbox)
	attach(actor)
	return actor
