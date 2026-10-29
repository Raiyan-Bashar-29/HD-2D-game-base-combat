extends TestCase
## `StatusEffect`, `StatusDb` and `StatusSet`: both units, the three stacking rules, ticks, clean
## expiry, cure, and surviving a save.
##
## OWNS: assertions about statuses on one fixture combatant.
## MUST NOT: name a game's statuses or stats. The statuses are written to this run's scratch
## directory, so the suite passes with `data/` deleted.

const WHO: StringName = &"fixture_combatant"

var _applied: int = 0
var _expired: int = 0


func run() -> void:
	plan(27)
	SaveFixture.activate()
	Flags.clear_all()
	Events.status_applied.connect(_on_applied)
	Events.status_expired.connect(_on_expired)
	_a_broken_status_is_refused()
	_turns_tick_then_expire_cleanly()
	_seconds_tick_on_their_interval()
	_the_three_stacking_rules()
	_cure()
	_statuses_survive_a_save()
	Events.status_applied.disconnect(_on_applied)
	Events.status_expired.disconnect(_on_expired)
	StatusDb.content_dir = StatusDb.STATUS_DIR
	StatusDb.rescan()
	Flags.clear_all()


func _status(name: String, unit: StatusEffect.Unit, duration: float,
		stacking: StatusEffect.Stacking = StatusEffect.Stacking.REFRESH) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = StringName(StatusDb.ID_PREFIX + name)
	made.unit = unit
	made.duration = duration
	made.stacking = stacking
	return made


func _combatant() -> Node:
	var actor := Node.new()
	var vitals := Vitals.new()
	vitals.owner_id = WHO
	vitals.sheet.set_base(&"max_hp", 50.0)
	vitals.sheet.set_base(&"stat_a", 10.0)
	actor.add_child(vitals)
	var set := StatusSet.new()
	set.owner_id = WHO
	set.save_id = &"statuses/fixture_combatant"
	actor.add_child(set)
	attach(actor)
	return actor


func _a_broken_status_is_refused() -> void:
	var broken := _status("fixture_broken", StatusEffect.Unit.TURNS, 2.0)
	broken.tick_change = -1
	equal("a tick with no pool is a problem", broken.problems().size(), 1)
	var actor := _combatant()
	equal("and is refused", StatusSet.of(actor).apply(broken), false)
	actor.free()


func _turns_tick_then_expire_cleanly() -> void:
	Flags.clear_all()
	var actor := _combatant()
	var set := StatusSet.of(actor)
	var vitals := Vitals.of(actor)
	var poison := _status("fixture_poison", StatusEffect.Unit.TURNS, 2.0)
	poison.tick_pool = &"hp"
	poison.tick_change = -5
	poison.modifiers = [StatModifier.of(&"stat_a", StatModifier.Op.ADD, -4.0, &"")]
	_expired = 0
	set.apply(poison)
	equal("its modifier is on the sheet", vitals.sheet.value(&"stat_a"), 6.0)
	set.tick_seconds(10.0)
	equal("a TURNS status ignores seconds", vitals.current(&"hp"), 50)
	set.tick_turn()
	equal("a turn ticks it", vitals.current(&"hp"), 45)
	equal("and spends a turn", set.remaining(poison.id), 1.0)
	set.tick_turn()
	equal("the last turn still ticks", vitals.current(&"hp"), 40)
	equal("then it is gone", set.stacks(poison.id), 0)
	equal("and so is its modifier", vitals.sheet.value(&"stat_a"), 10.0)
	equal("its expiry is announced once", _expired, 1)
	actor.free()


