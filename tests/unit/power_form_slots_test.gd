extends TestCase
## Forms, their quick slots and saves (C6.5c): a kit finds the statuses it grants (a passive, a
## form's, a cycle stage's); a power that needs a form of its kit takes a quick slot only while
## that form is held, so each form has its own four; and a form held when the game was saved is
## held again after a load, while a new game ends it.
##
## OWNS: assertions about `PowerMechanism.statuses`, `PowerKit.status`, `PowerSlots` with forms,
## and a form's status through a save.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const SLOT: int = 3
const BASE_ATTACK: float = 5.0
const FORM_A: StringName = &"status/fixture_fslots_a"
const FORM_B: StringName = &"status/fixture_fslots_b"
const STAGE: StringName = &"status/fixture_fslots_stage"
const AURA: StringName = &"status/fixture_fslots_aura"
const OUTSIDE: StringName = &"status/fixture_fslots_outside"

var _rng := RandomNumberGenerator.new()
var _player: PlayerController
var _kit: PowerKit
var _form_a: Power
var _form_b: Power
var _chain: ActionMove = ActionMove.new()


func run() -> void:
	plan(14)
	SaveFixture.activate()
	# Director's section asks for an area change on load; core_test's precedent.
	SaveSystem.unregister(&"world")
	Flags.clear_all()
	_rng.seed = 9
	_kit = _build_kit()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout())
	_content()
	_slots()
	_saves()
	_player.free()
	SaveSystem.delete_slot(SLOT)
	Flags.clear_all()


func _content() -> void:
	equal("a mechanism grants no statuses unless it says so", PowerMechanism.new().statuses().size(), 0)
	equal("a kit finds a passive, a form's status and a cycle stage's status",
		[_kit.status(AURA) != null, _kit.status(FORM_A) != null, _kit.status(STAGE) != null], [true, true, true])
	equal("and nothing for a status it does not grant", _kit.status(OUTSIDE), null)


func _slots() -> void:
	equal("out of every form, the slots hold the forms and the powers that need no form of the kit",
		_slot_ids(), ["form_a", "form_b", "outside", "plain"])
	_use(_form_a)
	equal("in a form, its own powers take their slots, and the other form's do not",
		_slot_ids(), ["form_a", "a1", "a2", "form_b"])
	var hud := CombatHud.new()
	attach(hud)
	equal("the HUD's slot line shows the form's powers",
		[hud.slot_text(_me()).contains("fixture.a1"), hud.slot_text(_me()).contains("fixture.b1")], [true, false])
	hud.free()
	var powers: PowerSet = PowerSet.of(_player)
	equal("a slot key uses the power sitting there now",
		[PowerSlots.press(_me(), 1, _rng), powers.cooldown_left(&"power/fixture_fslots_a1")], [true, 2.0])
	_use(_form_b)
	equal("changing form changes the slots", _slot_ids(), ["form_a", "form_b", "b1", "outside"])
	_use(_form_b)


func _saves() -> void:
	var statuses: StatusSet = StatusSet.of(_player)
	var sheet: StatSheet = _me().sheet
	var powers: PowerSet = PowerSet.of(_player)
	_use(_form_a)
	equal("the save works", SaveSystem.save_to_slot(SLOT), OK)
	_use(_form_a)
	equal("the form was left before the load", [statuses.stacks(FORM_A), sheet.value(&"attack")], [0, BASE_ATTACK])
	equal("the load works", SaveSystem.load_from_slot(SLOT), OK)
	var run: FormRun = powers.executor(_form_a.power_id) as FormRun
	run.tick(0.0)
	equal("a form held when the game was saved is held again, its change counted once",
		[statuses.stacks(FORM_A), sheet.value(&"attack"), run.stage], [1, BASE_ATTACK + 3.0, 0])
	equal("and it plays its moves and owns its slots again",
		[powers.moves_over(MoveSet.new()).attack_chain, _slot_ids()], [[_chain], ["form_a", "a1", "a2", "form_b"]])
	Events.game_started.emit()
	run.tick(0.0)
	equal("a new game ends the form, and the passive stays",
		[statuses.stacks(FORM_A), run.stage, statuses.stacks(AURA)], [0, -1, 1])


# The slotted powers, as the short end of each id.
func _slot_ids() -> Array[String]:
	var out: Array[String] = []
	for power: Power in PowerSlots.powers(_me()):
		out.append(String(power.power_id).replace("power/fixture_fslots_", ""))
	return out


func _me() -> Combatant:
	return Combatant.of(_player)


func _use(power: Power) -> bool:
	return PowerUse.use(_me(), power, [], _rng, NOON)


func _build_kit() -> PowerKit:
	var form_a := FormMechanism.new()
	form_a.status = _status(FORM_A)
	form_a.status.modifiers = [StatModifier.of(&"attack", StatModifier.Op.ADD, 3.0, &"fixture")]
	form_a.exclusive_group = &"style"
	form_a.attack_chain = [_chain]
	var stage := FormMechanism.new()
	stage.status = _status(STAGE)
	var form_b := FormMechanism.new()
	form_b.cycle = [_form(FORM_B), stage]
	form_b.exclusive_group = &"style"
	_form_a = _power("form_a", form_a, &"")
	_form_b = _power("form_b", form_b, &"")
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_fslots"
	kit.name_key = "fixture.kit"
	kit.passives = [_status(AURA)]
	kit.powers = [_form_a, _power("a1", null, FORM_A), _power("a2", null, FORM_A), _form_b,
		_power("b1", null, FORM_B), _power("outside", null, OUTSIDE), _power("plain", null, &"")]
	return kit


func _form(id: StringName) -> FormMechanism:
	var form := FormMechanism.new()
	form.status = _status(id)
	return form


# A power named `short`: a form when given a mechanism, else a free skill on a 2 s cooldown that
# needs the status `needs`, if any.
func _power(short: String, mechanism: FormMechanism, needs: StringName) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_fslots_" + short)
	power.name_key = "fixture." + short
	power.mechanism = mechanism
	if needs != &"":
		power.requires_statuses = [needs]
	if mechanism == null:
		var skill := Skill.new()
		skill.id = StringName("skill/fixture_fslots_" + short)
		skill.name_key = "fixture.skill"
		skill.target = FactionTable.Target.SELF
		power.skill = skill
		power.cooldown = 2.0
	return power


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_fslots_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": BASE_ATTACK}
	def.level_curve = LevelCurve.new()
	def.power_kit = _kit
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made
