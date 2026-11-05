extends TestCase
## Forms (C6.5a), the first built-in mechanism: a form is a status entered and left by using its
## power; one form per exclusive group; a cycle moves through its stages and on after a named
## power; a drain by the second in the field and by the turn in a battle ends the form at an
## empty pool; and a status taken off from outside, or run out, ends the form.
##
## OWNS: assertions about `FormMechanism` and `FormRun`, through `PowerUse` and `PowerSet`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const STYLE_A: StringName = &"status/fixture_form_style_a"
const STYLE_B: StringName = &"status/fixture_form_style_b"
const AURA: StringName = &"status/fixture_form_aura"
const TRIGGER: StringName = &"status/fixture_form_trigger"
const SWORDS: Array[StringName] = [&"status/fixture_form_sword_1", &"status/fixture_form_sword_2",
	&"status/fixture_form_sword_3"]

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _style_a: Power
var _style_b: Power
var _aura: Power
var _trigger: Power
var _swords: Power
var _finisher: Power
var _jab: Power


func run() -> void:
	plan(21)
	Flags.clear_all()
	_rng.seed = 5
	_shapes()
	var field: Combatant = _fighter(&"fixture_form_field", true)
	_toggling(field)
	_groups(field)
	_cycling(field)
	_draining_by_seconds(field)
	_outside(field)
	var battle: Combatant = _fighter(&"fixture_form_battle", false)
	_draining_by_turns(battle)
	_unequipping(field)
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _shapes() -> void:
	var form := FormMechanism.new()
	equal("a form's kind is form, and the base runs it",
		[form.kind(), PowerMechanisms.make(_form(STYLE_A, &"style")) is FormRun], [&"form", true])
	equal("a form with no status and no cycle is a problem", form.problems("fixture").size(), 1)
	form.status = _status(STYLE_A, 0.0)
	form.drain_per_second = -1.0
	form.advance_after = [&"power/fixture_form_finisher"]
	equal("a drain of no pool, a negative drain, and advancing a form that is not a cycle",
		form.problems("fixture").size(), 3)
	var cycle := FormMechanism.new()
	cycle.cycle = [_form(SWORDS[0], &""), null, cycle.duplicate()]
	(cycle.cycle[2] as FormMechanism).cycle = [_form(SWORDS[1], &"")]
	equal("an empty stage and a stage with its own cycle are problems",
		cycle.problems("fixture").size(), 2)
	equal("a clean cycle has none, and lists one status per stage",
		[_sword_cycle().problems("fixture").size(), _sword_cycle().stage_statuses().size()], [0, 3])


func _toggling(me: Combatant) -> void:
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	equal("using a form's power enters it: its status is held and its modifier is on the sheet",
		[_use(me, _style_a), statuses.stacks(STYLE_A), me.sheet.value(&"attack")], [true, 1, 9.0])
	_use(me, _style_a)
	equal("using it again leaves it", [statuses.stacks(STYLE_A), me.sheet.value(&"attack")],
		[0, 6.0])


func _groups(me: Combatant) -> void:
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	_use(me, _style_a)
	_use(me, _aura)
	_use(me, _style_b)
	equal("entering a form leaves the other form of its group, and not one of another group",
		[statuses.stacks(STYLE_A), statuses.stacks(STYLE_B), statuses.stacks(AURA)], [0, 1, 1])
	equal("the running forms know which is held",
		[_run(me, _style_a).stage, _run(me, _style_b).stage], [-1, 0])
	_use(me, _style_b)
	_use(me, _aura)


func _cycling(me: Combatant) -> void:
	var seen: Array[int] = []
	for i: int in 4:
		_use(me, _swords)
		seen.append(_run(me, _swords).stage)
	equal("a cycle enters its first stage, moves on with each use, wraps round, never turns off",
		seen, [0, 1, 2, 0])
	equal("only the stage held has its status on",
		[_stacks(me, SWORDS[0]), _stacks(me, SWORDS[1]), _stacks(me, SWORDS[2])], [1, 0, 0])
	_use(me, _finisher)
	equal("a power named in advance_after moves the cycle on", _run(me, _swords).stage, 1)
	_use(me, _jab)
	equal("a power not named leaves it where it is", _run(me, _swords).stage, 1)
	_use(me, _style_a)
	equal("a form of another group leaves the cycle alone", _run(me, _swords).stage, 1)
	_use(me, _style_a)


func _draining_by_seconds(me: Combatant) -> void:
	var vitals: Vitals = Vitals.of(me.get_parent())
	vitals.set_to(&"devil", 10)
	_use(me, _trigger)
	var powers: PowerSet = PowerSet.of(me.get_parent())
	powers.tick_seconds(0.5)
	powers.tick_seconds(0.5)
	equal("in the field the form drains its pool by the second, fractions carried",
		[vitals.current(&"devil"), _stacks(me, TRIGGER)], [6, 1])
	powers.tick_seconds(3.0)
	equal("at an empty pool the form ends", [vitals.current(&"devil"), _stacks(me, TRIGGER),
		_run(me, _trigger).stage], [0, 0, -1])


