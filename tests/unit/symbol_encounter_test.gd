extends TestCase
## Symbol encounters (C5.1): a field foe with a `SymbolEncounter` child asks for its turn-based
## encounter once when the party comes within `touch_radius`. A win fells the field body, a
## flee or a loss leaves it quiet for `grace` seconds, and a request nobody answers never leaves
## it stuck. The test is its own battle host: it answers the request by announcing a battle.
##
## OWNS: assertions about `SymbolEncounter`.
## MUST NOT: name a game's encounters, or wait for frames.

const DT: float = 0.1
const ID: StringName = &"encounter/fixture_symbol"

var _requests: Array[StringName] = []
var _answer: bool = true
var _fallen: Array[StringName] = []


func run() -> void:
	plan(16)
	SaveFixture.activate()
	Flags.clear_all()
	Events.encounter_requested.connect(_on_request)
	Events.field_enemy_defeated.connect(_on_fallen)
	var hero := _hero(Vector3(0, 0, -5))
	var foe := _foe()
	var symbol: SymbolEncounter = foe.get_node("Symbol") as SymbolEncounter
	_touching(foe, symbol, hero)
	_fleeing_and_refused(symbol, hero)
	_winning(foe, symbol)
	_checks()
	Events.encounter_requested.disconnect(_on_request)
	Events.field_enemy_defeated.disconnect(_on_fallen)
	foe.free()
	hero.free()
	CombatClock.reset()
	Flags.clear_all()


func _touching(foe: ActionEnemy, symbol: SymbolEncounter, hero: Node3D) -> void:
	symbol.watch(DT)
	equal("a party member far away starts nothing", _requests.size(), 0)
	hero.global_position = foe.global_position + Vector3(0, 0, -1)
	symbol.watch(DT)
	equal("within the touch radius, its encounter is asked for once", [_requests, symbol.waiting()], [[ID], true])
	symbol.watch(DT)
	equal("while that battle is open it asks no more", _requests.size(), 1)
	Events.battle_ended.emit(Battle.Outcome.FLED)
	equal("a flee ends the wait", symbol.waiting(), false)


func _fleeing_and_refused(symbol: SymbolEncounter, hero: Node3D) -> void:
	symbol.watch(DT)
	equal("after a flee it leaves the party alone for its grace", _requests.size(), 1)
	CombatClock.set_scale(0.0)
	for i: int in 40:
		symbol.watch(DT)
	equal("the grace counts fight time: a stopped clock keeps it", _requests.size(), 1)
	CombatClock.reset()
	for i: int in 30:
		symbol.watch(DT)
	equal("once the grace has run out, a touch asks again", _requests.size(), 2)
	Events.battle_ended.emit(Battle.Outcome.LOST)
	_answer = false
	for i: int in 31:
		symbol.watch(DT)
	equal("a request nobody answers is not left waiting", [_requests.size(), symbol.waiting()], [3, false])
	_answer = true
	for i: int in 31:
		symbol.watch(DT)
	equal("and after its grace it asks again", [_requests.size(), symbol.waiting()], [4, true])
	hero.global_position = Vector3(0, 0, -20)
	Events.battle_ended.emit(Battle.Outcome.FLED)
	for i: int in 31:
		symbol.watch(DT)
	Events.combatant_damaged.emit(&"fixture_hero", &"fixture_symbol_foe/Foe", 3, false)
	equal("someone else being hit starts nothing", _requests.size(), 4)
	Events.combatant_damaged.emit(&"fixture_symbol_foe/Foe", &"fixture_hero", 3, false)
	equal("a strike landing on it starts its battle: a first strike", [_requests.size(), symbol.waiting()], [5, true])


func _winning(foe: ActionEnemy, symbol: SymbolEncounter) -> void:
	Events.battle_ended.emit(Battle.Outcome.WON)
	equal("a won battle drops the field body to 0 hp", [Vitals.of(foe).current(&"hp"), symbol.waiting()], [0, false])
	foe.act(DT)
	equal("and it falls its own way", _fallen, [&"fixture_symbol_foe/Foe"])
	Events.battle_ended.emit(Battle.Outcome.FLED)
	symbol.watch(DT)
	equal("a battle it did not ask for is ignored, and a fallen foe asks nothing", _requests.size(), 5)


func _checks() -> void:
	var bad := SymbolEncounter.new()
	bad.touch_radius = 0.0
	equal("problems: no encounter and no radius", bad.problems("x").size(), 2)
	bad.free()
	var chaser := ActionBrain.new()
	chaser.chase_only = true
	equal("a chase-only brain may have no moves", chaser.problems("x"), PackedStringArray())


func _on_request(id: StringName) -> void:
	_requests.append(id)
	if _answer:
		Events.battle_started.emit([&"fixture"] as Array[StringName])


func _on_fallen(who: StringName, _experience: int, _loot: Array[StringName]) -> void:
	_fallen.append(who)


func _foe() -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_symbol_foe"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 20.0}
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	brain.chase_only = true
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.name = "Foe"
	made.fighter = def
	made.brain = brain
	var symbol := SymbolEncounter.new()
	symbol.name = "Symbol"
	symbol.encounter_id = ID
	made.add_child(symbol)
	attach(made)
	return made


func _hero(at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = &"fixture_hero"
	combatant.faction = &"side_a"
	combatant.base_stats = {&"max_hp": 30.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	return actor
