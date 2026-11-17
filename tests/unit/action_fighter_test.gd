extends TestCase
## The player fights (C3.4): `ActionHost.equip` fits a body with every fighting part, once; the
## fighter swings, holds the body while busy and lets go after; it ignores the buttons while
## something else holds the body; a dodge rolls the way the body was moving, untouchable, and
## never starts out of a wind-up; a knockback interrupts, pushes and stuns; statuses tick in
## seconds and a seconds sleep stuns; a fallen fighter does nothing.
##
## OWNS: assertions about `ActionFighter`, `ActionHost.equip` and `ActionLoadout`.
## MUST NOT: name a game's fighters or moves, or wait for frames: `drive` is called by hand.

const DT: float = 0.02

var _player: PlayerController
var _fighter: ActionFighter


func run() -> void:
	plan(27)
	SaveFixture.activate()
	Flags.clear_all()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_equipping()
	_swinging()
	_dodging()
	_holding()
	_throw_held()
	_knockback_and_stun()
	_falling()
	_player.free()
	Flags.clear_all()


func _move(startup: float, active: float, recovery: float) -> ActionMove:
	var made := ActionMove.new()
	made.startup = startup
	made.active = active
	made.recovery = recovery
	return made


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"attack": 3.0}
	var swing := _move(0.1, 0.1, 0.2)
	swing.power = 2.0
	var roll := _move(0.0, 0.2, 0.1)
	roll.iframes_to = 0.2
	roll.travel_speed = 5.0
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [swing, swing]
	made.moves.dodge = roll
	return made


func _hitbox() -> Hitbox:
	for child: Node in _player.get_children():
		if child is Hitbox:
			return child as Hitbox
	return null


