extends TestCase
## A form's own commands (C6.5e): while a form is held the menus offer its commands in place of
## the fighter's own, a battle's plain Attack becomes the form's skill, and the form's aftermath
## goes on when it ends by its own rules (used again, drained dry, timed out) and never when a
## rival replaces it, a cure takes it off or the kit comes off.
##
## OWNS: assertions about `FormMechanism.commands`/`replaces_attack`/`aftermath`, `FormRun`'s
## `commands_of`/`attack_of` and aftermath, `PowerMenu.with_powers` and `Battle`'s Attack.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const FORM: StringName = &"status/fixture_cmd_form"
const RIVAL: StringName = &"status/fixture_cmd_rival"
const TIMED: StringName = &"status/fixture_cmd_timed"
const PRICE: StringName = &"status/fixture_cmd_price"

var _rng := RandomNumberGenerator.new()
var _form: Power
var _rival: Power
var _timed: Power
var _blast: Skill
var _offered: Array[BattleCommand] = []
var _form_menu: Array[BattleCommand] = []


func run() -> void:
	plan(16)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	_blast = _skill()
	_offered = [_command(BattleCommand.Kind.ATTACK, null), _command(BattleCommand.Kind.DEFEND, null)]
	_form_menu = [_command(BattleCommand.Kind.SKILL, _blast)]
	_content()
	_menus()
	_aftermath()
	_in_a_battle()
	Flags.clear_all()


func _content() -> void:
	var kit: PowerKit = _kit()
	equal("a form with commands, an attack and an aftermath is clean", kit.problems("x").size(), 0)
	var broken := FormMechanism.new()
	broken.status = _status(FORM, 0.0)
	broken.commands = [null, _command(BattleCommand.Kind.SKILL, null)]
	equal("an empty command and a skill command with no skill are two problems",
		broken.problems("x").size(), 2)
	var stage := FormMechanism.new()
	stage.status = _status(TIMED, 0.0)
	var cycle := FormMechanism.new()
	cycle.cycle = [stage]
	cycle.commands = _form_menu
	cycle.replaces_attack = _blast
	var own := FormMechanism.new()
	own.status = _status(RIVAL, 0.0)
	own.replaces_attack = _skill()
	cycle.cycle.append(own)
	equal("a stage's own commands and attack, else the cycle's",
		[cycle.commands_at(0), cycle.attack_at(0), cycle.attack_at(1) == _blast, cycle.commands_at(1)],
		[_form_menu, _blast, false, _form_menu])
	equal("a form's aftermath is a status its kit can find, so a save keeps it",
		kit.status(PRICE) != null, true)


func _menus() -> void:
	var body: Node3D = _body(&"fixture_cmd_menus")
	var user: Combatant = Combatant.of(body)
	var powers: int = PowerMenu.commands(user).size()
	equal("out of every form the menu is the fighter's own, then its powers",
		[PowerMenu.with_powers(_offered, user).slice(0, 2), PowerMenu.with_powers(_offered, user).size(),
			FormRun.attack_of(body)], [_offered, 2 + powers, null])
	_use(body, _form)
	var listed: Array[BattleCommand] = PowerMenu.with_powers(_offered, user)
	equal("in the form its own commands stand in, the powers still follow",
		[listed[0], listed.size()], [_form_menu[0], 1 + powers])
	_use(body, _form)
	_use(body, _rival)
	listed = PowerMenu.with_powers(_offered, user)
	equal("a form with no commands keeps the menu, the Attack row named after its skill",
		[listed[0].kind, listed[0].label_key, listed[1], _offered[0].label_key],
		[BattleCommand.Kind.ATTACK, _blast.name_key, _offered[1], ""])
	body.free()


