extends TestCase
## The counter stance (C6.6d, M13): a status with the COUNTER reaction answers a hit. With a
## `counter_move`, the field holder swings that move on its own clock and does not flinch, and a
## battle counter strikes with the move's numbers. A timed-block barrier whose status counters is
## a parry: the perfect press stops the hit, and the counter answers it.
##
## OWNS: assertions about `StatusEffect.counter_move`, `SkillUse.counter_stance` and `answer`,
## the counter in `Hurtbox.take`, and `ActionFighter` turning to face whoever it counters.
## MUST NOT: name a game's fighters, moves or kits, or wait for frames.

const NOON: float = 12.0

var _actors: Array[Node] = []
var _countered: int = 0
var _pushes: int = 0
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 7
	Events.countered.connect(_on_countered)
	Events.knockback_requested.connect(_on_push)
	_shapes()
	_battle_numbers()
	_battle_parry()
	_in_the_field()
	_the_player_parries()
	Events.countered.disconnect(_on_countered)
	Events.knockback_requested.disconnect(_on_push)
	for actor: Node in _actors:
		if is_instance_valid(actor):
			actor.free()
	_actors.clear()
	Flags.clear_all()


func _shapes() -> void:
	var stray := _stance(&"status/fixture_cs_stray", _flurry(3))
	stray.reactions = []
	equal("a counter_move with no COUNTER reaction is a problem", stray.problems().size(), 1)
	equal("a counter stance with a move is clean",
		_stance(&"status/fixture_cs_ok", _flurry(3)).problems().size(), 0)
	var broken := _flurry(3)
	broken.startup = -1.0
	equal("a broken counter move is the status's problem",
		_stance(&"status/fixture_cs_bad", broken).problems().size(), 1)


func _battle_numbers() -> void:
	var striker: Node3D = _actor(&"fixture_cs_striker", &"side_b", {&"max_hp": 200.0})
	var plain: Node3D = _actor(&"fixture_cs_plain", &"side_a", {&"max_hp": 50.0, &"attack": 3.0})
	var flurry: Node3D = _actor(&"fixture_cs_flurry", &"side_a", {&"max_hp": 50.0, &"attack": 3.0})
	StatusSet.of(plain).apply(_stance(&"status/fixture_cs_plain", null))
	StatusSet.of(flurry).apply(_stance(&"status/fixture_cs_flurry", _flurry(3)))
	var landed := DamageResult.new()
	_countered = 0
	SkillUse.counter(Combatant.of(striker), Combatant.of(plain), landed, _rng)
	var after_plain: int = 200 - _hp(striker)
	Vitals.of(striker).set_to(&"hp", 200)
	SkillUse.counter(Combatant.of(striker), Combatant.of(flurry), landed, _rng)
	equal("a three-hit counter move hurts more than a plain counter, and each is announced",
		[200 - _hp(striker) > after_plain, after_plain > 0, _countered], [true, true, 2])
	var jabber: Node3D = _actor(&"fixture_cs_jabber", &"side_a", {&"max_hp": 50.0})
	var with_skill := _flurry(1)
	with_skill.skill = Skill.new()
	with_skill.skill.id = &"skill/fixture_cs_jab"
	with_skill.skill.name_key = "fixture.skill"
	with_skill.skill.power = 9.0
	with_skill.skill.sure_hit = true
	StatusSet.of(jabber).apply(_stance(&"status/fixture_cs_skill", with_skill))
	Vitals.of(striker).set_to(&"hp", 200)
	SkillUse.counter(Combatant.of(striker), Combatant.of(jabber), landed, _rng)
	equal("a counter move wrapping a skill lands that skill on the attacker", _hp(striker) < 200, true)


# A battle: the guard raises a timed-block barrier whose status counters, and the foe's attack
# before the guard's next turn is parried and answered.
func _battle_parry() -> void:
	var holder := Node.new()
	attach(holder)
	_actors.append(holder)
	var guard := _def(&"fixture_cs_guard", &"side_a", 9.0)
	guard.power_kit = _parry_kit("bt")
	var foe := _def(&"fixture_cs_foe", &"side_b", 1.0)
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_cs"
	encounter.enemies = [foe]
	var battle: Battle = BattleSetup.build(encounter, [guard], holder, RandomNumberGenerator.new())
	var me: Combatant = battle.party[0]
	var them: Combatant = battle.enemies[0]
	battle.next_turn()
	battle.act(BattleCommand.for_power(guard.power_kit.powers[0]), [])
	battle.next_turn()
	var attack := BattleCommand.new()
	attack.kind = BattleCommand.Kind.ATTACK
	_countered = 0
	battle.act(attack, [me])
	equal("in a battle the parried attack takes nothing, and the foe is struck back",
		[Vitals.of(me.get_parent()).current(&"hp"), Vitals.of(them.get_parent()).current(&"hp") < 99,
			_countered],
		[99, true, 1])
	BattleSetup.release(battle)


func _in_the_field() -> void:
	var striker: Node3D = _actor(&"fixture_cs_hitter", &"side_b", {&"max_hp": 200.0, &"attack": 2.0})
	var holder: Node3D = _actor(&"fixture_cs_holder", &"side_a", {&"max_hp": 99.0, &"attack": 2.0})
	var clock := MoveTimeline.new()
	_hurtbox(holder).timeline = clock
	var riposte := _flurry(2)
	StatusSet.of(holder).apply(_stance(&"status/fixture_cs_field", riposte))
	_countered = 0
	_pushes = 0
	_hurtbox(holder).take(Combatant.of(striker), _swing(2.0), _rng, Vector3.ZERO)
	equal("a field hit lands, then the holder swings its counter move without flinching",
		[_hp(holder) < 99, clock.move == riposte, clock.busy(), _countered, _pushes],
		[true, true, true, 1, 0])
	var swing: int = clock.swing
	clock.step(0.05)
	_hurtbox(holder).take(Combatant.of(striker), _swing(2.0), _rng, Vector3.ZERO)
	equal("a second hit mid-counter does not begin the counter again", [clock.swing, _countered], [swing, 1])
	var bare: Node3D = _actor(&"fixture_cs_bare", &"side_a", {&"max_hp": 99.0, &"attack": 2.0})
	StatusSet.of(bare).apply(_stance(&"status/fixture_cs_bare", null))
	_hurtbox(bare).take(Combatant.of(striker), _swing(2.0), _rng, Vector3.ZERO)
	equal("a stance with no move strikes back at once", [_hp(striker) < 200, _countered], [true, 2])
	var dazed: Node3D = _actor(&"fixture_cs_dazed", &"side_a", {&"max_hp": 99.0})
	StatusSet.of(dazed).apply(_stance(&"status/fixture_cs_dazed", null))
	var stun := StatusEffect.new()
	stun.id = &"status/fixture_cs_stun"
	stun.unit = StatusEffect.Unit.SECONDS
	stun.blocks = [StatusEffect.Block.SKIP_TURN]
	StatusSet.of(dazed).apply(stun)
	_hurtbox(dazed).take(Combatant.of(striker), _swing(2.0), _rng, Vector3.ZERO)
	equal("a stunned holder does not counter, and is pushed", [_countered, _pushes], [2, 1])
	var roller: Node3D = _actor(&"fixture_cs_roller", &"side_a", {&"max_hp": 99.0})
	StatusSet.of(roller).apply(_stance(&"status/fixture_cs_roll", _flurry(2)))
	var roll := ActionMove.new()
	roll.active = 0.5
	roll.iframes_to = 0.5
	var rolling := MoveTimeline.new()
	rolling.start(roll)
	_hurtbox(roller).timeline = rolling
	_hurtbox(roller).take(Combatant.of(striker), _swing(2.0), _rng, Vector3.ZERO)
	equal("a hit dodged in i-frames is not countered", [_countered, rolling.move == roll], [2, true])


