extends TestCase
## Grabs and throws (C8.8b): a landed grab holds its victim and starts the throw on the
## attacker's clock; the held victim follows its holder; the throw lands once the moment it is
## live, wherever its box is, and lets go; a holder interrupted before the throw lets go with
## no hit; a fighter that does not flinch is hit but not held; a held victim is not grabbed
## again; and a throw that does not strike, or grabs again, is a problem.
##
## OWNS: assertions about `Grab`, and the grab path through `Hitbox` and `Hurtbox`.
## MUST NOT: name a game's fighters or moves, or wait for physics frames.

var _actors: Array[Node] = []


func run() -> void:
	plan(9)
	SaveFixture.activate()
	Flags.clear_all()
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, 0.0)
	var foe := _actor(&"fixture_foe", &"side_b", Vector3(0, 0, -1), 0.0)
	_hold_and_throw(hero, foe)
	_interrupted(hero, foe)
	_refusals(hero, foe)
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


func _swing(startup: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = startup
	made.active = 0.2
	made.recovery = 0.2
	made.power = 5.0
	return made


func _grab() -> ActionMove:
	var made := _swing(0.0)
	made.throw_move = _swing(0.3)
	return made


func _hp(actor: Node) -> int:
	return Vitals.of(actor).current(&"hp")


# The hero swings `move` on a new clock and strikes `foe` with it. Returns the clock.
func _strike(hero: Node3D, foe: Node3D, move: ActionMove) -> MoveTimeline:
	var clock := MoveTimeline.new()
	var hitbox := hero.get_child(4) as Hitbox
	hitbox.timeline = clock
	clock.start(move)
	clock.step(0.05)
	hitbox.strike(foe.get_child(3) as Hurtbox)
	return clock


func _hold_and_throw(hero: Node3D, foe: Node3D) -> void:
	var own := MoveTimeline.new()
	(foe.get_child(3) as Hurtbox).timeline = own
	own.start(_swing(0.0))
	var grab := _grab()
	var clock := _strike(hero, foe, grab)
	equal("a landed grab holds the victim and starts the throw",
		[Grab.held(foe), clock.move == grab.throw_move, clock.phase], [true, true, MoveTimeline.Phase.STARTUP])
	equal("and the victim drops its own swing", own.busy(), false)
	hero.position = Vector3(3, 0, 0)
	var held: Grab = Grab.of(foe)
	held.pass_time()
	equal("the held victim follows its holder", foe.position, Vector3(3, 0, -1))
	var before: int = _hp(foe)
	clock.step(0.31)
	held.pass_time()
	equal("the throw lands the moment it is live, and lets go", [_hp(foe) < before, Grab.held(foe)], [true, false])
	var after: int = _hp(foe)
	(hero.get_child(4) as Hitbox).strike(foe.get_child(3) as Hurtbox)
	equal("and it lands only once", _hp(foe), after)


func _interrupted(hero: Node3D, foe: Node3D) -> void:
	var clock := _strike(hero, foe, _grab())
	var before: int = _hp(foe)
	clock.cancel()
	Grab.of(foe).pass_time()
	equal("a holder interrupted before the throw lets go with no hit", [Grab.held(foe), _hp(foe)], [false, before])


func _refusals(hero: Node3D, foe: Node3D) -> void:
	var rock := _actor(&"fixture_rock", &"side_b", Vector3(0, 0, -2), -1.0)
	var before: int = _hp(rock)
	_strike(hero, rock, _grab())
	equal("a fighter that does not flinch is hit but not held", [_hp(rock) < before, Grab.held(rock)], [true, false])
	_strike(hero, foe, _grab())
	var other := _actor(&"fixture_ally", &"side_a", Vector3(1, 0, -1), 0.0)
	var second := _strike(other, foe, _grab())
	equal("a held victim is not grabbed by a second fighter", second.move.throw_move != null, true)
	var bad := _grab()
	bad.throw_move.power = 0.0
	var worse := _grab()
	worse.throw_move.throw_move = _swing(0.0)
	equal("a throw that does not strike, or grabs again, is a problem",
		[bad.problems("x").size(), worse.problems("x").size()], [1, 1])
