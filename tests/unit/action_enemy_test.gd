extends TestCase
## The enemy's body (C3.7): the prefab builds its fighting parts from data with full pools; it
## stands with nobody near; it walks at a target it notices and stands once in range; it starts
## its chosen move facing the target, and the move's hit lands; it reels from a knockback;
## hurt, it backs away; dragged past its leash it walks home; fallen, it stops; and it never
## picks an ally or the fallen as its target.
##
## OWNS: assertions about `ActionEnemy` and its prefab.
## MUST NOT: name a game's enemies, or wait for physics: `act` is called by hand, and with no
## navmesh the enemy walks straight at its goal.

const S := ActionDecider.State
const DT: float = 0.1

var _actors: Array[Node] = []


func run() -> void:
	plan(13)
	SaveFixture.activate()
	Flags.clear_all()
	var enemy := _enemy()
	var hero := _hero(&"fixture_hero", &"side_a", Vector3(0, 0, -10))
	_noticing_and_chasing(enemy, hero)
	_attacking(enemy, hero)
	_reeling_retreating_and_home(enemy, hero)
	enemy.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _enemy() -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_brute"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0, &"attack": 2.0}
	var jab := ActionMove.new()
	jab.power = 3.0
	var entry := ActionBrainEntry.new()
	entry.move = jab
	var brain := ActionBrain.new()
	brain.move_speed = 2.0
	brain.wander_radius = 0.0
	brain.retreat_below = 0.3
	brain.moves = [entry]
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	attach(made)
	# A fixed formula: the standard one rolls crits and variance, and this test counts hp exactly.
	Combatant.of(made).formula = DamageFormula.new()
	Combatant.of(made).formula.stages = [AttackDefenceStage.new()]
	return made


func _hero(id: StringName, side: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 30.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _flat_velocity(enemy: ActionEnemy) -> Vector3:
	return Vector3(snappedf(enemy.velocity.x, 0.01), 0.0, snappedf(enemy.velocity.z, 0.01))


func _noticing_and_chasing(enemy: ActionEnemy, hero: Node3D) -> void:
	equal("the prefab builds a fighter from its definition, hp full",
		[String(Combatant.of(enemy).combatant_id).begins_with("fixture_brute/"), Vitals.of(enemy).current(&"hp")],
		[true, 20])
	_hero(&"fixture_friend", &"side_b", Vector3(0, 0, -1))
	equal("an ally right beside it is never its target", enemy.nearest_hostile().fighter().combatant_id, &"fixture_hero")
	equal("with nobody near, it stands", [enemy.act(DT), _flat_velocity(enemy)], [S.IDLE, Vector3.ZERO])
	hero.position = Vector3(0, 0, -4)
	equal("it walks straight at a target it notices", [enemy.act(DT), _flat_velocity(enemy)], [S.CHASE, Vector3(0, 0, -2)])
	equal("facing it", enemy.facing, Vector3.FORWARD)


func _attacking(enemy: ActionEnemy, hero: Node3D) -> void:
	hero.position = Vector3(0, 0, -1)
	equal("in reach, it starts its move and plants its feet",
		[enemy.act(DT), enemy.timeline.busy(), _flat_velocity(enemy)], [S.ATTACK, true, Vector3.ZERO])
	var hitbox: Hitbox = null
	for child: Node in enemy.get_children():
		if child is Hitbox:
			hitbox = child as Hitbox
	hitbox.strike(hero.get_child(2) as Hurtbox)
	equal("its live move lands through the formula: 3 + 2", Vitals.of(hero).current(&"hp"), 25)
	for i: int in 4:
		enemy.act(DT)
	equal("the move over, inside range it stands and waits out the cooldown",
		[enemy.act(DT), _flat_velocity(enemy)], [S.CHASE, Vector3.ZERO])


func _reeling_retreating_and_home(enemy: ActionEnemy, hero: Node3D) -> void:
	Events.knockback_requested.emit(Combatant.of(enemy).combatant_id, Vector3(0.6, 0, 0))
	equal("a knockback makes it reel, pushed for the stun", [enemy.act(DT), _flat_velocity(enemy)], [S.STAGGERED, Vector3(2, 0, 0)])
	for i: int in 4:
		enemy.act(DT)
	Vitals.of(enemy).change(&"hp", -15)
	equal("hurt below 30% with the target close, it backs away", [enemy.act(DT), _flat_velocity(enemy)],
		[S.RETREAT, Vector3(0, 0, 2)])
	Vitals.of(enemy).change(&"hp", 15)
	enemy.position = Vector3(0, 0, 20)
	hero.position = Vector3(0, 0, 21)
	equal("dragged past its leash, it walks home and ignores the target", [enemy.act(DT), _flat_velocity(enemy)],
		[S.RETURN, Vector3(0, 0, -2)])
	enemy.position = Vector3.ZERO
	Vitals.of(enemy).change(&"hp", -100)
	equal("fallen, it stops", [enemy.act(DT), _flat_velocity(enemy)], [S.DEFEATED, Vector3.ZERO])
	Vitals.of(hero).change(&"hp", -100)
	equal("and nobody targets the fallen", enemy.nearest_hostile(), null)
