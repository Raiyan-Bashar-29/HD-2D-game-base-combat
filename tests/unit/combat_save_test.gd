extends TestCase
## Saves around combat (C5.2). A save is refused while a battle is on and while the player lies
## defeated; a field fighter's pools and a stagger survive a save and a load; and a player loaded
## at 0 hp (a save from before the guard) gets up when the area is entered.
##
## Each refusal is proved by the absence of a file, as in upstream's `save_blocker_test`.
##
## OWNS: assertions about `CombatSaveGuard`, `Weakness.built_in` on load, and `FieldDefeat`'s
## get-up on area entry.
## MUST NOT: name a game's fighters, statuses or areas. Every name here is made up for the case.

const SLOT: int = 2
const AREA: StringName = &"combat_save_test_area"

var _guard: CombatSaveGuard = null
var _actors: Array[Node] = []


func run() -> void:
	plan(18)
	SaveFixture.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Flags.clear_all()
	_guard = CombatSaveGuard.new()
	attach(_guard)
	_a_battle_refuses_saving()
	_a_fallen_player_refuses_saving()
	_pools_and_a_stagger_survive_a_load()
	_a_loaded_fallen_player_gets_up()
	_guard.free()
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	SaveSystem.delete_slot(SLOT)
	Flags.clear_all()


func _fighter(id: StringName) -> Node3D:
	var body := Node3D.new()
	body.add_child(Vitals.new())
	body.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = &"side_a"
	combatant.base_stats = {&"max_hp": 50.0, &"max_mp": 20.0, &"max_shield": 3.0}
	combatant.real_time = true
	body.add_child(combatant)
	attach(body)
	_actors.append(body)
	return body


func _a_battle_refuses_saving() -> void:
	var ids: Array[StringName] = []
	equal("outside a fight nothing is refused", _guard.reason(), "")
	Events.battle_started.emit(ids)
	equal("a battle refuses saving, and says why", SaveSystem.blockers.refusal(),
			CombatSaveGuard.IN_BATTLE_KEY)
	equal("a save in a battle is refused", SaveSystem.save_to_slot(SLOT), ERR_UNAVAILABLE)
	equal("and writes nothing", SaveSystem.has_slot(SLOT), false)
	equal("the quit autosave skips too", _autosave(), ERR_SKIP)
	Events.battle_ended.emit(0)
	equal("after the battle saving works again", SaveSystem.save_to_slot(SLOT), OK)
	SaveSystem.delete_slot(SLOT)


func _a_fallen_player_refuses_saving() -> void:
	var body := _fighter(&"combat_save_test_hero")
	var vitals: Vitals = Vitals.of(body)
	_guard._on_player_spawned(body)
	equal("a standing player may save", _guard.reason(), "")
	vitals.set_to(&"hp", 0)
	equal("a fallen player may not", SaveSystem.blockers.refusal(), CombatSaveGuard.FALLEN_KEY)
	equal("so the save is refused", SaveSystem.save_to_slot(SLOT), ERR_UNAVAILABLE)
	vitals.revive(10)
	equal("once they are up, saving works", SaveSystem.save_to_slot(SLOT), OK)
	SaveSystem.delete_slot(SLOT)


func _pools_and_a_stagger_survive_a_load() -> void:
	var body := _fighter(&"combat_save_test_runner")
	var vitals: Vitals = Vitals.of(body)
	var statuses: StatusSet = StatusSet.of(body)
	var stagger: StatusEffect = Weakness.staggered_status()
	vitals.set_to(&"hp", 30)
	vitals.set_to(&"mp", 5)
	vitals.set_to(&"shield", 0)
	statuses.apply(stagger)
	statuses.tick_seconds(1.0)
	var left: float = statuses.remaining(stagger.id)
	SaveSystem.save_to_slot(SLOT)
	vitals.set_to(&"hp", 50)
	vitals.set_to(&"mp", 20)
	statuses.cure(stagger.id)
	equal("the load succeeds", SaveSystem.load_from_slot(SLOT), OK)
	equal("hp came back", vitals.current(&"hp"), 30)
	equal("so did mp", vitals.current(&"mp"), 5)
	equal("a stagger, built in code, is found again on load", statuses.stacks(stagger.id), 1)
	equal("with the seconds it had left", statuses.remaining(stagger.id), left)
	Weakness.recover(Combatant.of(body))
	equal("so the shield stays empty until the stagger ends", vitals.current(&"shield"), 0)
	SaveSystem.delete_slot(SLOT)


func _a_loaded_fallen_player_gets_up() -> void:
	var body := _fighter(&"combat_save_test_sleeper")
	var vitals: Vitals = Vitals.of(body)
	var defeat := FieldDefeat.new()
	body.add_child(defeat)
	# What a load from an old save does: the pool is 0, and no defeat edge ever fires.
	Flags.set_flag(vitals.key(&"hp"), 0)
	Events.area_entered.emit(AREA)
	equal("entering the area stands a loaded fallen player up", vitals.is_defeated(), false)
	# One who fell just now lies out their rule's delay first; an area entry does not cut it.
	var faller := _fighter(&"combat_save_test_faller")
	var waiting := FieldDefeat.new()
	waiting.rule.delay = 5.0
	faller.add_child(waiting)
	Vitals.of(faller).set_to(&"hp", 0)
	Events.area_entered.emit(AREA)
	equal("but one still lying out the delay stays down", Vitals.of(faller).is_defeated(), true)


func _autosave() -> int:
	var policy := Autosave.new()
	attach(policy)
	var was_area: StringName = Director.current_area_id
	var was_on: bool = Settings.get_bool(Autosave.AUTOSAVE_SETTING)
	Director.current_area_id = AREA
	Settings.set_value(Autosave.AUTOSAVE_SETTING, true)
	var result: int = policy.request()
	Settings.set_value(Autosave.AUTOSAVE_SETTING, was_on)
	Director.current_area_id = was_area
	policy.free()
	return result
