extends TestCase
## Powers in field brains (C10.22): an `ActionBrainEntry` naming a power picks its move and says
## so; a field foe whose brain picks it uses the power (its cooldown starts) and plays its move;
## while it is refused the move is not played.
##
## OWNS: assertions about `ActionBrainEntry.power`, `ActionDecider.chosen_power` and
## `FieldPowerPress` through `ActionEnemy`.
## MUST NOT: name a game's fighters, kits or moves, or wait for frames.

var _bodies: Array[Node] = []


func run() -> void:
	plan(3)
	SaveFixture.activate()
	Flags.clear_all()
	var power: Power = _power()
	var entry := ActionBrainEntry.new()
	entry.power = power
	entry.reach = 5.0
	var brain := ActionBrain.new()
	brain.moves = [entry]
	var decider := ActionDecider.new(brain)
	equal("an entry naming a power picks the power's move and says which power",
		[decider.pick(1.0, 1.0, RandomNumberGenerator.new()) == power.move, decider.chosen_power == power, entry.problems("x").size()],
		[true, true, 0])
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_pentry"
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	var foe: ActionEnemy = _foe(brain, kit)
	_target(Vector3(0, 0, -1.5))
	for i: int in 4:
		foe.act(0.05)
	var powers: PowerSet = PowerSet.of(foe)
	equal("a field foe whose brain picks it uses the power and plays its move",
		[foe.timeline.move == power.move, powers.cooldown_left(power.power_id) > 0.0], [true, true])
	var swing: int = foe.timeline.swing
	for i: int in 30:
		foe.act(0.05)
	equal("while the power cools down its move is not played again", foe.timeline.swing, swing)
	for body: Node in _bodies:
		body.free()
	Flags.clear_all()


func _power() -> Power:
	var move := ActionMove.new()
	move.startup = 0.1
	move.active = 0.1
	move.recovery = 0.1
	move.power = 1.0
	move.hitbox_size = Vector3(1, 1, 1)
	var made := Power.new()
	made.power_id = &"power/fixture_pentry"
	made.name_key = "fixture.power"
	made.cooldown = 30.0
	made.move = move
	return made


func _foe(brain: ActionBrain, kit: PowerKit) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_pentry_foe"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 50.0}
	def.power_kit = kit
	brain.attack_range = 5.0
	brain.aggro_radius = 10.0
	brain.wander_radius = 0.0
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	attach(made)
	_bodies.append(made)
	if PowerSet.of(made) == null:
		var powers := PowerSet.new()
		made.add_child(powers)
		powers.equip(kit)
	return made


func _target(at: Vector3) -> void:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_pentry_target"
	fighter.faction = &"side_a"
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 50.0}
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_bodies.append(actor)
