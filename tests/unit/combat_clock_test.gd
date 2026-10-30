extends TestCase
## The combat time scale (C4.1): `CombatClock` scales frame time and refuses to run backwards;
## at 0 a fighter's swing and roll stand still and an enemy neither walks nor strikes; at 0.5 a
## swing takes twice as long; and entering an area puts the fight back to full speed.
##
## OWNS: assertions about `CombatClock`, and how `ActionFighter`, `ActionEnemy` and `ActionHost`
## obey it.
## MUST NOT: name a game's fighters or moves, or wait for frames: `drive` and `act` are called
## by hand. Every case puts the scale back to 1, because it is shared by the whole process.

const DT: float = 0.02

var _player: PlayerController
var _fighter: ActionFighter
var _actors: Array[Node] = []


func run() -> void:
	plan(15)
	SaveFixture.activate()
	Flags.clear_all()
	_the_number()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_fighter = ActionHost.equip(_player, _loadout())
	_a_fighter_obeys()
	_an_enemy_obeys()
	_an_area_resets_it()
	CombatClock.reset()
	_player.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _the_number() -> void:
	equal("the fight runs at full speed by default", CombatClock.scale, 1.0)
	CombatClock.set_scale(0.5)
	equal("at half speed a frame is half as long", CombatClock.scaled(0.2), 0.1)
	CombatClock.set_scale(-1.0)
	equal("a fight cannot run backwards", CombatClock.scale, 0.0)
	CombatClock.reset()
	equal("reset is full speed again", CombatClock.scaled(0.2), 0.2)


func _a_fighter_obeys() -> void:
	CombatClock.set_scale(0.0)
	_fighter.drive(DT, true, false)
	for i: int in 20:
		_fighter.drive(DT, false, false)
	equal("stopped, a swing starts but its clock does not move", _fighter.timeline.elapsed, 0.0)
	equal("and it is still winding up", _fighter.timeline.phase, MoveTimeline.Phase.STARTUP)
	CombatClock.set_scale(0.5)
	_drive(0.5)
	equal("at half speed, a 0.4 s swing is not over after 0.5 s", _fighter.timeline.busy(), true)
	_drive(0.4)
	equal("and is over after 0.9 s", _fighter.timeline.busy(), false)
	CombatClock.set_scale(0.0)
	_fighter.drive(DT, false, true)
	_fighter.drive(DT, false, false)
	equal("stopped, a roll has started", _fighter.timeline.move, _fighter.moves.dodge)
	equal("but does not move the body", Vector2(_player.velocity.x, _player.velocity.z), Vector2.ZERO)
	CombatClock.reset()
	_fighter.drive(DT, false, false)
	equal("at full speed again it rolls", Vector2(_player.velocity.x, _player.velocity.z).length() > 0.0, true)
	_drive(0.5)


func _an_enemy_obeys() -> void:
	# The fighter from the case above is a hostile too: move it far off, so the hero is the target.
	_player.position = Vector3(50, 0, 50)
	var enemy := _enemy()
	var hero := _hero(Vector3(0, 0, -4))
	CombatClock.set_scale(0.0)
	enemy.act(0.1)
	equal("stopped, an enemy that sees a target does not walk", Vector2(enemy.velocity.x, enemy.velocity.z), Vector2.ZERO)
	CombatClock.reset()
	enemy.act(0.1)
	equal("at full speed it walks at it", Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.0, true)
	hero.position = Vector3(0, 0, -1)
	CombatClock.set_scale(0.0)
	for i: int in 30:
		enemy.act(0.1)
	equal("stopped, in reach, it never lands a hit", Vitals.of(hero).current(&"hp"), 30)
	CombatClock.reset()


func _an_area_resets_it() -> void:
	var host := ActionHost.new()
	attach(host)
	CombatClock.set_scale(0.0)
	Events.area_entered.emit(&"fixture_area")
	equal("entering an area puts the fight back to full speed", CombatClock.scale, 1.0)
	host.free()


func _drive(seconds: float) -> void:
	var left: float = seconds
	while left > 0.001:
		_fighter.drive(DT, false, false)
		left -= DT


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 3.0}
	var swing := ActionMove.new()
	swing.startup = 0.1
	swing.active = 0.1
	swing.recovery = 0.2
	swing.power = 2.0
	var roll := ActionMove.new()
	roll.startup = 0.0
	roll.active = 0.2
	roll.recovery = 0.1
	roll.iframes_to = 0.2
	roll.travel_speed = 5.0
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [swing]
	made.moves.dodge = roll
	return made


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
	brain.moves = [entry]
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	attach(made)
	_actors.append(made)
	return made


func _hero(at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = &"fixture_target"
	combatant.faction = &"side_a"
	combatant.base_stats = {&"max_hp": 30.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor
