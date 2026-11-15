extends TestCase
## Things in the arena (C8.9). A thing can be hit by anyone but is never chosen as a target.
## A hit that leaves it hp does nothing more. An explosive whose hp is gone bursts where it
## stands, hurting friend and foe of whoever broke it, breaks the next thing too, and is then
## gone. A throwable that is struck flies away from the striker as that fighter's shot.
##
## OWNS: assertions about `ArenaThing`.
## MUST NOT: name a game's things or fighters, or wait for physics: a blast and a shot are
## stepped by hand and struck against a hurtbox directly.

var _world: Node3D
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(7)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 5
	_world = Node3D.new()
	attach(_world)
	_explosive()
	_throwable()
	_world.free()
	Flags.clear_all()


func _explosive() -> void:
	var hero: Combatant = _fighter(&"fixture_thing_hero", &"side_a", Vector3(0, 0, 2))
	var friend: Combatant = _fighter(&"fixture_thing_friend", &"side_a", Vector3(1, 0, 0))
	var foe: Combatant = _fighter(&"fixture_thing_foe", &"side_b", Vector3(-1, 0, 0))
	var keg: ArenaThing = _thing("FixtureKeg", Vector3.ZERO, 50.0)
	keg.burst = _move(40.0)
	var next: ArenaThing = _thing("FixtureKegNext", Vector3(0, 0, -1), 1.0)
	next.burst = _move(40.0)
	var me: Combatant = Combatant.of(keg)
	equal("a thing can be hit by anyone, yet nobody looks for it as a target",
		[hero.can_target(me, FactionTable.Target.ENEMY), foe.can_target(me, FactionTable.Target.ENEMY),
			Hurtbox.nearest_hostile(hero.get_parent() as Node3D).fighter(), _hp(me)],
		[true, true, foe, 50])
	hero.hit(me, 1.0, &"", _rng, true)
	equal("a hit that leaves it hp sets nothing off", [_hp(me) < 50, _blasts().size()], [true, 0])
	Vitals.of(keg).set_to(&"hp", 1)
	hero.hit(me, 100.0, &"", _rng, true)
	var blasts: Array[Planted] = _blasts()
	equal("its hp gone, it bursts where it stands", [blasts.size(), keg.visible], [1, false])
	blasts[0].watch(0.01)
	blasts[0].watch(0.06)
	var struck: Array = [blasts[0].strike(_hurtbox(friend.get_parent())), blasts[0].strike(_hurtbox(foe.get_parent())),
		blasts[0].strike(_hurtbox(next))]
	equal("the burst hurts friend and foe of whoever broke it, and breaks the next thing, which bursts too",
		[struck, _hp(friend) < 500, _hp(foe) < 500, _blasts().size()], [[true, true, true], true, true, 2])
	for i: int in 10:
		blasts[0].watch(0.1)
	keg._physics_process(0.0)
	equal("the blast over, the thing is on its way out", [blasts[0].gone(), keg.is_queued_for_deletion()], [true, true])


func _throwable() -> void:
	var hero: Combatant = _fighter(&"fixture_throw_hero", &"side_c", Vector3(100, 0, 2))
	var foe: Combatant = _fighter(&"fixture_throw_foe", &"side_d", Vector3(100, 0, -6))
	var rock: ArenaThing = _thing("FixtureRock", Vector3(100, 0, 0), 500.0)
	rock.thrown = _move(40.0)
	hero.hit(Combatant.of(rock), 1.0, &"", _rng, true)
	var shots: Array[Node] = get_tree().get_nodes_in_group(Projectile.GROUP)
	var shot: Projectile = shots[0] as Projectile if shots.size() == 1 else null
	equal("struck, a throwable flies away from the striker as that fighter's shot",
		[shot != null, shot.attacker if shot != null else null, shot.direction if shot != null else Vector3.ZERO,
			rock.is_queued_for_deletion()],
		[true, hero, Vector3(0, 0, -1), true])
	shot.fly(0.01)
	shot.fly(0.06)
	equal("the shot hits a foe of the striker in its way",
		[shot.strike(_hurtbox(foe.get_parent())), _hp(foe) < 500], [true, true])


func _blasts() -> Array[Planted]:
	var found: Array[Planted] = []
	for node: Node in get_tree().get_nodes_in_group(Planted.GROUP):
		if not node.is_queued_for_deletion():
			found.append(node as Planted)
	return found


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")


func _move(power: float) -> ActionMove:
	var made := ActionMove.new()
	made.id = &"move/fixture_thing_burst"
	made.name_key = "ui.cancel"
	made.startup = 0.05
	made.active = 0.3
	made.recovery = 0.1
	made.power = power
	made.hitbox_size = Vector3(4, 2, 4)
	made.hitbox_offset = Vector3.ZERO
	return made


func _thing(called: String, at: Vector3, hp: float) -> ArenaThing:
	var made := build("res://scenes/objects/arena_thing.tscn") as ArenaThing
	made.name = called
	made.hp = hp
	made.position = at
	_world.add_child(made)
	return made


func _fighter(id: StringName, side: StringName, at: Vector3) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	_world.add_child(actor)
	return combatant