func _outside(me: Combatant) -> void:
	var statuses: StatusSet = StatusSet.of(me.get_parent())
	_use(me, _style_a)
	statuses.cure(STYLE_A)
	_use(me, _style_a)
	equal("a form whose status was cured from outside is off, so the next use enters it again",
		statuses.stacks(STYLE_A), 1)
	_use(me, _style_a)
	_use(me, _aura)
	statuses.tick_seconds(5.0)
	PowerSet.of(me.get_parent()).tick_seconds(0.1)
	equal("a timed form that runs out is over", [statuses.stacks(AURA), _run(me, _aura).stage],
		[0, -1])


func _draining_by_turns(me: Combatant) -> void:
	var vitals: Vitals = Vitals.of(me.get_parent())
	var powers: PowerSet = PowerSet.of(me.get_parent())
	vitals.set_to(&"devil", 5)
	_use(me, _trigger)
	powers.tick_turn()
	equal("in a battle the form drains by the turn",
		[vitals.current(&"devil"), _stacks(me, TRIGGER)], [3, 1])
	powers.tick_turn()
	powers.tick_turn()
	equal("a battle form ends at an empty pool too", [vitals.current(&"devil"), _stacks(me, TRIGGER)],
		[0, 0])


func _unequipping(me: Combatant) -> void:
	_use(me, _style_a)
	_use(me, _swords)
	PowerSet.of(me.get_parent()).unequip()
	equal("taking the kit off ends its forms", [_stacks(me, STYLE_A), _stacks(me, SWORDS[0]),
		_stacks(me, SWORDS[1]), _stacks(me, SWORDS[2]), me.sheet.value(&"attack")], [0, 0, 0, 0, 6.0])


func _use(me: Combatant, power: Power) -> bool:
	return PowerUse.use(me, power, [], _rng, NOON)


func _run(me: Combatant, power: Power) -> FormRun:
	return PowerSet.of(me.get_parent()).executor(power.power_id) as FormRun


func _stacks(me: Combatant, id: StringName) -> int:
	return StatusSet.of(me.get_parent()).stacks(id)


func _fighter(id: StringName, real_time: bool) -> Combatant:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = &"player"
	fighter.real_time = real_time
	fighter.base_stats = {&"max_hp": 60.0, &"max_devil": 100.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	attach(actor)
	_actors.append(actor)
	PowerSet.of(actor).equip(_kit())
	return fighter


func _kit() -> PowerKit:
	_style_a = _power(&"power/fixture_form_style_a", _form(STYLE_A, &"style"))
	(_style_a.mechanism as FormMechanism).status.modifiers = [
		StatModifier.of(&"attack", StatModifier.Op.ADD, 3.0, &"anything")]
	_style_b = _power(&"power/fixture_form_style_b", _form(STYLE_B, &"style"))
	_aura = _power(&"power/fixture_form_aura", _form(AURA, &"aura"))
	(_aura.mechanism as FormMechanism).status.duration = 4.0
	(_aura.mechanism as FormMechanism).status.unit = StatusEffect.Unit.SECONDS
	var trigger: FormMechanism = _form(TRIGGER, &"")
	trigger.drain_pool = &"devil"
	trigger.drain_per_second = 4.0
	trigger.drain_per_turn = 2.0
	_trigger = _power(&"power/fixture_form_trigger", trigger)
	_swords = _power(&"power/fixture_form_swords", _sword_cycle())
	_finisher = _power(&"power/fixture_form_finisher", null)
	_jab = _power(&"power/fixture_form_jab", null)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_form"
	kit.name_key = "fixture.kit"
	kit.powers = [_style_a, _style_b, _aura, _trigger, _swords, _finisher, _jab]
	return kit


func _sword_cycle() -> FormMechanism:
	var cycle := FormMechanism.new()
	cycle.exclusive_group = &"sword"
	cycle.advance_after = [&"power/fixture_form_finisher"]
	for id: StringName in SWORDS:
		cycle.cycle.append(_form(id, &""))
	return cycle


func _form(id: StringName, group: StringName) -> FormMechanism:
	var form := FormMechanism.new()
	form.status = _status(id, 0.0)
	form.exclusive_group = group
	return form


# A power with no skill runs its mechanism alone; one with neither is a plain no-cost skill.
func _power(id: StringName, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	if mechanism == null:
		var skill := Skill.new()
		skill.id = StringName(String(id).replace("power/", "skill/"))
		skill.name_key = "fixture.skill"
		skill.toggle_status = _status(StringName(String(id).replace("power/", "status/")), 0.0)
		power.skill = skill
	return power


func _status(id: StringName, duration: float) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = duration
	return status
