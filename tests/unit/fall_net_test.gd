extends TestCase
## The fall safety net (C5.8). A body above the kill height is left alone. A field foe below
## it is felled where it is; one that returns home is put back unhurt. The player's fighter
## is put back where it last stood and felled, once.
##
## OWNS: assertions about `FallNet`, `ActionEnemy.returns_home` and the fighter's safe place.
## MUST NOT: name a game's fighters, or wait for physics frames.

const DT: float = 0.05


func run() -> void:
	plan(6)
	SaveFixture.activate()
	Flags.clear_all()
	CombatClock.reset()
	_a_foe()
	_the_player()
	Flags.clear_all()


func _a_foe() -> void:
	var foe: ActionEnemy = _enemy(&"fixture_faller")
	foe.global_position = Vector3(3, FallNet.height() + 1.0, 0)
	foe._physics_process(0.0)
	equal("a foe above the kill height is left alone", Vitals.of(foe).is_defeated(), false)
	foe.global_position = Vector3(3, FallNet.height() - 1.0, 0)
	foe._physics_process(0.0)
	equal("below it the foe is felled where it is",
		[Vitals.of(foe).is_defeated(), foe.global_position.y < FallNet.height()], [true, true])
	foe.free()
	var homer: ActionEnemy = _enemy(&"fixture_homer")
	homer.returns_home = true
	homer.home = Vector3(1, 0, 1)
	homer.global_position = Vector3(9, FallNet.height() - 5.0, 9)
	homer.velocity = Vector3(0, -30, 0)
	homer._physics_process(0.0)
	equal("a foe that returns home is put back there, unhurt and still",
		[Vitals.of(homer).is_defeated(), homer.global_position.distance_to(Vector3(1, 0, 1)) < 0.5,
			homer.velocity.y > -1.0], [false, true, true])
	homer.free()


func _the_player() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	player.global_position = Vector3(2, 0, 2)
	var fighter: ActionFighter = ActionHost.equip(player, _loadout())
	var vitals: Vitals = Vitals.of(player)
	fighter.drive(DT, false, false)
	equal("standing, the player is untouched", [vitals.is_defeated(), player.global_position], [false, Vector3(2, 0, 2)])
	player.global_position = Vector3(7, FallNet.height() - 2.0, 7)
	fighter.drive(DT, false, false)
	equal("fallen out of the world, the player is put back where they last stood and felled",
		[vitals.is_defeated(), player.global_position], [true, Vector3(2, 0, 2)])
	vitals.revive(10)
	fighter.drive(DT, false, false)
	equal("back on their feet there, they are not felled again", vitals.is_defeated(), false)
	player.free()


func _enemy(id: StringName) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0}
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = ActionBrain.new()
	attach(made)
	return made


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_fall_walker"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0}
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made
