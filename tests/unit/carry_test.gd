extends TestCase
## Carrying a thing (C8.18b). A `carryable` thing offers a pick-up prompt; taking it lifts it
## overhead, where it follows the carrier and cannot be struck. A second pick-up is refused with
## "hands full". The attack button throws it the way the carrier faces, as the carrier's shot,
## and a carrier who falls sets it down.
##
## OWNS: assertions about `CarryPoint` and `Carried`.
## MUST NOT: name a game's things or fighters, or wait for physics: the holder is stepped by hand.

var _world: Node3D


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	_world = Node3D.new()
	attach(_world)
	var hero: Node3D = _fighter(&"fixture_carry_hero", &"side_e", Vector3(200, 0, 0))
	var rock: ArenaThing = _thing("FixtureCarryRock", Vector3(200, 0, -1))
	var spare: ArenaThing = _thing("FixtureCarrySpare", Vector3(201, 0, -1))
	var point: CarryPoint = _point(rock)
	equal("a carryable thing offers a pick-up prompt",
		[point != null, point.is_offerable() if point != null else false,
			point.refusal(hero) if point != null else -1],
		[true, true, GameEnums.RefusalReason.NONE])
	point.perform(hero)
	hero.position = Vector3(203, 0, 0)
	Carried.of(hero)._physics_process(0.1)
	var hurtbox: Hurtbox = _hurtbox(rock)
	equal("taken, it is held overhead, follows the carrier, and cannot be struck or offered",
		[Carried.of(hero) != null, rock.global_position, hurtbox.is_in_group(Hurtbox.GROUP),
			point.is_offerable()],
		[true, Vector3(203, 0, 0) + Carried.HOLD, false, false])
	equal("a second pick-up is refused: hands full",
		[_point(spare).refusal(hero), Carried.lift(hero, spare)],
		[GameEnums.RefusalReason.HANDS_FULL, false])
	equal("thrown, it flies the way the carrier faces as the carrier's shot",
		[Carried.throw(hero, Vector3(1, 0, 0)), Carried.of(hero), _shot_by(Combatant.of(hero)),
			rock.is_queued_for_deletion()],
		[true, null, Vector3(1, 0, 0), true])
	Carried.lift(hero, spare)
	Vitals.of(hero).set_to(&"hp", 0)
	Carried.of(hero)._physics_process(0.1)
	equal("a carrier who falls sets it down, and it can be struck and taken again",
		[Carried.of(hero), _hurtbox(spare).is_in_group(Hurtbox.GROUP), _point(spare).is_offerable()],
		[null, true, true])
	equal("holding nothing, the attack button is not taken: no throw",
		Carried.throw(hero, Vector3.FORWARD), false)
	_world.free()
	Flags.clear_all()


func _shot_by(who: Combatant) -> Vector3:
	for node: Node in get_tree().get_nodes_in_group(Projectile.GROUP):
		var shot: Projectile = node as Projectile
		if shot != null and shot.attacker == who:
			return shot.direction
	return Vector3.ZERO


func _point(thing: Node) -> CarryPoint:
	for child: Node in thing.get_children():
		if child is CarryPoint:
			return child as CarryPoint
	return null


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _thing(called: String, at: Vector3) -> ArenaThing:
	var made := build("res://scenes/objects/arena_thing.tscn") as ArenaThing
	made.name = called
	made.hp = 50.0
	made.carryable = true
	made.label_key = "ui.cancel"
	var move := ActionMove.new()
	move.id = &"move/fixture_carry_throw"
	move.name_key = "ui.cancel"
	move.startup = 0.0
	move.active = 0.5
	move.power = 20.0
	made.thrown = move
	made.position = at
	_world.add_child(made)
	return made


func _fighter(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	Vitals.of(actor).set_to(&"hp", 500)
	return actor
