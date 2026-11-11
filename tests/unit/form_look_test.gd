extends TestCase
## Transformations you can see (C6.5d): a form's look goes on the body while it is held and comes
## off when it ends, however it ends; a cycle stage shows its own look and name or the cycle's;
## each body shows the member on it after a party switch; and the battle screen and the HUD name
## the form only while it is held.
##
## OWNS: assertions about `LookDef`, `FormMechanism.look_at`/`name_at`, `LookSwap`, and the form's
## name on `BattleScreen.name_of` and `CombatHud`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const NOON: float = 12.0
const FORM: StringName = &"status/fixture_look_form"
const STAGE_0: StringName = &"status/fixture_look_stage_0"
const STAGE_1: StringName = &"status/fixture_look_stage_1"

var _rng := RandomNumberGenerator.new()
var _player: PlayerController
var _form: Power
var _cycle: Power
var _red: LookDef
var _stage_look: LookDef
var _cycle_look: LookDef
var _the_kit: PowerKit


func run() -> void:
	plan(17)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 5
	_red = _look(&"look/fixture_red", Color(1.0, 0.25, 0.25), 1.5, "fixture.look.red")
	_stage_look = _look(&"look/fixture_stage", Color(0.25, 0.25, 1.0), 1.25, "")
	_cycle_look = _look(&"look/fixture_cycle", Color(0.25, 1.0, 0.25), 0.8, "fixture.look.cycle")
	_content()
	_the_kit = _kit()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	var lead: ActionLoadout = _loadout(&"fixture_look_lead", _the_kit)
	lead.companions = [_loadout(&"fixture_look_mate", null)]
	ActionHost.equip(_player, lead)
	_on_the_body()
	_no_visual()
	_switch(lead)
	_in_a_battle()
	_player.free()
	Flags.clear_all()


func _content() -> void:
	equal("a clean look has no problems", _red.problems("x").size(), 0)
	equal("a look with no id and no size is two problems", _look(&"", Color.WHITE, 0.0, "").problems("x").size(), 2)
	var form := FormMechanism.new()
	form.status = _status(FORM)
	form.look = _look(&"", Color.WHITE, 1.0, "")
	equal("a form reports its look's problems", form.problems("x").size(), 1)
	var cycle: FormMechanism = _cycle_mechanism()
	equal("a stage shows its own look and name, else the cycle's",
		[cycle.look_at(0), cycle.look_at(1), cycle.name_at(0), cycle.name_at(1), cycle.look_at(-1)],
		[_stage_look, _cycle_look, "fixture.form.stage", "fixture.form.cycle", _cycle_look])


func _on_the_body() -> void:
	var swap: LookSwap = _swap(_player)
	var visual: CharacterVisual = _player.get_node(^"Visual") as CharacterVisual
	var tint: Color = visual.sprite.modulate
	var size: Vector3 = visual.scale
	equal("every field body gets a look swap, and out of every form it shows nothing",
		[swap != null, LookSwap.look_of(_player), LookSwap.form_name_key(_player)], [true, null, ""])
	_use(_form)
	swap.watch()
	var tag: Label3D = _player.get_node_or_null(^"LookTag") as Label3D
	equal("entering a form tints, sizes and tags the body",
		[visual.sprite.modulate.is_equal_approx(tint * _red.tint), visual.scale.is_equal_approx(size * 1.5),
			tag != null and tag.text == tr("fixture.look.red"), swap.current], [true, true, true, _red])
	_use(_form)
	swap.watch()
	equal("leaving it puts the body back",
		[visual.sprite.modulate.is_equal_approx(tint), visual.scale.is_equal_approx(size),
			_player.get_node_or_null(^"LookTag") == null, swap.current], [true, true, true, null])
	_use(_form)
	swap.watch()
	StatusSet.of(_player).cure(FORM)
	swap.watch()
	equal("a cure from outside puts it back too", [visual.scale.is_equal_approx(size), swap.current], [true, null])
	_use(_cycle)
	swap.watch()
	var first: Array = [swap.current, visual.scale.is_equal_approx(size * 1.25), LookSwap.form_name_key(_player)]
	_use(_cycle)
	swap.watch()
	equal("a cycle shows each stage's look, never piling sizes up",
		[first, [swap.current, visual.scale.is_equal_approx(size * 0.8), LookSwap.form_name_key(_player)]],
		[[_stage_look, true, "fixture.form.stage"], [_cycle_look, true, "fixture.form.cycle"]])
	_on_the_hud(swap)


