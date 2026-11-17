extends TestCase
## Launch and juggle (C8.8a): a launching hit puts its victim in the air for the move's
## `launch` seconds and drops the victim's swing; a plain hit on a grounded fighter does not;
## a hit in the air keeps the victim up longer, each worth less than the one before; time
## passing lands it and starts the count again; a fighter that does not flinch is not
## launched; a solid body is thrown upward; a field foe in the air cannot act; and a landed
## hit tells the attacker's clock, so a `cancel_on_hit` swing goes straight into the next.
##
## OWNS: assertions about `Juggle`, and the launch path through `Hurtbox` and `Hitbox`.
## MUST NOT: name a game's fighters or moves, or wait for physics frames.

var _actors: Array[Node] = []


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, 0.0)
	var foe := _actor(&"fixture_foe", &"side_b", Vector3(0, 0, -1), 0.0)
	_launching(hero, foe)
	_juggling(hero, foe)
	_no_flinch(hero)
	_a_solid_body(hero)
	_cancel_on_hit(hero, foe)
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _actor(id: StringName, side: StringName, at: Vector3, flinch: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0, &"knockback_taken": flinch}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	actor.add_child(Hitbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _swing(launch: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.2
	made.recovery = 0.4
	made.chain_after = 0.4
	made.power = 5.0
	made.launch = launch
	return made


func _hit(by: Node, on: Node, move: ActionMove) -> void:
	var rng := RandomNumberGenerator.new()
	(on.get_child(3) as Hurtbox).take(Combatant.of(by), move, rng, (by as Node3D).global_position)


func _launching(hero: Node3D, foe: Node3D) -> void:
	var clock := MoveTimeline.new()
	(foe.get_child(3) as Hurtbox).timeline = clock
	_hit(hero, foe, _swing(0.0))
	equal("a plain hit on a grounded fighter launches nothing", Juggle.airborne(foe), false)
	clock.start(_swing(0.0))
	_hit(hero, foe, _swing(0.8))
	var juggle: Juggle = Juggle.of(foe)
	equal("a launching hit puts it in the air for the move's launch time",
		[Juggle.airborne(foe), juggle.left, juggle.count], [true, 0.8, 1])
	equal("and drops the swing it was in", clock.busy(), false)


func _juggling(hero: Node3D, foe: Node3D) -> void:
	var juggle: Juggle = Juggle.of(foe)
	_hit(hero, foe, _swing(0.0))
	equal("a plain hit in the air keeps it up: 0.25 s times 0.7",
		[is_equal_approx(juggle.left, 0.975), juggle.count], [true, 2])
	_hit(hero, foe, _swing(0.8))
	equal("a second launcher adds its time at 0.7 squared",
		[is_equal_approx(juggle.left, 0.975 + 0.8 * 0.49), juggle.count], [true, 3])
	juggle.pass_time(1.0)
	equal("time passing brings it nearer the ground", [Juggle.airborne(foe), juggle.count], [true, 3])
	juggle.pass_time(1.0)
	equal("and once landed the count starts again", [Juggle.airborne(foe), juggle.left, juggle.count],
		[false, 0.0, 0])


func _no_flinch(hero: Node3D) -> void:
	var rock := _actor(&"fixture_rock", &"side_b", Vector3(0, 0, -2), -1.0)
	_hit(hero, rock, _swing(0.8))
	equal("a fighter that does not flinch is not launched", [Juggle.airborne(rock), Juggle.of(rock)],
		[false, null])


func _a_solid_body(hero: Node3D) -> void:
	var enemy := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_brute"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 200.0}
	enemy.fighter = def
	enemy.brain = ActionBrain.new()
	attach(enemy)
	for child: Node in enemy.get_children():
		if child is Hurtbox:
			(child as Hurtbox).take(Combatant.of(hero), _swing(1.0), RandomNumberGenerator.new(), Vector3.ZERO)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	equal("a solid body is thrown up fast enough to fall back in that time",
		[Juggle.airborne(enemy), is_equal_approx(enemy.velocity.y, gravity * 0.5)], [true, true])
	equal("and a foe in the air does not act", enemy.act(0.1) != ActionDecider.State.ATTACK, true)
	enemy.free()


func _cancel_on_hit(hero: Node3D, foe: Node3D) -> void:
	var first := _swing(0.0)
	first.cancel_on_hit = true
	var chain: Array[ActionMove] = [first, _swing(0.0)]
	var clock := MoveTimeline.new()
	var hitbox := hero.get_child(4) as Hitbox
	hitbox.timeline = clock
	clock.press(chain)
	clock.step(0.05)
	hitbox.strike(foe.get_child(3) as Hurtbox)
	equal("a landed hit lets a cancel-on-hit swing go straight into the next",
		[clock.press(chain), clock.chain_index], [true, 1])
