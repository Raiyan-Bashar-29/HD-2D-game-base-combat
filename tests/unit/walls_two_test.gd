extends TestCase
## Walls and ledges, part 2 (C10.15): a field foe does not see a fighter behind a wall unless it
## has threat on it; a blink from solid ground lands on the last floor before a ledge; a wall
## raised where a fighter stands is pushed clear of it.
##
## OWNS: assertions about `Aggro.pick`'s sight, `CombatSight.last_floor` through `BlinkRun`, and
## `ConstructRun`'s clearing.
## MUST NOT: name a game's fighters or kits, or wait for physics. Bodies are added where they
## stay, so the space sees them at once.

var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	_sight()
	_blink_floor()
	_construct()
	_world.free()
	Flags.clear_all()


func _sight() -> void:
	var hero: Combatant = _fighter(&"fixture_walls2_hero", &"side_a", Vector3(0, 0, -4))
	_box(Vector3(0, 1.5, -2), Vector3(4, 3, 0.5))
	var blind: ActionEnemy = _enemy(&"fixture_walls2_blind", Vector3.ZERO)
	var clear: ActionEnemy = _enemy(&"fixture_walls2_clear", Vector3(5, 0, 0))
	var hidden: Hurtbox = Aggro.pick(blind)
	var seen: Hurtbox = Aggro.pick(clear)
	Aggro.of(blind).threat[hero.combatant_id] = 3.0
	equal("a foe does not see a fighter behind a wall, another with a clear line does, and threat finds it",
		[hidden, seen != null and seen.fighter() == hero, Aggro.pick(blind) != null], [null, true, true])


func _blink_floor() -> void:
	_box(Vector3(30, -0.5, 0), Vector3(2, 1, 2))
	var me: Combatant = _fighter(&"fixture_walls2_blinker", &"side_a", Vector3(30, 0, 0))
	var body: Node3D = me.get_parent() as Node3D
	body.look_at(Vector3(30, 0, -1), Vector3.UP)
	var forward := BlinkMechanism.new()
	forward.to = BlinkMechanism.To.FORWARD
	forward.distance = 4.0
	PowerMechanisms.make(forward).use(me, [], _rng)
	equal("a blink toward a ledge lands on the last floor, not in the air",
		[body.global_position.z < 0.0, body.global_position.z >= -1.0], [true, true])
	var floating: Combatant = _fighter(&"fixture_walls2_floating", &"side_a", Vector3(50, 0, 0))
	(floating.get_parent() as Node3D).look_at(Vector3(50, 0, -1), Vector3.UP)
	PowerMechanisms.make(forward).use(floating, [], _rng)
	equal("one that starts in the air goes its whole way", (floating.get_parent() as Node3D).global_position.z, -4.0)


func _construct() -> void:
	var build := ConstructMechanism.new()
	build.lifetime = 5.0
	var power := Power.new()
	power.power_id = &"power/fixture_walls2_wall"
	power.name_key = "fixture.power"
	power.mechanism = build
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_walls2"
	kit.powers = [power]
	var me: Combatant = _fighter(&"fixture_walls2_builder", &"side_a", Vector3(40, 0, 0))
	(me.get_parent() as Node3D).look_at(Vector3(40, 0, -1), Vector3.UP)
	var powers := PowerSet.new()
	me.get_parent().add_child(powers)
	powers.equip(kit)
	_fighter(&"fixture_walls2_in_the_way", &"side_b", Vector3(40, 0, -1.5))
	PowerUse.use(me, power, [], _rng)
	var raised: Array[Vector3] = []
	for child: Node in _world.get_children():
		if child is ArenaThing:
			raised.append((child as Node3D).global_position)
	equal("a wall raised where a fighter stands is pushed on until it is clear", raised, [Vector3(40, 0, -2.5)] as Array[Vector3])


func _box(at: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = at
	_world.add_child(wall)


func _fighter(id: StringName, side: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = side
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 30.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	return fighter


func _enemy(id: StringName, at: Vector3) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 50.0}
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = ActionBrain.new()
	made.position = at
	_world.add_child(made)
	return made
