extends TestCase
## Allies that think in real time (C4.8): `BattleAi.decide` reads a brain against a
## `BrainContext`, and a party follower in the field uses its member's `BattleBrain` through a
## `FieldBrainContext`: it spends ATB on what it can pay for, heals the most hurt ally by
## LOWEST_HP, casts an all-foes skill at every foe in reach, thinks only near a foe, only every
## `think_every` seconds of fight time, and never while silenced, fallen or stopped.
##
## OWNS: assertions about `BrainContext`, `FieldBrainContext`, `PartyFollower.think` and
## `FieldCommands.candidates` and `use`'s aim. The turn-based side is `battle_ai_test`.
## MUST NOT: name a game's fighters or skills, or wait for frames.

const DT: float = 0.1

var _player: PlayerController
var _mate: ActionLoadout
var _follower: PartyFollower
var _me: Combatant
var _near: Node3D
var _other: Node3D
var _far: Node3D
var _actors: Array[Node] = []


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	var lead := _loadout(&"fixture_lead")
	_mate = _loadout(&"fixture_mate")
	_mate.atb = AtbRules.new()
	lead.companions = [_mate]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	_player.global_position = Vector3.ZERO
	ActionHost.equip(_player, lead)
	_follower = FieldParty.spawn(_player, lead)[0]
	_follower.rng.seed = 7
	_me = Combatant.of(_follower)
	_near = _foe(&"fixture_near", Vector3(0, 0, -3))
	_other = _foe(&"fixture_other", Vector3(2, 0, -3))
	_far = _foe(&"fixture_far", Vector3(0, 0, -30))
	_contexts()
	_spending()
	_choosing()
	_timing()
	for follower: PartyFollower in FieldParty.followers(_player):
		follower.free()
	_player.free()
	for actor: Node in _actors:
		actor.free()
	CombatClock.reset()
	Flags.clear_all()


func _contexts() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0))
	_brain([_entry(bolt, BrainEntry.TargetRule.FIRST)])
	equal("a bare context allows nothing, so a brain read against it does nothing",
		BattleAi.decide(BrainContext.new(_me), _mate.fighter.brain), false)
	var guard := BattleCommand.new()
	guard.kind = BattleCommand.Kind.DEFEND
	var context := FieldBrainContext.new(_me)
	equal("the field has no defending, and nothing to fall back on",
		[context.allows(guard), context.fallback()], [false, false])
	equal("the field's candidates are every foe in reach, nearest first",
		_ids(context.targets_for(bolt)), [&"fixture_near", &"fixture_other"])


func _spending() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0))
	_brain([_entry(bolt, BrainEntry.TargetRule.FIRST)])
	equal("with an empty gauge, a follower does nothing", [_follower.think(), _hp(_near)], [false, 50])
	var gauge: AtbGauge = AtbMeter.of(_follower).gauge
	gauge.gain(200.0)
	equal("with a bar, it casts at the nearest foe and spends the bar and the mp",
		[_follower.think(), _hp(_near) < 50, gauge.full_segments(), Vitals.of(_follower).current(&"mp")],
		[true, true, 1, 8])
	equal("an aim the command cannot reach is refused, changing nothing",
		[FieldCommands.use(_me, bolt, _follower.rng, [Combatant.of(_far)]), gauge.full_segments()], [false, 1])
	var hush := StatusEffect.new()
	hush.id = &"status/fixture_hush"
	hush.unit = StatusEffect.Unit.SECONDS
	hush.duration = 30.0
	hush.blocks = [StatusEffect.Block.NO_SKILLS]
	StatusSet.of(_follower).apply(hush)
	equal("a silenced follower casts nothing", _follower.think(), false)
	StatusSet.of(_follower).cure(&"status/fixture_hush")


func _choosing() -> void:
	var gauge: AtbGauge = AtbMeter.of(_follower).gauge
	var mend := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ALLY, -10.0))
	_brain([_entry(mend, BrainEntry.TargetRule.LOWEST_HP)])
	Vitals.of(_player).change(&"hp", -20)
	gauge.gain(200.0)
	equal("LOWEST_HP heals the most hurt ally, the player, not itself",
		[_follower.think(), Vitals.of(_player).current(&"hp") > 20], [true, true])
	var storm := _command(_skill(Skill.Scope.ALL, FactionTable.Target.ENEMY, 4.0))
	_brain([_entry(storm, BrainEntry.TargetRule.FIRST)])
	var before: Array[int] = [_hp(_near), _hp(_other), _hp(_far)]
	gauge.gain(200.0)
	_follower.think()
	equal("an all-foes skill lands on every foe in reach and no further",
		[_hp(_near) < before[0], _hp(_other) < before[1], _hp(_far) == before[2]], [true, true, true])
	_far.global_position = Vector3(0, 0, -40)
	_near.global_position = Vector3(0, 0, -20)
	_other.global_position = Vector3(2, 0, -20)
	gauge.gain(200.0)
	equal("with no foe in reach, it does not think, and keeps its bars",
		[FieldBrainContext.new(_me).fighting(), _follower.think(), gauge.full_segments()], [false, false, 2])
	_near.global_position = Vector3(0, 0, -3)
	_other.global_position = Vector3(2, 0, -3)


func _timing() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0))
	_brain([_entry(bolt, BrainEntry.TargetRule.FIRST)])
	var gauge: AtbGauge = AtbMeter.of(_follower).gauge
	gauge.gain(200.0)
	var hp: int = _hp(_near)
	CombatClock.set_scale(0.0)
	_frames(30)
	equal("with the fight stopped, it never gets round to thinking", _hp(_near), hp)
	CombatClock.reset()
	_frames(5)
	equal("half a second in, it has not chosen yet", _hp(_near), hp)
	_frames(6)
	equal("after `think_every`, it casts on its own as it follows", _hp(_near) < hp, true)
	Vitals.of(_follower).change(&"hp", -999)
	gauge.gain(200.0)
	hp = _hp(_near)
	_frames(20)
	equal("a fallen follower thinks no more", _hp(_near), hp)


func _frames(count: int) -> void:
	for i: int in count:
		_follower.follow(DT)


func _brain(entries: Array[BrainEntry]) -> void:
	var brain := BattleBrain.new()
	brain.entries = entries
	_mate.fighter.brain = brain


func _entry(command: BattleCommand, rule: BrainEntry.TargetRule) -> BrainEntry:
	var made := BrainEntry.new()
	made.command = command
	made.target_rule = rule
	return made


func _loadout(id: StringName) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0, &"attack": 5.0}
	def.level_curve = LevelCurve.new()
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	return made


func _skill(scope: Skill.Scope, target: FactionTable.Target, power: float) -> Skill:
	var made := Skill.new()
	made.id = &"skill/fixture_ally"
	made.name_key = "fixture.ally_skill"
	made.scope = scope
	made.target = target
	made.power = power
	made.cost = 2
	made.cost_pool = &"mp"
	made.sure_hit = true
	return made


func _command(skill: Skill) -> BattleCommand:
	var made := BattleCommand.new()
	made.kind = BattleCommand.Kind.SKILL
	made.skill = skill
	return made


func _foe(id: StringName, at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = &"enemy"
	combatant.base_stats = {&"max_hp": 50.0, &"defence": 1.0}
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return actor


func _hp(actor: Node3D) -> int:
	return Vitals.of(actor).current(&"hp")


func _ids(fighters: Array[Combatant]) -> Array[StringName]:
	var out: Array[StringName] = []
	for fighter: Combatant in fighters:
		out.append(fighter.combatant_id)
	return out
