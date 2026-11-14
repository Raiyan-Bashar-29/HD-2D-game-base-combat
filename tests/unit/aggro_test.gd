extends TestCase
## Aggro and taunt (C8.6): a foe picks the nearest with an empty table; a hit it takes puts the
## attacker on its table and the most threat wins; the `threat` stat scales that, and -1 makes
## none; threat fades; a fighter holding a status tagged `taunt` is picked over any threat, but
## not past the foe's reach and not once it is down; and in a turn battle `narrow` cuts the
## choice to the taunting foes and leaves a taunting ally alone.
##
## OWNS: assertions about `Aggro`.
## MUST NOT: name a game's fighters, or wait for physics.

var _actors: Array[Node] = []


func run() -> void:
	plan(11)
	SaveFixture.activate()
	Flags.clear_all()
	var enemy := _enemy()
	var near := _hero(&"fixture_near", &"side_a", Vector3(0, 0, -2), 0.0)
	var far := _hero(&"fixture_far", &"side_a", Vector3(0, 0, -6), 0.0)
	var tank := _hero(&"fixture_tank", &"side_a", Vector3(0, 0, -8), 2.0)
	_threat(enemy)
	_taunts(enemy, tank)
	_narrowing(enemy, near, far)
	enemy.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _enemy() -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_brute"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 200.0}
	var brain := ActionBrain.new()
	brain.give_up_radius = 10.0
	brain.threat_fade = 2.0
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	attach(made)
	return made


func _hero(id: StringName, side: StringName, at: Vector3, threat: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 30.0, Aggro.STAT: threat}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _picked(enemy: ActionEnemy) -> StringName:
	var hurtbox: Hurtbox = enemy.nearest_hostile()
	return hurtbox.fighter().combatant_id if hurtbox != null else &""


func _hurt(enemy: ActionEnemy, by: StringName, amount: int) -> void:
	Events.combatant_damaged.emit(Combatant.of(enemy).combatant_id, by, amount, false)


func _taunt() -> StatusEffect:
	var made := StatusEffect.new()
	made.id = &"status/fixture_provoke"
	made.unit = StatusEffect.Unit.SECONDS
	made.duration = 5.0
	made.tags = [Aggro.TAG]
	return made


func _threat(enemy: ActionEnemy) -> void:
	var table: Aggro = Aggro.of(enemy)
	equal("the enemy has a table, fading by its brain's number", [table != null, table.fade], [true, 2.0])
	equal("an empty table: the nearest is picked", _picked(enemy), &"fixture_near")
	_hurt(enemy, &"fixture_far", 10)
	equal("a hit puts the attacker on the table, and the most threat is picked",
		[table.toward(&"fixture_far"), _picked(enemy)], [10.0, &"fixture_far"])
	_hurt(enemy, &"fixture_tank", 4)
	equal("a threat stat of 2 triples it: 4 damage makes 12, more than 10",
		[table.toward(&"fixture_tank"), _picked(enemy)], [12.0, &"fixture_tank"])
	Combatant.of(_actors[0]).sheet.set_base(Aggro.STAT, -1.0)
	_hurt(enemy, &"fixture_near", 50)
	equal("a threat stat of -1 makes none", table.toward(&"fixture_near"), 0.0)
	table.pass_time(5.5)
	equal("threat fades 2 a second: after 5.5 s only the tank's 1 point is left",
		[table.threat.size(), table.toward(&"fixture_tank")], [1, 1.0])
	table.pass_time(1.0)
	equal("and with the table empty the nearest is picked again", _picked(enemy), &"fixture_near")


func _taunts(enemy: ActionEnemy, tank: Node3D) -> void:
	_hurt(enemy, &"fixture_far", 30)
	StatusSet.of(tank).apply(_taunt())
	equal("a taunting fighter is picked over any threat", _picked(enemy), &"fixture_tank")
	tank.position = Vector3(0, 0, -12)
	equal("but not from beyond the enemy's reach", _picked(enemy), &"fixture_far")
	tank.position = Vector3(0, 0, -8)
	Vitals.of(tank).change(&"hp", -100)
	equal("nor once it is down", _picked(enemy), &"fixture_far")
	Vitals.of(tank).revive(30)


func _narrowing(enemy: ActionEnemy, near: Node3D, far: Node3D) -> void:
	var foe: Combatant = Combatant.of(enemy)
	var one: Combatant = Combatant.of(near)
	var two: Combatant = Combatant.of(far)
	var both: Array[Combatant] = [one, two]
	StatusSet.of(far).apply(_taunt())
	equal("in a battle a foe may aim only at the taunting one, and an ally's taunt changes nothing",
		[Aggro.narrow(foe, both), Aggro.narrow(one, both)], [[two] as Array[Combatant], both])