func _aftermath() -> void:
	var body: Node3D = _body(&"fixture_cmd_after")
	var statuses: StatusSet = StatusSet.of(body)
	_use(body, _form)
	_use(body, _form)
	equal("leaving by using it again puts the aftermath on", statuses.stacks(PRICE), 1)
	statuses.cure(PRICE)
	_use(body, _form)
	_use(body, _rival)
	equal("a rival of its group replacing it gives none", [statuses.stacks(FORM), statuses.stacks(PRICE)], [0, 0])
	_use(body, _form)
	statuses.cure(FORM)
	equal("a cure from outside gives none", statuses.stacks(PRICE), 0)
	_use(body, _form)
	PowerSet.of(body).tick_seconds(3.0)
	equal("drained dry, the form ends with its aftermath",
		[statuses.stacks(FORM), statuses.stacks(PRICE), Vitals.of(body).current(&"mp")], [0, 1, 0])
	statuses.cure(PRICE)
	Vitals.of(body).change(&"mp", 99)
	_use(body, _timed)
	statuses.tick_seconds(5.0)
	equal("a timed form running out gives its aftermath", [statuses.stacks(TIMED), statuses.stacks(PRICE)], [0, 1])
	statuses.cure(PRICE)
	_use(body, _form)
	PowerSet.of(body).unequip()
	equal("the kit coming off gives none", [statuses.stacks(FORM), statuses.stacks(PRICE)], [0, 0])
	body.free()


func _in_a_battle() -> void:
	var holder := Node.new()
	attach(holder)
	var hero: CombatantDef = _def(&"fixture_cmd_hero", &"side_a", 9.0)
	hero.power_kit = _kit()
	var foe: CombatantDef = _def(&"fixture_cmd_foe", &"side_b", 1.0)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_cmd"
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], holder, _rng)
	var fighter: Combatant = battle.party[0]
	var target: Combatant = battle.enemies[0]
	var attack: BattleCommand = _offered[0]
	battle.next_turn()
	var before: int = Vitals.of(fighter.get_parent()).current(&"mp")
	battle.act(attack, [target])
	equal("out of a form Attack is a plain hit, costing nothing",
		Vitals.of(fighter.get_parent()).current(&"mp"), before)
	_use(fighter.get_parent(), _rival)
	var guard: BattleCommand = _offered[1]
	while battle.next_turn() != fighter:
		battle.act(guard, [])
	var as_skill: BattleCommand = _command(BattleCommand.Kind.SKILL, _blast)
	equal("in the form Attack is aimed as its skill", battle.targets_for(attack), battle.targets_for(as_skill))
	var hp: int = Vitals.of(target.get_parent()).current(&"hp")
	equal("and done as it: paid for, and hitting through the skill",
		[battle.act(attack, [target]), Vitals.of(fighter.get_parent()).current(&"mp"),
			Vitals.of(target.get_parent()).current(&"hp") < hp], [true, before - 5, true])
	BattleSetup.release(battle)
	holder.free()


func _use(body: Node, power: Power) -> bool:
	return PowerUse.use(Combatant.of(body), power, [], _rng, NOON)


func _body(id: StringName) -> Node3D:
	var body := Node3D.new()
	attach(body)
	var made := ActionLoadout.new()
	made.fighter = _def(id, &"player", 5.0)
	made.fighter.power_kit = _kit()
	made.moves = MoveSet.new()
	ActionHost.fit_identity(body, made)
	return body


func _kit() -> PowerKit:
	var price: StatusEffect = _status(PRICE, 0.0)
	var form := FormMechanism.new()
	form.status = _status(FORM, 0.0)
	form.exclusive_group = &"style"
	form.commands = _form_menu
	form.aftermath = price
	form.drain_pool = &"mp"
	form.drain_per_second = 10.0
	form.drain_per_turn = 10.0
	var rival := FormMechanism.new()
	rival.status = _status(RIVAL, 0.0)
	rival.exclusive_group = &"style"
	rival.replaces_attack = _blast
	var timed := FormMechanism.new()
	timed.status = _status(TIMED, 4.0)
	timed.aftermath = price
	_form = _power("form", form)
	_rival = _power("rival", rival)
	_timed = _power("timed", timed)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_cmd"
	kit.name_key = "fixture.kit"
	kit.powers = [_form, _rival, _timed]
	return kit


func _power(short: String, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_cmd_" + short)
	power.name_key = "fixture.power_" + short
	power.mechanism = mechanism
	return power


func _skill() -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture_cmd_blast"
	skill.name_key = "fixture.skill.blast"
	skill.power = 6.0
	skill.cost_pool = &"mp"
	skill.cost = 5
	skill.sure_hit = true
	return skill


func _command(kind: BattleCommand.Kind, skill: Skill) -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = kind
	command.skill = skill
	return command


func _status(id: StringName, seconds: float) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	if seconds > 0.0:
		status.unit = StatusEffect.Unit.SECONDS
		status.duration = seconds
	return status


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 2.0, &"defence": 1.0}
	def.level_curve = LevelCurve.new()
	return def
