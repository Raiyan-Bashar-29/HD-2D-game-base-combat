extends TestCase
## What a shot sent by a move event does (C8.16c, C8.16d): one `at_foe` starts at the foe; one
## with lift and a fall arcs; a pierce shot of several hits strikes one hit at a time; one that
## does not pierce lands all its hits at once and is gone; a shot's own events play on it.
##
## OWNS: assertions about `MoveEvent.at_foe`, `lift`, `gravity`, `pierce`, and the C8.16d parts
## of `Projectile` and `Hitbox.forget`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _actors: Array[Node] = []


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_at_foe()
	_shot_life()
	for actor: Node in _actors:
		actor.free()
	CombatClock.reset()
	Flags.clear_all()


func _at_foe() -> void:
	var hero := _actor(&"fixture_far_hero", &"side_a", Vector3(-20, 0, 0))
	var foe := _actor(&"fixture_far_foe", &"side_b", Vector3(-20, 0, -4))
	var events: MoveEvents = hero.get_child(5) as MoveEvents
	var clock := MoveTimeline.new()
	(hero.get_child(3) as Hurtbox).timeline = clock
	var move := _move()
	var shot := _event(MoveEvent.Kind.SHOT, 0.0, 0.0)
	shot.shot = _strike(3.0)
	shot.at_foe = true
	shot.offset = Vector3(0.0, 0.5, 0.0)
	move.events = [shot]
	clock.start(move)
	events.watch()
	var shots: Array[Node] = get_tree().get_nodes_in_group(Projectile.GROUP)
	var placed: Projectile = shots[0] as Projectile if shots.size() == 1 else null
	equal("a shot at the foe starts at the foe's feet plus its offset, not at the body",
		placed != null and placed.global_position.is_equal_approx(foe.global_position + Vector3(0, 0.5, 0)), true)
	if placed != null:
		placed.free()


func _shot_life() -> void:
	var hero := _actor(&"fixture_life_hero", &"side_a", Vector3(40, 0, 0))
	var foe := _actor(&"fixture_life_foe", &"side_b", Vector3(40, 0, -2))
	var arc := _flying(hero, false, 1, 0.0, false, 2.0)
	arc.lift = 4.0
	arc.fall = 10.0
	var heights: Array[float] = []
	for step: int in 8:
		arc.fly(0.1)
		heights.append(snappedf(arc.global_position.y, 0.01))
	equal("a shot with lift and gravity rises, then falls below where it started",
		[heights.max() > 0.5, heights[7] < 0.0], [true, true])
	arc.free()
	var spread := _flying(hero, true, 3, 3.0)
	var hurt: Hurtbox = foe.get_child(3) as Hurtbox
	var seen: Array[int] = []
	for step: int in 7:
		spread.fly(0.1)
		spread.strike(hurt)
		seen.append(Vitals.of(foe).current(&"hp"))
	equal("a pierce shot of three hits strikes one at a time, every third of its active time", seen, [45, 40, 40, 35, 35, 35, 35])
	spread.free()
	Vitals.of(foe).set_to(&"hp", 50)
	var bolt := _flying(hero, false, 3, 3.0)
	bolt.fly(0.01)
	bolt.strike(hurt)
	equal("a shot that does not pierce lands all its hits at once and is gone", [Vitals.of(foe).current(&"hp"), bolt.gone()], [35, true])
	var ringing := _flying(hero, false, 1, 0.0, true)
	var own: MoveEvents = ringing.get_child(ringing.get_child_count() - 1) as MoveEvents
	if own != null:
		own.watch()
	equal("a shot's own MoveEvents plays the sound of the shot's move on the shot's clock", own != null and own.done == 1, true)
	ringing.free()


# A shot from `hero`'s side, in the tree at its feet, its move `hits` hits of `power`, `active` s.
func _flying(hero: Node3D, pierce: bool, hits: int, power: float, sound: bool = false, active: float = 0.6) -> Projectile:
	var move := _strike(power)
	move.active = active
	move.hits = hits
	if sound:
		var ring := _event(MoveEvent.Kind.SOUND, 0.0)
		ring.sound = AudioStreamWAV.new()
		move.events = [ring]
	var shot := Projectile.new()
	shot.attacker = Combatant.of(hero)
	shot.pierce = pierce
	shot.launch(move)
	if sound:
		shot.add_child(MoveEvents.new())
	hero.get_parent().add_child(shot)
	shot.global_position = hero.global_position
	return shot


func _event(kind: MoveEvent.Kind, at: float, amount: float = 0.0, seconds: float = 0.0) -> MoveEvent:
	var made := MoveEvent.new()
	made.kind = kind
	made.at = at
	made.amount = amount
	made.seconds = seconds
	return made


func _move() -> ActionMove:
	var made := ActionMove.new()
	made.id = &"move/fixture_event_swing"
	made.startup = 0.2
	made.active = 0.4
	made.recovery = 0.4
	made.travel_speed = 2.0
	return made


func _strike(power: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.0
	made.active = 0.5
	made.recovery = 0.1
	made.power = power
	made.knockback = 2.0
	return made


func _actor(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 50.0, &"attack": 2.0}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	actor.add_child(Hitbox.new())
	actor.add_child(MoveEvents.new())
	attach(actor)
	_actors.append(actor)
	return actor
