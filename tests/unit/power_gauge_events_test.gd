extends TestCase
## The other gauge events (C6.4b): a kill of the holder's own, an ally falling, a move started
## that differs from the last, points of another pool spent as a cost, and a running second on
## top of a moving one; and the HUD shows a gauge and its level with no code of its own.
##
## OWNS: assertions about `on_kill`, `on_ally_defeated`, `on_new_move`, `on_spent` and
## `per_running_second`, through `PowerSet`, `SkillUse.pay` and `ActionFighter`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const ME: StringName = &"fixture_events_hero"
const LOW: StringName = &"status/fixture_events_low"
const AILMENT: StringName = &"status/fixture_events_ailment"

var _player: PlayerController
var _ally: Node3D
var _foe: Node3D
var _swing := ActionMove.new()
var _other := ActionMove.new()
var _roll := ActionMove.new()
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(16)
	_rng.seed = 11
	Flags.clear_all()
	var lone := GaugeRule.new()
	lone.pool = &"focus"
	lone.on_spent = 1.0
	equal("filling on spending with no pool spent is a problem", lone.problems("fixture").size(), 1)
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout())
	_ally = _fighter(&"fixture_events_ally", &"player", Vector3(2, 0, 0))
	_foe = _fighter(&"fixture_events_foe", &"enemy", Vector3(0, 0, -2))
	_kills()
	_fallen()
	_spending()
	_running()
	_moves()
	_hud()
	_ally.free()
	_foe.free()
	_player.free()
	Flags.clear_all()


func _kills() -> void:
	var me: Combatant = Combatant.of(_player)
	me.hit(Combatant.of(_foe), 1.0, &"", _rng, true)
	equal("a hit that leaves the foe standing is no kill", [Vitals.of(_foe).is_defeated(), _focus()],
		[false, 0])
	Vitals.of(_foe).set_to(&"hp", 1)
	me.hit(Combatant.of(_foe), 1.0, &"", _rng, true)
	equal("felling the foe adds on_kill, and reaching a level holds its status",
		[Vitals.of(_foe).is_defeated(), _focus(), StatusSet.of(_player).stacks(LOW)], [true, 30, 1])
	Vitals.of(_foe).revive(1)
	Combatant.of(_ally).hit(Combatant.of(_foe), 1.0, &"", _rng, true)
	equal("a foe felled by someone else is not the holder's kill",
		[Vitals.of(_foe).is_defeated(), _focus()], [true, 30])
	equal("every combatant can be found by its id",
		Combatant.find(_player.get_tree(), &"fixture_events_ally"), Combatant.of(_ally))


func _fallen() -> void:
	Vitals.of(_ally).set_to(&"hp", 0)
	equal("an ally falling adds on_ally_defeated", _focus(), 35)
	Vitals.of(_foe).revive(5)
	Vitals.of(_foe).set_to(&"hp", 0)
	equal("a foe falling to something else adds nothing", _focus(), 35)


func _spending() -> void:
	var me: Combatant = Combatant.of(_player)
	SkillUse.pay(me, _skill(&"mp", 6))
	equal("6 points of the spent pool paid give 2 at a third a point", [_mp(), _arts()], [14, 2])
	SkillUse.pay(me, _skill(&"hp", 3))
	equal("a cost paid from another pool gives nothing", _arts(), 2)
	var ailment := StatusEffect.new()
	ailment.id = AILMENT
	ailment.duration = 0.0
	ailment.tags = [&"ailment"]
	StatusSet.of(_player).apply(ailment)
	SkillUse.pay(me, _skill(&"mp", 6))
	equal("a blocked rule does not fill on spending", [_mp(), _arts()], [8, 2])
	StatusSet.of(_player).cure(AILMENT)


func _running() -> void:
	var powers: PowerSet = PowerSet.of(_player)
	_player.velocity = Vector3(5.0, 0.0, 0.0)
	_player.state = GameEnums.MoveState.WALK
	powers.tick_seconds(1.0)
	equal("a walking second adds only per_moving_second", _focus(), 39)
	_player.state = GameEnums.MoveState.RUN
	powers.tick_seconds(1.0)
	equal("a running second adds per_running_second on top, and the level drops",
		[_focus(), StatusSet.of(_player).stacks(LOW)], [24, 0])
	_player.velocity = Vector3.ZERO
	_player.state = GameEnums.MoveState.IDLE


func _moves() -> void:
	var powers: PowerSet = PowerSet.of(_player)
	powers.moved(_swing)
	powers.moved(_swing)
	powers.moved(_other)
	equal("only a move unlike the last one adds on_new_move", _focus(), 28)
	var fighter: ActionFighter = _action_fighter()
	fighter.drive(0.0, true, false)
	equal("the fighter tells the kit about the swing it starts", _focus(), 30)
	fighter.drive(5.0, false, false)
	fighter.drive(0.0, false, true)
	fighter.drive(5.0, false, false)
	fighter.drive(0.0, true, false)
	equal("a dodge is no move, so the same swing after it is not new",
		[fighter.timeline.swing, _focus()], [3, 30])


func _hud() -> void:
	var hud := CombatHud.new()
	hud.subject = _player
	attach(hud)
	hud.refresh()
	equal("the HUD shows the gauge and its level with no code of its own",
		[hud.text.contains("FOCUS 30 / 100"), hud.text.contains("fixture_events_low")], [true, true])
	hud.free()


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = ME
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0, &"attack": 6.0, &"defence": 1.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = _kit()
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	loadout.moves.attack_chain = [_swing]
	loadout.moves.dodge = _roll
	return loadout


func _kit() -> PowerKit:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_events"
	kit.name_key = "fixture.kit"
	kit.stat_bonuses = [StatModifier.of(&"max_focus", StatModifier.Op.ADD, 100.0, &"any"),
		StatModifier.of(&"start_focus", StatModifier.Op.ADD, 0.0, &"any"),
		StatModifier.of(&"max_arts", StatModifier.Op.ADD, 100.0, &"any"),
		StatModifier.of(&"start_arts", StatModifier.Op.ADD, 0.0, &"any")]
	var low := StatusEffect.new()
	low.id = LOW
	low.duration = 0.0
	var focus := GaugeRule.new()
	focus.pool = &"focus"
	focus.on_kill = 30.0
	focus.on_ally_defeated = 5.0
	focus.on_new_move = 2.0
	focus.per_moving_second = 4.0
	focus.per_running_second = -19.0
	focus.levels = {30: low}
	var arts := GaugeRule.new()
	arts.pool = &"arts"
	arts.spent_pool = &"mp"
	arts.on_spent = 0.3334
	arts.blocked_by_tags = [&"ailment"]
	kit.gauges = [focus, arts]
	return kit


func _skill(pool: StringName, cost: int) -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture_events"
	skill.name_key = "fixture.skill"
	skill.cost_pool = pool
	skill.cost = cost
	return skill


func _fighter(id: StringName, faction: StringName, offset: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = _player.global_position + offset
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.base_stats = {&"max_hp": 60.0, &"attack": 6.0, &"defence": 1.0}
	actor.add_child(fighter)
	attach(actor)
	return actor


func _action_fighter() -> ActionFighter:
	for child: Node in _player.get_children():
		if child is ActionFighter:
			return child as ActionFighter
	return null


func _focus() -> int:
	return Vitals.of(_player).current(&"focus")


func _arts() -> int:
	return Vitals.of(_player).current(&"arts")


func _mp() -> int:
	return Vitals.of(_player).current(&"mp")
