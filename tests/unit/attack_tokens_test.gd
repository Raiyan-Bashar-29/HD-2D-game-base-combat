extends TestCase
## Foes as a group (C10.27): only `max_attackers` tokens on one target, given back on release;
## five foes with a limit of 2 never have more than 2 swinging at once; a timed retreat turns back
## when its time is up.
##
## OWNS: assertions about `AttackTokens`, `ActionBrain.max_attackers` through `ActionEnemy`, and
## `ActionBrain.retreat_for` through `ActionDecider`.
## MUST NOT: name a game's fighters or moves, or wait for frames.

var _bodies: Array[Node] = []


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	var target := Node3D.new()
	attach(target)
	_bodies.append(target)
	var a := Node.new()
	var b := Node.new()
	var c := Node.new()
	for each: Node in [a, b, c]:
		attach(each)
		_bodies.append(each)
	var first: Array[bool] = [AttackTokens.take(a, target, 2), AttackTokens.take(b, target, 2), AttackTokens.take(c, target, 2)]
	AttackTokens.release(a)
	equal("only two tokens on one target, and a released one is taken again", first + [AttackTokens.take(c, target, 2)],
		[true, true, false, true])
	AttackTokens.release(b)
	AttackTokens.release(c)
	_crowd()
	_retreat()
	for body: Node in _bodies:
		body.free()
	Flags.clear_all()


func _crowd() -> void:
	var hero := Node3D.new()
	hero.add_child(Vitals.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_tokens_hero"
	fighter.faction = &"side_a"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 999.0}
	hero.add_child(fighter)
	hero.add_child(Hurtbox.new())
	attach(hero)
	_bodies.append(hero)
	var foes: Array[ActionEnemy] = []
	for i: int in 5:
		foes.append(_foe(i, Vector3(cos(i * 1.2), 0, sin(i * 1.2)) * 1.0))
	var most: int = 0
	for step: int in 20:
		var swinging: int = 0
		for foe: ActionEnemy in foes:
			foe.act(0.05)
			if foe.timeline.busy():
				swinging += 1
		most = maxi(most, swinging)
	equal("five foes with a limit of two never have more than two swinging", [most > 0, most <= 2], [true, true])


func _foe(i: int, at: Vector3) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = StringName("fixture_tokens_foe_%d" % i)
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 50.0}
	var swing := ActionMove.new()
	swing.startup = 0.2
	swing.active = 0.2
	swing.recovery = 0.2
	swing.power = 1.0
	swing.hitbox_size = Vector3.ONE
	var entry := ActionBrainEntry.new()
	entry.move = swing
	var brain := ActionBrain.new()
	brain.moves = [entry]
	brain.attack_range = 3.0
	brain.wander_radius = 0.0
	brain.max_attackers = 2
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	made.position = at
	attach(made)
	_bodies.append(made)
	return made


func _retreat() -> void:
	var brain := ActionBrain.new()
	brain.retreat_below = 0.5
	brain.retreat_distance = 5.0
	brain.retreat_for = 1.0
	brain.wander_radius = 0.0
	var decider := ActionDecider.new(brain)
	var rng := RandomNumberGenerator.new()
	var states: Array[ActionDecider.State] = []
	for i: int in 12:
		states.append(decider.think(0.1, 1.0, 0.0, 0.2, false, false, false, rng))
	equal("a timed retreat turns back when its time is up", [states[0], states[11] != ActionDecider.State.RETREAT],
		[ActionDecider.State.RETREAT, true])
