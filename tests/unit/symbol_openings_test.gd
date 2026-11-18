extends TestCase
## Symbol encounter openings (C10.21): a party strike on a foe's back opens the battle with every
## foe off guard; the foe touching a member from behind puts the party off guard; a plain touch
## leaves both sides alone; a foe felled outright asks for no battle.
##
## OWNS: assertions about `SymbolEncounter.behind`, the opening and the one-blow path.
## MUST NOT: name a game's fighters or encounters. Every name here is made up for the case.

var _holder: Node
var _battle: Battle
var _requests: int = 0


func run() -> void:
	plan(4)
	SaveFixture.activate()
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	Events.encounter_requested.connect(_on_request)
	var hero: Node3D = _body(&"fixture_open_hero", &"side_a", Vector3(0, 0, 3))
	var foe: ActionEnemy = _foe(Vector3.ZERO)
	var symbol: SymbolEncounter = foe.get_node(^"Symbol") as SymbolEncounter
	equal("behind is the far side of the way a body faces",
		[SymbolEncounter.behind(foe, hero), SymbolEncounter.behind(hero, foe)], [true, false])
	Events.combatant_damaged.emit(Combatant.of(foe).combatant_id, &"fixture_open_hero", 1, false)
	equal("a strike on the foe's back puts every foe off guard and not the party",
		[_off(_battle.enemies[0]), _off(_battle.party[0])], [true, false])
	_end(symbol)
	hero.global_position = Vector3(0, 0, -0.8)
	hero.look_at(Vector3(0, 0, -5), Vector3.UP)
	symbol.watch(0.0)
	equal("the foe touching a member from behind puts the party off guard", [_off(_battle.party[0]), _off(_battle.enemies[0])], [true, false])
	_end(symbol)
	Vitals.of(foe).set_to(&"hp", 0)
	var asked: int = _requests
	Events.combatant_damaged.emit(Combatant.of(foe).combatant_id, &"fixture_open_hero", 20, false)
	equal("a foe felled outright asks for no battle", _requests, asked)
	Events.encounter_requested.disconnect(_on_request)
	foe.free()
	hero.free()
	_holder.free()
	Flags.clear_all()


func _off(fighter: Combatant) -> bool:
	return StatusSet.of(fighter.get_parent()).stacks(SymbolEncounter.off_guard().id) > 0


func _end(symbol: SymbolEncounter) -> void:
	BattleSetup.release(_battle)
	Events.battle_ended.emit(Battle.Outcome.FLED)
	symbol.watch(symbol.grace + 1.0)


func _on_request(_id: StringName) -> void:
	_requests += 1
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_open"
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_open_battle_foe"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0, &"speed": 1.0}
	encounter.enemies = [def]
	var hero := CombatantDef.new()
	hero.combatant_id = &"fixture_open_battle_hero"
	hero.faction = &"side_a"
	hero.base_stats = {&"max_hp": 20.0, &"speed": 5.0}
	_battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())


func _foe(at: Vector3) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_open_foe"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0}
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	brain.chase_only = true
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = brain
	var symbol := SymbolEncounter.new()
	symbol.name = "Symbol"
	symbol.encounter_id = &"encounter/fixture_open"
	made.add_child(symbol)
	made.position = at
	attach(made)
	return made


func _body(id: StringName, side: StringName, at: Vector3) -> Node3D:
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
	return actor
