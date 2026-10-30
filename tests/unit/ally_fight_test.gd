extends TestCase
## Allies that fight in the field (C4.9): a party follower whose loadout has a `field_brain`
## chases a foe it notices, swings its member's attack chain through its own hitbox, waits its
## cooldown, keeps a leash on its place in the line, reels from a knockback, and walks back into
## line when the fight is over. One without a field brain only follows.
##
## OWNS: assertions about `PartyFollower`'s fighting, `ActionLoadout.field_brain` and
## `Hurtbox.nearest_hostile`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

const DT: float = 0.05

var _player: PlayerController
var _lead: ActionLoadout
var _mate: ActionLoadout
var _follower: PartyFollower
var _foe: Node3D
var _first: ActionMove
var _second: ActionMove


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	_lead = _loadout(&"fixture_lead")
	_mate = _loadout(&"fixture_mate")
	_first = _move(0.1, 0.1, 0.3, 0.1)
	_second = _move(0.1, 0.1, 0.3, 0.0)
	_mate.moves.attack_chain = [_first, _second]
	_lead.companions = [_mate]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_player.global_position = Vector3.ZERO
	ActionHost.equip(_player, _lead)
	_follower = FieldParty.spawn(_player, _lead)[0]
	_follower.rng.seed = 3
	# It thinks no command in this test: no gauge, and a think far off.
	_follower.think_every = 1000.0
	_foe = _actor(&"fixture_foe", Vector3(0.0, 0.0, -4.0))
	_without_a_brain()
	_chasing_and_swinging()
	_leash_and_return()
	_reeling_and_switching()
	for follower: PartyFollower in FieldParty.followers(_player):
		follower.free()
	_player.free()
	_foe.free()
	CombatClock.reset()
	Flags.clear_all()


func _without_a_brain() -> void:
	equal("the target is the nearest standing foe, never an ally",
		Hurtbox.nearest_hostile(_follower).fighter().combatant_id, &"fixture_foe")
	_follower.global_position = Vector3(0.0, 0.0, 3.0)
	_follower.follow(DT)
	equal("with no field brain it only keeps its place, though a foe is near",
		[_follower.velocity.z < 0.0, _follower.timeline.busy(), _follower.decider == null], [true, false, true])
	var broken := ActionBrain.new()
	_mate.field_brain = broken
	equal("a field brain's problems are the loadout's", _mate.problems("x").size() > 0, true)
	_mate.field_brain = _brain([_first])


func _chasing_and_swinging() -> void:
	_follower.global_position = Vector3(0.0, 0.0, 1.0)
	_follower.follow(DT)
	equal("a foe within its aggro radius is chased",
		[_follower.decider.state, _follower.velocity.z < 0.0, _follower.facing.z < 0.0],
		[ActionDecider.State.CHASE, true, true])
	_follower.global_position = Vector3(0.0, 0.0, -3.0)
	_follower.follow(DT)
	equal("in reach, it opens its attack chain",
		[_follower.decider.state, _follower.timeline.move == _first, _follower.timeline.chain_index],
		[ActionDecider.State.ATTACK, true, 0])
	var swung: Array[ActionMove] = []
	var struck: bool = false
	# The two swings take 0.8 s of fight time: 20 frames see the chain through.
	for i: int in 20:
		_follower.follow(DT)
		if not swung.has(_follower.timeline.move) and _follower.timeline.move != null:
			swung.append(_follower.timeline.move)
		if _follower.timeline.is_hitting() and not struck:
			struck = _hitbox().strike(_foe.get_node(^"Hurtbox") as Hurtbox)
	equal("it presses on through the whole chain, and its hitbox strikes as its member",
		[swung, struck, _hp() < 50, _hitbox().attacker == Combatant.of(_follower)], [[_first, _second], true, true, true])
	equal("after the chain it stands and waits out its cooldown, not starting again",
		[_follower.timeline.busy(), _follower.decider.state, _follower.velocity.length()],
		[false, ActionDecider.State.CHASE, 0.0])
	var lunge := _move(0.1, 0.1, 0.1, 0.0)
	_mate.field_brain = _brain([lunge])
	_follower.follow(DT)
	equal("a move that does not open the chain plays alone", [_follower.timeline.move == lunge,
		_follower.timeline.chain_index], [true, -1])


func _leash_and_return() -> void:
	# A new brain is a fresh mind: the lunge in progress is dropped.
	_mate.field_brain = _brain([_first])
	_foe.global_position = Vector3(0.0, 0.0, -9.0)
	_follower.global_position = Vector3(0.0, 0.0, -8.0)
	_follower.follow(DT)
	equal("strayed past its leash from its place in the line, it walks back, ignoring the foe",
		[_follower.decider.state, _follower.velocity.z > 0.0], [ActionDecider.State.RETURN, true])
	_foe.global_position = Vector3(0.0, 0.0, -40.0)
	_follower.global_position = Vector3(0.0, 0.0, 4.0)
	_follower.follow(DT)
	equal("with no foe in sight it falls back into line",
		[_follower.velocity.z < 0.0, _follower.timeline.busy()], [true, false])


func _reeling_and_switching() -> void:
	_foe.global_position = Vector3(0.0, 0.0, -1.0)
	_follower.global_position = Vector3.ZERO
	_follower.decider = null
	_follower.follow(DT)
	Events.knockback_requested.emit(Combatant.of(_follower).combatant_id, Vector3(0.0, 0.0, 1.0))
	_follower.follow(DT)
	equal("a knockback drops its swing and pushes it back",
		[_follower.timeline.busy(), _follower.decider.state, _follower.velocity.z > 0.0],
		[false, ActionDecider.State.STAGGERED, true])
	CombatClock.set_scale(0.0)
	_follower.follow(DT)
	equal("a stopped fight holds it still", _follower.velocity.length(), 0.0)
	CombatClock.reset()
	FieldParty.switch(_player)
	_follower.global_position = Vector3(0.0, 0.0, 4.0)
	_player.global_position = Vector3.ZERO
	_follower.follow(DT)
	equal("after a switch the body is the lead, who has no field brain, so it only follows",
		[_follower.decider == null, _follower.timeline.busy(), _follower.velocity.z < 0.0], [true, false, true])


func _brain(openers: Array[ActionMove]) -> ActionBrain:
	var made := ActionBrain.new()
	made.aggro_radius = 6.0
	made.give_up_radius = 10.0
	made.leash_radius = 6.0
	made.attack_range = 1.6
	made.attack_cooldown = 1.0
	made.wander_radius = 0.0
	for move: ActionMove in openers:
		var entry := ActionBrainEntry.new()
		entry.move = move
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


func _loadout(id: StringName) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made


func _actor(id: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = &"enemy"
	combatant.base_stats = {&"max_hp": 50.0, &"defence": 1.0}
	actor.add_child(combatant)
	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	actor.add_child(hurtbox)
	attach(actor)
	return actor


func _hp() -> int:
	return Vitals.of(_foe).current(&"hp")


func _hitbox() -> Hitbox:
	for child: Node in _follower.get_children():
		if child is Hitbox:
			return child as Hitbox
	return null