func _on_the_hud(swap: LookSwap) -> void:
	var hud := CombatHud.new()
	attach(hud)
	hud.subject = _player
	hud.refresh()
	equal("the HUD's line leads with the form held", hud.text.begins_with(tr("fixture.form.cycle")), true)
	_use(_form)
	swap.watch()
	equal("entering a rival form of the group shows that one's look", swap.current, _red)
	_use(_form)
	hud.refresh()
	equal("out of every form, the HUD names none", hud.text.contains("fixture.form"), false)
	hud.free()
	swap.watch()


func _no_visual() -> void:
	var body := Node3D.new()
	attach(body)
	ActionHost.fit_identity(body, _loadout(&"fixture_look_bare", _the_kit))
	var run: PowerSet = PowerSet.of(body)
	PowerUse.use(Combatant.of(body), run.powers()[0], [], _rng, NOON)
	_swap(body).watch()
	equal("a body with no visual is left alone, the look still known",
		[_swap(body).current, body.get_node_or_null(^"LookTag") == null], [_red, true])
	body.free()


func _switch(lead: ActionLoadout) -> void:
	var line: Array[PartyFollower] = FieldParty.spawn(_player, lead)
	var mate: PartyFollower = line[0]
	_use(_form)
	_swap(_player).watch()
	FieldParty.switch(_player)
	_swap(_player).watch()
	_swap(mate).watch()
	equal("after a switch each body shows the member now on it",
		[_swap(_player).current, _swap(mate).current, (mate.get_node(^"Visual") as Node3D).scale.x > 1.0],
		[null, _red, true])
	FieldParty.switch(_player)
	_swap(_player).watch()
	_swap(mate).watch()
	equal("and switching back moves the look back",
		[_swap(_player).current, _swap(mate).current], [_red, null])
	_use(_form)
	_swap(_player).watch()
	mate.free()


func _in_a_battle() -> void:
	var holder := Node.new()
	attach(holder)
	var hero: CombatantDef = _loadout(&"fixture_look_hero", _the_kit).fighter
	var foe: CombatantDef = _loadout(&"fixture_look_foe", null).fighter
	hero.faction = &"side_a"
	foe.faction = &"side_b"
	foe.brain = BattleBrain.new()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_look"
	encounter.enemies = [foe]
	var battle := BattleSetup.build(encounter, [hero], holder, _rng)
	var fighter: Combatant = battle.party[0]
	var screen := BattleScreen.for_battle(battle)
	var plain: String = screen.name_of(fighter)
	PowerUse.use(fighter, PowerSet.of(fighter.get_parent()).powers()[0], [], _rng, NOON)
	var formed: String = screen.name_of(fighter)
	equal("in a battle the fighter's name carries its form's",
		formed, tr(BattleScreen.FORM_TITLE_KEY).format({"name": plain, "form": tr("fixture.form.red")}))
	PowerUse.use(fighter, PowerSet.of(fighter.get_parent()).powers()[0], [], _rng, NOON)
	equal("and only while it is held", [screen.name_of(fighter), tr(BattleScreen.FORM_TITLE_KEY) != BattleScreen.FORM_TITLE_KEY],
		[plain, true])
	screen.free()
	holder.free()


func _swap(body: Node) -> LookSwap:
	for child: Node in body.get_children():
		if child is LookSwap:
			return child as LookSwap
	return null


func _use(power: Power) -> bool:
	return PowerUse.use(Combatant.of(_player), power, [], _rng, NOON)


func _kit() -> PowerKit:
	var form := FormMechanism.new()
	form.status = _status(FORM)
	form.exclusive_group = &"style"
	form.look = _red
	form.name_key = "fixture.form.red"
	_form = _power("form", form)
	_cycle = _power("cycle", _cycle_mechanism())
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_look"
	kit.name_key = "fixture.kit"
	kit.powers = [_form, _cycle]
	return kit


func _cycle_mechanism() -> FormMechanism:
	var stage_0 := FormMechanism.new()
	stage_0.status = _status(STAGE_0)
	stage_0.look = _stage_look
	stage_0.name_key = "fixture.form.stage"
	var stage_1 := FormMechanism.new()
	stage_1.status = _status(STAGE_1)
	var cycle := FormMechanism.new()
	cycle.cycle = [stage_0, stage_1]
	cycle.exclusive_group = &"style"
	cycle.look = _cycle_look
	cycle.name_key = "fixture.form.cycle"
	return cycle


func _power(short: String, mechanism: FormMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_look_" + short)
	power.name_key = "fixture.power_" + short
	power.mechanism = mechanism
	return power


func _look(id: StringName, tint: Color, size: float, label: String) -> LookDef:
	var look := LookDef.new()
	look.look_id = id
	look.tint = tint
	look.scale = size
	look.label_key = label
	return look


func _status(id: StringName) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	return status


func _loadout(id: StringName, kit: PowerKit) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made
