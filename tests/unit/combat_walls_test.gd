extends TestCase
## Walls (C9.12). A swing strikes a foe in the open but not one behind a wall, and a breakable
## thing behind a wall is not struck either; a shot stops at a wall, says it landed there and
## leaves the foe behind untouched; a blink stops short of a wall, and a swap across one moves
## nobody; a shot fired from a move event never starts behind a wall; a field command and a
## power finding its own foe never aim through a wall; a step at a floor's edge is a drop.
##
## Each case has its own lane along x, so one lane's wall never stands in another's way. Walls
## are added where they stay: the physics space sees a new body at once, but a moved one only
## after a physics step, and nothing here awaits one.
##
## OWNS: assertions about `CombatSight` and the wall checks in `Hitbox`, `Projectile`,
## `BlinkRun` and `MoveEvents`.
## MUST NOT: name a game's fighters, kits or moves.

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _landed: Array[Vector3] = []


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 12
	_world = Node3D.new()
	attach(_world)
	_sight()
	_swings()
	_shots()
	_blinks()
	_world.free()
	Flags.clear_all()


func _sight() -> void:
	_wall(Vector3(-20, 0, -2))
	var from := Vector3(-20, 0.8, 0)
	var hit: Vector3 = CombatSight.wall_between(_world, from, Vector3(-20, 0.8, -4))
	var open: Vector3 = CombatSight.wall_between(_world, Vector3(-25, 0.8, 0), Vector3(-25, 0.8, -4))
	var short: Vector3 = CombatSight.short_of(_world, from, Vector3(-20, 0.8, -4))
	equal("a ray finds the wall's near face, a clear line finds nothing, and short_of stops before it",
		[snappedf(hit.z, 0.01), open.is_finite(), snappedf(short.z, 0.01)], [-1.75, false, -1.35])
	_floor(Vector3(-30, 0, 0))
	var on := Node3D.new()
	on.position = Vector3(-30, 0, 0)
	_world.add_child(on)
	var safe: bool = CombatSight.drop_ahead(on, Vector3.FORWARD)
	on.position = Vector3(-30, 0, -0.8)
	equal("a step forward on the floor is safe, and one at its edge would drop",
		[safe, CombatSight.drop_ahead(on, Vector3.FORWARD), CombatSight.drop_ahead(on, Vector3.BACK)],
		[false, true, false])


func _swings() -> void:
	var me: Combatant = _fighter(&"fixture_walls_me", &"side_a", Vector3(0, 0, 0))
	var open: Combatant = _fighter(&"fixture_walls_open", &"side_b", Vector3(0, 0, -1.5))
	var hitbox: Hitbox = _swinger(me)
	var struck: bool = hitbox.strike(_hurtbox(open.get_parent()))
	var walled: Combatant = _fighter(&"fixture_walls_walled", &"side_b", Vector3(5, 0, -1.5))
	(me.get_parent() as Node3D).global_position = Vector3(5, 0, 0)
	_wall(Vector3(5, 0, -0.75))
	hitbox.timeline.start(_move(10.0, 0.2))
	hitbox.timeline.step(0.01)
	var live: bool = hitbox.timeline.is_hitting()
	var through: bool = hitbox.strike(_hurtbox(walled.get_parent()))
	equal("a swing strikes a foe in the open, and not one behind a wall",
		[struck, _hp(open) < 100, live, through, _hp(walled)], [true, true, true, false, 100])
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	var behind_me: Combatant = _fighter(&"fixture_walls_behind", &"side_b", Vector3(5, 0, 3))
	var aimable: Array[Combatant] = FieldCommands.candidates(me, command)
	equal("a field command never aims at a foe behind a wall, and a power finding its own foe skips one",
		[aimable.has(behind_me), aimable.has(walled), BarrageRun.aim_of(me, []) == null], [true, false, true])
	var thing := build("res://scenes/objects/arena_thing.tscn") as ArenaThing
	thing.name = "fixture_walls_thing"
	thing.hp = 5.0
	thing.position = Vector3(5, 0, -1.2)
	_world.add_child(thing)
	var thing_box: Hurtbox = _hurtbox(thing)
	equal("a breakable thing behind a wall is not struck",
		[hitbox.strike(thing_box), thing.is_queued_for_deletion()], [false, false])


