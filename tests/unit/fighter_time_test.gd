extends TestCase
## One fighter's own time speed (C8.11a). `time_rate` makes `FighterTime.rate` 1 plus it, never
## below 0, and 1 for a non-fighter; a stopped fighter's swing does not move on while its
## statuses still count down; a stopped fighter's shot hangs in the air; a slowed one's swing runs
## at half speed.
##
## OWNS: assertions about `FighterTime` and the parts that read it.
## MUST NOT: name a game's kits, powers or characters, or wait for physics.

const SOURCE: StringName = &"fixture_time"


func run() -> void:
	plan(4)
	var body: CharacterBody3D = _body()
	var me: Combatant = Combatant.of(body)
	var rates: Array[float] = [FighterTime.rate(body)]
	var slow: StatModifier = StatModifier.of(FighterTime.STAT, StatModifier.Op.ADD, -0.5, SOURCE)
	me.sheet.add(slow)
	rates.append(FighterTime.rate(body))
	me.sheet.add(StatModifier.of(FighterTime.STAT, StatModifier.Op.ADD, -2.0, SOURCE))
	rates.append(FighterTime.rate(body))
	var plain := Node3D.new()
	rates.append(FighterTime.rate(plain))
	plain.free()
	equal("the rate is 1 plus time_rate, never below 0, and 1 for a non-fighter", rates, [1.0, 0.5, 0.0, 1.0])
	var fighter: ActionFighter = body.get_node(^"ActionFighter") as ActionFighter
	var status := StatusEffect.new()
	status.id = &"status/fixture_time_mark"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 1.0
	StatusSet.of(body).apply(status)
	fighter.timeline.start(_move())
	for _i: int in 3:
		fighter.drive(0.1, false, false)
	equal("stopped, its swing stands still while its statuses count down",
		[fighter.timeline.elapsed, StatusSet.of(body).remaining(status.id) < 1.0], [0.0, true])
	var shot := Projectile.new()
	shot.attacker = me
	shot.speed = 10.0
	body.get_parent().add_child(shot)
	shot.launch(_move())
	var from: Vector3 = shot.global_position
	shot._physics_process(0.1)
	equal("a stopped fighter's shot hangs where it is", shot.global_position.is_equal_approx(from), true)
	shot.queue_free()
	me.sheet.remove_from(SOURCE)
	me.sheet.add(slow)
	fighter.timeline.start(_move())
	fighter.drive(0.1, false, false)
	equal("slowed to half, a swing runs at half speed", is_equal_approx(fighter.timeline.elapsed, 0.05), true)
	body.get_parent().free()


func _move() -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.5
	made.active = 1.0
	made.recovery = 0.5
	made.hitbox_offset = Vector3.ZERO
	return made


func _body() -> CharacterBody3D:
	var world := Node3D.new()
	var body := CharacterBody3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_time_hero"
	fighter.base_stats = {&"max_hp": 40.0, &"attack": 2.0}
	body.add_child(fighter)
	var action := ActionFighter.new()
	action.name = "ActionFighter"
	action.moves = MoveSet.new()
	action.set_physics_process(false)
	body.add_child(action)
	world.add_child(body)
	attach(world)
	return body