# The player raises a timed-block counter barrier: a hit at once is parried and answered, facing
# the attacker; a hit after the timing is a late block, and still answered.
func _the_player_parries() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_actors.append(player)
	player.position = Vector3.ZERO
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_cs_hero"
	def.faction = &"side_a"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 20.0}
	def.power_kit = _parry_kit("pl")
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	var fighter: ActionFighter = ActionHost.equip(player, loadout)
	var me: Combatant = Combatant.of(player)
	var striker: Node3D = _actor(&"fixture_cs_rival", &"side_b", {&"max_hp": 200.0, &"attack": 3.0})
	striker.position = Vector3(4.0, 0.0, 0.0)
	PowerUse.use(me, def.power_kit.powers[0], [], _rng, NOON)
	_countered = 0
	_hurtbox(player).take(Combatant.of(striker), _swing(1.0), _rng, striker.position)
	equal("a hit just after the press is parried: nothing lands, and the counter swings",
		[Vitals.of(player).current(&"hp"), fighter.timeline.move != null, _countered], [40, true, 1])
	equal("and the hero turns to face whoever it countered",
		fighter.facing.is_equal_approx(Vector3.RIGHT), true)
	fighter.timeline.cancel()
	PowerSet.of(player).tick_seconds(0.5)
	_hurtbox(player).take(Combatant.of(striker), _swing(1.0), _rng, striker.position)
	equal("a later hit is a late block: some lands, and it is still countered",
		[Vitals.of(player).current(&"hp") < 40, _countered], [true, 2])


## A fighter with a hurtbox, in the tree.
func _actor(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Node3D:
	var actor := Node3D.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.real_time = true
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _hurtbox(actor: Node) -> Hurtbox:
	for child: Node in actor.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(actor: Node) -> int:
	return Vitals.of(actor).current(&"hp")


func _stance(id: StringName, move: ActionMove) -> StatusEffect:
	var status := StatusEffect.new()
	status.id = id
	status.name_key = "fixture.status"
	status.unit = StatusEffect.Unit.SECONDS
	status.duration = 0.0
	status.reactions = [StatusEffect.Reaction.COUNTER]
	status.counter_move = move
	return status


## A counter flurry of `hits` hits.
func _flurry(hits: int) -> ActionMove:
	var made := ActionMove.new()
	made.startup = 0.1
	made.active = 0.3
	made.recovery = 0.3
	made.power = 2.0
	made.hits = hits
	return made


func _swing(knockback: float) -> ActionMove:
	var made := ActionMove.new()
	made.active = 0.2
	made.recovery = 0.2
	made.power = 3.0
	made.knockback = knockback
	return made


## A kit holding one power: a timed-block barrier whose status counters with a flurry.
func _parry_kit(tag: String) -> PowerKit:
	var guard := BarrierMechanism.new()
	guard.mode = BarrierMechanism.Mode.TIMED_BLOCK
	guard.status = _stance(StringName("status/fixture_cs_parry_" + tag), _flurry(2))
	guard.timing = TimedWindow.new()
	guard.timing.opens = 0.0
	guard.timing.closes = 0.2
	guard.factor = 0.5
	var power := Power.new()
	power.power_id = StringName("power/fixture_cs_parry_" + tag)
	power.name_key = "fixture.power"
	power.mechanism = guard
	var kit := PowerKit.new()
	kit.kit_id = StringName("kit/fixture_cs_" + tag)
	kit.name_key = "fixture.kit"
	kit.powers = [power]
	return kit


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name"
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 4.0, &"defence": 1.0}
	return def


func _on_countered(_who: StringName, _against: StringName) -> void:
	_countered += 1


func _on_push(_who: StringName, _push: Vector3) -> void:
	_pushes += 1