func _shots() -> void:
	var me: Combatant = _fighter(&"fixture_walls_shooter", &"side_a", Vector3(10, 0, 0))
	var foe: Combatant = _fighter(&"fixture_walls_target", &"side_b", Vector3(10, 0, -6))
	_wall(Vector3(10, 0, -3))
	var shot := Projectile.new()
	shot.attacker = me
	shot.rng = _rng
	shot.speed = 10.0
	shot.launch(_move(10.0, 2.0))
	shot.landed.connect(_on_landed)
	_world.add_child(shot)
	shot.global_position = Vector3(10, 0.8, -0.5)
	shot.direction = Vector3.FORWARD
	for i: int in 10:
		shot.fly(0.1)
	var at: Vector3 = _landed[0] if _landed.size() == 1 else Vector3.INF
	equal("a shot stops at a wall, says it landed there, and the foe behind is untouched",
		[shot.gone(), snappedf(at.z, 0.01), _hp(foe)], [true, -2.75, 100])


func _blinks() -> void:
	var me: Combatant = _fighter(&"fixture_walls_blinker", &"side_a", Vector3(15, 0, 0))
	var foe: Combatant = _fighter(&"fixture_walls_across", &"side_b", Vector3(15, 0, -6))
	var body: Node3D = me.get_parent() as Node3D
	body.look_at(Vector3(15, 0, -1), Vector3.UP)
	_wall(Vector3(15, 0, -3))
	var forward := BlinkMechanism.new()
	forward.to = BlinkMechanism.To.FORWARD
	forward.distance = 6.0
	PowerMechanisms.make(forward).use(me, [], _rng)
	var stopped: Vector3 = body.global_position
	body.global_position = Vector3(15, 0, 0)
	var swap := BlinkMechanism.new()
	swap.to = BlinkMechanism.To.SWAP
	PowerMechanisms.make(swap).use(me, [foe], _rng)
	var shooter: Combatant = _fighter(&"fixture_walls_caster", &"side_a", Vector3(20, 0, 0))
	var caster: Node3D = shooter.get_parent() as Node3D
	caster.look_at(Vector3(20, 0, -1), Vector3.UP)
	_wall(Vector3(20, 0, -1))
	var events := MoveEvents.new()
	caster.add_child(events)
	var event := MoveEvent.new()
	event.kind = MoveEvent.Kind.SHOT
	event.shot = _move(1.0, 1.0)
	event.offset = Vector3(0, 0.8, -3)
	var firing: ActionMove = _move(0.0, 0.5)
	firing.events = [event]
	var clock := MoveTimeline.new()
	_hurtbox(caster).timeline = clock
	clock.start(firing)
	events.watch()
	var spawned: Projectile = null
	for child: Node in _world.get_children():
		if child is Projectile and child != null and not (child as Projectile).gone():
			spawned = child as Projectile
	equal("a blink stops short of a wall, and a swap across one moves nobody",
		[snappedf(stopped.z, 0.01), body.global_position.is_equal_approx(Vector3(15, 0, 0)),
			(foe.get_parent() as Node3D).global_position.is_equal_approx(Vector3(15, 0, -6))],
		[-2.35, true, true])
	equal("a shot from a move event starts this side of the wall",
		[spawned != null, spawned != null and spawned.global_position.z > -0.75], [true, true])


# A wall 4 m wide, 3 m tall and 0.5 m deep, standing on the ground at `at`, on the world layer.
func _wall(at: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 1.5, 0)
	wall.add_child(shape)
	wall.position = at
	_world.add_child(wall)


# A floor 2 m square whose top is at `at`.
func _floor(at: Vector3) -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 1, 2)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	ground.position = at
	_world.add_child(ground)


func _swinger(me: Combatant) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.attacker = me
	hitbox.rng = _rng
	hitbox.timeline = MoveTimeline.new()
	me.get_parent().add_child(hitbox)
	hitbox.timeline.start(_move(10.0, 0.2))
	hitbox.timeline.step(0.01)
	return hitbox


func _move(power: float, active: float) -> ActionMove:
	var move := ActionMove.new()
	move.startup = 0.0
	move.active = active
	move.recovery = 0.1
	move.power = power
	move.hitbox_size = Vector3(1, 1, 1)
	move.hitbox_offset = Vector3.ZERO
	return move


func _fighter(id: StringName, side: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 10.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 100)
	return fighter


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _on_landed(at: Vector3) -> void:
	_landed.append(at)