func _seconds_tick_on_their_interval() -> void:
	Flags.clear_all()
	var actor := _combatant()
	var set := StatusSet.of(actor)
	var vitals := Vitals.of(actor)
	var burn := _status("fixture_burn", StatusEffect.Unit.SECONDS, 3.0)
	burn.tick_pool = &"hp"
	burn.tick_change = -2
	burn.tick_interval = 1.0
	set.apply(burn)
	set.tick_turn()
	equal("a SECONDS status ignores turns", vitals.current(&"hp"), 50)
	set.tick_seconds(0.5)
	equal("half an interval does not tick", vitals.current(&"hp"), 50)
	set.tick_seconds(1.0)
	equal("crossing it does, once", vitals.current(&"hp"), 48)
	set.tick_seconds(100.0)
	equal("a long step never ticks past expiry", vitals.current(&"hp"), 44)
	equal("and the status is gone", set.stacks(burn.id), 0)
	actor.free()


func _the_three_stacking_rules() -> void:
	Flags.clear_all()
	var actor := _combatant()
	var set := StatusSet.of(actor)
	var vitals := Vitals.of(actor)
	var refresh := _status("fixture_refresh", StatusEffect.Unit.TURNS, 3.0)
	set.apply(refresh)
	set.tick_turn()
	set.apply(refresh)
	equal("REFRESH resets the duration", set.remaining(refresh.id), 3.0)
	equal("and stays one stack", set.stacks(refresh.id), 1)
	var stack := _status("fixture_stack", StatusEffect.Unit.TURNS, 3.0, StatusEffect.Stacking.STACK)
	stack.max_stacks = 2
	stack.modifiers = [StatModifier.of(&"stat_a", StatModifier.Op.ADD, 1.0, &"")]
	set.apply(stack)
	set.apply(stack)
	set.apply(stack)
	equal("STACK stops at max_stacks", set.stacks(stack.id), 2)
	equal("each stack adds its modifiers", vitals.sheet.value(&"stat_a"), 12.0)
	var ignore := _status("fixture_ignore", StatusEffect.Unit.TURNS, 3.0, StatusEffect.Stacking.IGNORE)
	set.apply(ignore)
	set.tick_turn()
	_applied = 0
	equal("IGNORE refuses while held", set.apply(ignore), false)
	equal("leaves the duration alone, and says nothing", set.remaining(ignore.id) == 2.0 and _applied == 0, true)
	actor.free()


func _cure() -> void:
	Flags.clear_all()
	var actor := _combatant()
	var set := StatusSet.of(actor)
	var lasting := _status("fixture_lasting", StatusEffect.Unit.TURNS, 0.0)
	set.apply(lasting)
	for i: int in 5:
		set.tick_turn()
	equal("a duration of zero lasts until cured", set.stacks(lasting.id), 1)
	equal("cure ends it", set.cure(lasting.id), true)
	equal("curing what is not held is refused", set.cure(lasting.id), false)
	actor.free()


func _statuses_survive_a_save() -> void:
	Flags.clear_all()
	var directory: String = RunScratch.path("statuses")
	DirAccess.make_dir_recursive_absolute(directory)
	var stack := _status("fixture_saved", StatusEffect.Unit.TURNS, 4.0, StatusEffect.Stacking.STACK)
	stack.max_stacks = 3
	stack.modifiers = [StatModifier.of(&"stat_a", StatModifier.Op.ADD, 1.0, &"")]
	ResourceSaver.save(stack, directory.path_join("fixture_saved.tres"))
	StatusDb.content_dir = directory
	StatusDb.rescan()
	var actor := _combatant()
	var set := StatusSet.of(actor)
	var vitals := Vitals.of(actor)
	set.apply(stack)
	set.apply(stack)
	set.tick_turn()
	var slot: int = 3
	SaveSystem.save_to_slot(slot)
	set.cure(stack.id)
	SaveSystem.load_from_slot(slot)
	equal("the stacks came back", set.stacks(stack.id), 2)
	equal("so did the time left", set.remaining(stack.id), 3.0)
	equal("and the modifiers, rebuilt once per stack", vitals.sheet.value(&"stat_a"), 12.0)
	SaveSystem.delete_slot(slot)
	actor.free()


func _on_applied(_who: StringName, _status_id: StringName, _stacks: int) -> void:
	_applied += 1


func _on_expired(_who: StringName, _status_id: StringName) -> void:
	_expired += 1
