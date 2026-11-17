extends TestCase
## Prompts and interrupts (C8.8c). A prompt: the first attack press while a move plays is timed
## against the move's window and multiplies its power; a press outside it earns nothing and
## uses the press up; a move without a prompt earns nothing; the boost reaches the hit; and the
## next move starts at 1 again. An interrupt: a landed hit that interrupts stops a move that is
## winding up or armoured and stuns its user; an ordinary hit does not get through armour; and
## a fighter that never flinches is not interrupted.
##
## OWNS: assertions about `MoveTimeline.time_press`, and the interrupt path in `Hurtbox`.
## MUST NOT: name a game's fighters or moves, or wait for physics frames.

var _actors: Array[Node] = []
var _pushes: Array[Vector3] = []


func run() -> void:
	plan(10)
	SaveFixture.activate()
	Flags.clear_all()
	Events.knockback_requested.connect(_on_push)
	var hero := _actor(&"fixture_hero", &"side_a", Vector3.ZERO, 0.0)
	var foe := _actor(&"fixture_foe", &"side_b", Vector3(0, 0, -1), 0.0)
	_prompts(hero, foe)
	_interrupts(hero, foe)
	Events.knockback_requested.disconnect(_on_push)
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _on_push(_who: StringName, push: Vector3) -> void:
	_pushes.append(push)


func _actor(id: StringName, side: StringName, at: Vector3, flinch: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 5000.0, &"attack": 10.0, &"knockback_taken": flinch}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	actor.add_child(Hitbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _swing(timed: bool) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.3
	made.active = 0.2
	made.recovery = 0.2
	made.power = 20.0
	if timed:
		made.prompt = TimedWindow.new()
		made.prompt.opens = 0.2
		made.prompt.closes = 0.3
		made.prompt.bonus = 2.0
	return made


func _hp(actor: Node) -> int:
	return Vitals.of(actor).current(&"hp")


# The damage one live swing of `move` does to `foe`, after a press `at` seconds in (-1: none).
func _damage(hero: Node3D, foe: Node3D, move: ActionMove, at: float) -> int:
	var clock := MoveTimeline.new()
	var hitbox := hero.get_child(4) as Hitbox
	hitbox.timeline = clock
	clock.start(move)
	if at >= 0.0:
		clock.step(at)
		clock.time_press()
	clock.step(0.35 - maxf(at, 0.0))
	var before: int = _hp(foe)
	hitbox.strike(foe.get_child(3) as Hurtbox)
	return before - _hp(foe)


func _prompts(hero: Node3D, foe: Node3D) -> void:
	var clock := MoveTimeline.new()
	clock.start(_swing(true))
	clock.step(0.25)
	equal("a press inside the window earns its bonus", [clock.time_press(), clock.boost], [2.0, 2.0])
	clock.start(_swing(true))
	clock.step(0.05)
	equal("a press too early earns nothing", clock.time_press(), 1.0)
	clock.step(0.2)
	equal("and uses the one press up, so mashing misses", [clock.time_press(), clock.boost], [1.0, 1.0])
	clock.start(_swing(false))
	clock.step(0.25)
	equal("a move with no prompt earns nothing", clock.time_press(), 1.0)
	var plain: int = _damage(hero, foe, _swing(true), -1.0)
	var timed: int = _damage(hero, foe, _swing(true), 0.25)
	equal("the timed press reaches the hit: twice the power does more damage", [plain > 0, timed > plain], [true, true])
	var late := _swing(true)
	late.prompt.opens = 2.0
	late.prompt.closes = 3.0
	equal("a prompt that opens after the move ends is a problem", late.problems("x").size(), 1)


func _interrupts(hero: Node3D, foe: Node3D) -> void:
	var hurtbox := foe.get_child(3) as Hurtbox
	var own := MoveTimeline.new()
	hurtbox.timeline = own
	var breaker := _swing(false)
	breaker.interrupts = true
	var rng := RandomNumberGenerator.new()
	own.start(_swing(false))
	_pushes.clear()
	hurtbox.take(Combatant.of(hero), breaker, rng, Vector3.ZERO)
	equal("an interrupting hit stops a move that is winding up, and stuns with a push of no length",
		[own.busy(), hurtbox.interrupted, _pushes], [false, true, [Vector3.ZERO] as Array[Vector3]])
	var armoured := _swing(false)
	armoured.armour_to = 0.7
	armoured.startup = 0.0
	own.start(armoured)
	var knock := _swing(false)
	knock.knockback = 2.0
	hurtbox.take(Combatant.of(hero), knock, rng, Vector3.ZERO)
	equal("an ordinary hit does not get through armour", [own.busy(), hurtbox.interrupted], [true, false])
	hurtbox.take(Combatant.of(hero), breaker, rng, Vector3.ZERO)
	equal("an interrupting one does, past the wind-up too", [own.busy(), hurtbox.interrupted], [false, true])
	var rock := _actor(&"fixture_rock", &"side_b", Vector3(0, 0, -2), -1.0)
	var firm := MoveTimeline.new()
	(rock.get_child(3) as Hurtbox).timeline = firm
	firm.start(_swing(false))
	(rock.get_child(3) as Hurtbox).take(Combatant.of(hero), breaker, rng, Vector3.ZERO)
	equal("a fighter that never flinches is not interrupted", firm.busy(), true)