func _hurtbox() -> Hurtbox:
	for child: Node in _player.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _run(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_fighter.drive(DT, false, false)
		left -= DT


func _holds() -> bool:
	return _player.input_holders().has(ActionFighter.LOCK)


func _equipping() -> void:
	equal("an empty loadout has no fighter and no moves", ActionLoadout.new().problems("fixture").size(), 2)
	# The setting is the game's, so the test sets it and puts it back afterwards.
	var kept: Variant = ProjectSettings.get_setting(ActionHost.LOADOUT_SETTING, "")
	ProjectSettings.set_setting(ActionHost.LOADOUT_SETTING, "")
	equal("with no loadout configured, nobody is fitted", ActionHost.configured(), null)
	ProjectSettings.set_setting(ActionHost.LOADOUT_SETTING, "res://fixture/no_such_loadout.tres")
	equal("a loadout file that is gone means no field combat, quietly", ActionHost.configured(), null)
	ProjectSettings.set_setting(ActionHost.LOADOUT_SETTING, kept)
	_fighter = ActionHost.equip(_player, _loadout())
	var combatant: Combatant = Combatant.of(_player)
	equal("equip fits a fighter with the definition's id and hp",
		[_fighter != null, combatant.combatant_id, Vitals.of(_player).current(&"hp")], [true, &"fixture_hero", 40])
	equal("its hurtbox and hitbox share the fighter's clock",
		[_hurtbox().timeline == _fighter.timeline, _hitbox().timeline == _fighter.timeline], [true, true])
	equal("equipping twice adds nothing", ActionHost.equip(_player, _loadout()), null)


func _swinging() -> void:
	_player.velocity = Vector3(3.0, 0.0, 0.0)
	_fighter.drive(DT, false, false)
	equal("walking sets the way the fighter faces", _fighter.facing, Vector3.RIGHT)
	_fighter.drive(DT, true, false)
	equal("attack starts the chain and holds the body", [_fighter.timeline.chain_index, _holds()], [0, true])
	equal("and the fighter stands firm while it swings", _player.velocity.x, 0.0)
	equal("the hitbox is fitted and turned to face", [_hitbox().extent().size,
		is_equal_approx(_hitbox().rotation.y, -PI / 2.0)], [Vector3.ONE, true])
	_fighter.drive(DT, false, true)
	equal("no dodging out of a wind-up", _fighter.timeline.move == _fighter.moves.dodge, false)
	_run(1.0)
	equal("when the swing is over the body is let go", [_fighter.timeline.busy(), _holds()], [false, false])
	_player.lock_input(&"fixture_busy")
	_fighter.drive(DT, true, false)
	equal("while something else holds the body, attack does nothing", _fighter.timeline.busy(), false)
	_player.release_input(&"fixture_busy")


func _dodging() -> void:
	_player.velocity = Vector3(0.0, 0.0, 2.0)
	_fighter.drive(DT, false, true)
	equal("dodge plays the dodge", _fighter.timeline.move == _fighter.moves.dodge, true)
	_fighter.drive(DT, false, false)
	equal("rolling the way the body was moving, at its travel speed", _player.velocity, Vector3(0.0, 0.0, 5.0))
	equal("untouchable while it rolls", _fighter.timeline.invulnerable(), true)
	_run(0.25)
	equal("in recovery it stands firm instead of sliding on", _player.velocity.z, 0.0)
	_run(0.5)


# Hold to attack (C5.4c): a held button starts the chain and keeps it going, never timed.
func _holding() -> void:
	var swing: ActionMove = _fighter.moves.attack_chain[0]
	swing.prompt = TimedWindow.new()
	swing.prompt.opens = 0.0
	swing.prompt.closes = 1.0
	_fighter.drive(DT, false, false, true)
	var first: int = _fighter.timeline.chain_index
	var chained: bool = false
	for i: int in 40:
		_fighter.drive(DT, false, false, true)
		chained = chained or _fighter.timeline.chain_index == 1
	equal("a held attack starts the chain and keeps it going", [first, chained], [0, true])
	equal("a held press is never a timed press", _fighter.timeline.pressed(), false)
	swing.prompt = null
	_run(1.0)


## C8.27a: with hold-to-attack on, the press that throws a carried thing does not swing too, nor
## does the hold after it; a fresh hold swings again.
func _throw_held() -> void:
	var made := build("res://scenes/objects/arena_thing.tscn") as ArenaThing
	made.carryable = true
	made.label_key = "ui.cancel"
	made.position = Vector3(300, 0, 0)
	attach(made)
	var lifted: bool = Carried.lift(_player, made)
	_fighter.drive(DT, true, false, true)
	var thrown: bool = Carried.of(_player) == null
	var swung: bool = _fighter.timeline.busy()
	for i: int in 3:
		_fighter.drive(DT, false, false, true)
		swung = swung or _fighter.timeline.busy()
	_fighter.drive(DT, false, false, false)
	_fighter.drive(DT, false, false, true)
	equal("a held throw press throws without swinging, the hold after it stays still, a new hold swings",
		[lifted, thrown, swung, _fighter.timeline.busy()], [true, true, false, true])
	_run(1.0)


func _knockback_and_stun() -> void:
	_fighter.drive(DT, true, false)
	Events.knockback_requested.emit(&"fixture_hero", Vector3(1.0, 0.0, 0.0))
	equal("a knockback interrupts the swing and stuns", [_fighter.timeline.busy(), _fighter.stunned()], [false, true])
	_fighter.drive(DT, true, false)
	equal("the push moves it over the stun, and attack does nothing",
		[is_equal_approx(_player.velocity.x, 1.0 / _fighter.stun_time), _fighter.timeline.busy()], [true, false])
	_run(0.5)
	equal("then the stun is over", _fighter.stunned(), false)
	var nap := StatusEffect.new()
	nap.id = &"status/fixture_nap"
	nap.unit = StatusEffect.Unit.SECONDS
	nap.duration = 0.5
	nap.blocks = [StatusEffect.Block.SKIP_TURN]
	StatusSet.of(_player).apply(nap)
	equal("a sleep counted in seconds stuns", _fighter.stunned(), true)
	_run(0.6)
	equal("and wears off as the seconds tick", [StatusSet.of(_player).stacks(nap.id), _fighter.stunned()], [0, false])
	var turns := nap.duplicate() as StatusEffect
	turns.unit = StatusEffect.Unit.TURNS
	StatusSet.of(_player).apply(turns)
	equal("one counted in turns does not, or nothing would ever end it", _fighter.stunned(), false)
	StatusSet.of(_player).cure(turns.id)


func _falling() -> void:
	Vitals.of(_player).change(&"hp", -100)
	_fighter.drive(DT, true, false)
	equal("a fallen fighter does nothing", _fighter.timeline.busy(), false)
