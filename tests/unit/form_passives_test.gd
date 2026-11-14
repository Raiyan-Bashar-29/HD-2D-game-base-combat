extends TestCase
## A form's own passives (C9.6a): `FormMechanism.passive_skills` are held while the form is held.
##
## HOW IT COUNTS: the passives built by `_wakes` take MP from the holder when they wake (1 for a
## form entered, 10 for a form left), so the MP spent says which of them heard which moment.
##
## OWNS: assertions about `FormMechanism.passives_at`, `PassiveLending.form` and the lending in
## `FormRun`.
## MUST NOT: name a game's passives, powers or fighters, or wait for frames.

const E := PassiveTrigger.Event
const NOON: float = 12.0
const SHELL: StringName = &"status/fixture_fp_shell"
const PLAIN: StringName = &"power/fixture_fp_plain"
const CYCLE: StringName = &"power/fixture_fp_cycle"
const DRAIN: StringName = &"power/fixture_fp_drain"

var _rng := RandomNumberGenerator.new()
var _me: Node3D
var _shell: PassiveSkill
var _stage_own: PassiveSkill


func run() -> void:
	plan(10)
	Flags.clear_all()
	_rng.seed = 7
	_shell = _holds(&"passive/fixture_fp_shell", SHELL)
	_stage_own = _holds(&"passive/fixture_fp_stage", &"status/fixture_fp_stage_own")
	_shapes()
	_start()
	_plain()
	_cycle()
	_ends()
	_me.free()
	Flags.clear_all()


func _shapes() -> void:
	var form: FormMechanism = _form(&"status/fixture_fp_shape", [_shell, null])
	equal("an empty passive on a form is a problem, and a sound list is none",
		[form.problems("fixture").size(), _form(&"status/fixture_fp_shape", [_shell])
			.problems("fixture").size()], [1, 0])
	var cycle: FormMechanism = _cycle_form()
	equal("a stage lends its own passives, a stage with none the cycle's, a plain form its own",
		[cycle.passives_at(0), cycle.passives_at(1), form.passives_at(0).size()],
		[[_stage_own], [_shell], 2])


func _plain() -> void:
	var me: Combatant = Combatant.of(_me)
	equal("before the form, the fighter holds none of its passives",
		[PassiveSet.of(_me) == null, _stacks(SHELL)], [true, 0])
	_use(PLAIN)
	equal("entering lends them under the form's power: the held status is on, and the form's "
			+ "own passive heard the form go on",
		[PassiveSet.of(_me).sources(), _stacks(SHELL), _spent()],
		[[StringName(PassiveLending.FORM_PREFIX + String(PLAIN))], 1, 1])
	equal("the shell's modifier is on the sheet", me.sheet.value(&"defence"), 5.0)
	_use(PLAIN)
	equal("leaving takes them back, after the passive heard the form go off",
		[PassiveSet.of(_me).sources().size(), _stacks(SHELL), _spent(), me.sheet.value(&"defence")],
		[0, 0, 11, 1.0])


func _cycle() -> void:
	_use(CYCLE)
	var first: Array = [_stacks(&"status/fixture_fp_stage_own"), _stacks(SHELL)]
	_use(CYCLE)
	equal("moving to the next stage swaps the stage's passives for the cycle's",
		[first, _stacks(&"status/fixture_fp_stage_own"), _stacks(SHELL)], [[1, 0], 0, 1])
	StatusSet.of(_me).cure(&"status/fixture_fp_cycle_2")
	PowerSet.of(_me).tick_turn()
	equal("a form cured from outside gives its passives back when it is next read",
		[PassiveSet.of(_me).sources().size(), _stacks(SHELL)], [0, 0])


func _ends() -> void:
	Vitals.of(_me).set_to(&"devil", 2)
	_use(DRAIN)
	var held: int = _stacks(SHELL)
	PowerSet.of(_me).tick_turn()
	equal("a form drained dry gives them back", [held, _stacks(SHELL)], [1, 0])
	_use(PLAIN)
	PowerSet.of(_me).unequip()
	equal("taking the kit off gives them back", [PassiveSet.of(_me).sources().size(),
		_stacks(SHELL)], [0, 0])


func _use(power_id: StringName) -> void:
	for power: Power in PowerSet.of(_me).kit.powers:
		if power.power_id == power_id:
			PowerUse.use(Combatant.of(_me), power, [], _rng, NOON)


func _stacks(id: StringName) -> int:
	return StatusSet.of(_me).stacks(id)


func _spent() -> int:
	return 100 - Vitals.of(_me).current(&"mp")


func _start() -> void:
	_me = Node3D.new()
	_me.add_child(Vitals.new())
	_me.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = &"fixture_fp_holder"
	fighter.faction = &"player"
	fighter.base_stats = {&"max_hp": 60.0, &"max_mp": 100.0, &"max_devil": 100.0,
		&"attack": 6.0, &"defence": 1.0}
	_me.add_child(fighter)
	_me.add_child(PowerSet.new())
	attach(_me)
	var drain: FormMechanism = _form(&"status/fixture_fp_drain", [_shell])
	drain.drain_pool = &"devil"
	drain.drain_per_turn = 2.0
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_fp"
	kit.name_key = "fixture.kit"
	kit.powers = [_power(PLAIN, _form(&"status/fixture_fp_plain", [_shell, _wakes()])),
		_power(CYCLE, _cycle_form()), _power(DRAIN, drain)]
	PowerSet.of(_me).equip(kit)


func _cycle_form() -> FormMechanism:
	var cycle := FormMechanism.new()
	cycle.passive_skills = [_shell]
	cycle.cycle = [_form(&"status/fixture_fp_cycle_1", [_stage_own]),
		_form(&"status/fixture_fp_cycle_2", [])]
	return cycle


func _form(status_id: StringName, passives: Array[PassiveSkill]) -> FormMechanism:
	var form := FormMechanism.new()
	form.status = _status(status_id)
	form.passive_skills = passives
	return form


func _power(id: StringName, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = id
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	return power


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.duration = 0.0
	return status


# A passive that holds status `held_id`, which adds 4 defence.
func _holds(id: StringName, held_id: StringName) -> PassiveSkill:
	var passive := PassiveSkill.new()
	passive.id = id
	passive.name_key = "fixture.passive"
	passive.held = _status(held_id)
	passive.held.modifiers = [StatModifier.of(&"defence", StatModifier.Op.ADD, 4.0, &"")]
	return passive


# A passive that takes 1 MP when a form is entered and 10 when one is left.
func _wakes() -> PassiveSkill:
	var passive := PassiveSkill.new()
	passive.id = &"passive/fixture_fp_wakes"
	passive.name_key = "fixture.passive"
	for cost: int in [1, 10]:
		var effect := PassiveEffect.new()
		effect.kind = PassiveEffect.Kind.POOL_FLAT
		effect.pool = &"mp"
		effect.amount = -float(cost)
		var trigger := PassiveTrigger.new()
		trigger.event = E.FORM_ENTERED if cost == 1 else E.FORM_LEFT
		trigger.effects = [effect]
		passive.triggers.append(trigger)
	return passive
