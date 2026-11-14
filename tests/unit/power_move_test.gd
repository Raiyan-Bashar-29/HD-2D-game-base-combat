extends TestCase
## A power's own move in the field (C9.9b): a quick-slot press of a power that has a `move`
## plays that move on the fighter's clock, so the power has a wind-up, a hitbox and i-frames;
## a refused press starts nothing; and a power without a move still lands at once.
##
## OWNS: assertions about `ActionFighter.press_slot` and `Power.move`.
## MUST NOT: name a game's kits, powers or characters, or wait for frames.

const DT: float = 0.05
const POOL: StringName = &"zeal"
const COST: int = 10

var _player: PlayerController
var _fighter: ActionFighter
var _move: ActionMove


func run() -> void:
	plan(8)
	Flags.clear_all()
	_move = _lunge()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout())
	for child: Node in _player.get_children():
		if child is ActionFighter:
			_fighter = child as ActionFighter
	_plays()
	_refused()
	_player.free()
	Flags.clear_all()


func _plays() -> void:
	var vitals: Vitals = Vitals.of(_player)
	var before: int = vitals.current(POOL)
	equal("pressing the slot of a power with a move works", _fighter.press_slot(0), true)
	equal("the fighter plays the power's move, and the cost is paid",
		[_fighter.timeline.move == _move, vitals.current(POOL)], [true, before - COST])
	equal("in its wind-up the fighter can still be hit", _fighter.timeline.invulnerable(), false)
	_pass(0.15)
	equal("inside the move's i-frames the fighter is untouchable", _fighter.timeline.invulnerable(), true)
	_pass(0.3)
	equal("and after them it can be hit again", _fighter.timeline.invulnerable(), false)
	_pass(1.0)
	equal("the move ends by itself", _fighter.timeline.busy(), false)


func _refused() -> void:
	equal("a power without a move lands at once and starts no move",
		[_fighter.press_slot(1), _fighter.timeline.busy()], [true, false])
	Vitals.of(_player).change(POOL, -1000)
	equal("a press that is refused starts nothing",
		[_fighter.press_slot(0), _fighter.timeline.busy()], [false, false])


func _pass(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_fighter.drive(DT, false, false)
		left -= DT


func _lunge() -> ActionMove:
	var move := ActionMove.new()
	move.startup = 0.1
	move.active = 0.2
	move.recovery = 0.2
	move.iframes_from = 0.1
	move.iframes_to = 0.3
	move.power = 5.0
	return move


func _power(short: String, cost: int, move: ActionMove) -> Power:
	var skill := Skill.new()
	skill.id = StringName("skill/fixture_pmove_" + short)
	skill.name_key = "fixture.skill"
	skill.target = FactionTable.Target.SELF
	skill.cost_pool = POOL if cost > 0 else &""
	skill.cost = cost
	var power := Power.new()
	power.power_id = StringName("power/fixture_pmove_" + short)
	power.name_key = "fixture." + short
	power.skill = skill
	power.move = move
	return power


func _loadout() -> ActionLoadout:
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_pmove"
	kit.name_key = "fixture.kit"
	kit.powers = [_power("lunge", COST, _move), _power("plain", 0, null)]
	kit.stat_bonuses = [StatModifier.of(&"max_zeal", StatModifier.Op.ADD, 20.0, kit.kit_id)]
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_pmove_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	def.power_kit = kit
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made
