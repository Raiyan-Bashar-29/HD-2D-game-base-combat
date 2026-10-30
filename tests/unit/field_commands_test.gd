extends TestCase
## Field commands (C4.3): a skill aims at the locked foe, else the nearest in reach, "all" at
## every foe in reach and a self skill at the user; each reason a command is refused (no ATB, a
## status, short mp, no item, nobody to aim at) is the one the player reads; a use spends the
## bar and the cost, lands the skill and takes the item; a refused use changes nothing; and the
## loadout and skill report their field problems.
##
## OWNS: assertions about `FieldCommands`, `ActionLoadout.commands` and `Skill.atb_cost`.
## MUST NOT: name a game's skills or items, or wait for frames.

var _player: PlayerController
var _hero: Combatant
var _near: Node3D
var _far: Node3D
var _actors: Array[Node] = []


func run() -> void:
	plan(15)
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, _loadout())
	_hero = Combatant.of(_player)
	_near = _foe(&"fixture_near", Vector3(0, 0, -2))
	_far = _foe(&"fixture_far", Vector3(0, 0, -5))
	_foe(&"fixture_distant", Vector3(0, 0, -30))
	_aiming()
	_refusing()
	_using()
	_problems()
	_player.free()
	for actor: Node in _actors:
		actor.free()
	Flags.clear_all()


func _aiming() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0), BattleCommand.Kind.SKILL)
	_lock().target = _hurtbox(_far)
	equal("a skill lands on the locked foe", _ids(FieldCommands.targets(_hero, bolt)), [&"fixture_far"])
	_lock().target = null
	equal("with nothing locked, on the nearest", _ids(FieldCommands.targets(_hero, bolt)), [&"fixture_near"])
	var storm := _command(_skill(Skill.Scope.ALL, FactionTable.Target.ENEMY, 4.0), BattleCommand.Kind.SKILL)
	equal("an all-foes skill lands on every foe in reach, nearest first",
		_ids(FieldCommands.targets(_hero, storm)), [&"fixture_near", &"fixture_far"])
	var mend := _command(_skill(Skill.Scope.ONE, FactionTable.Target.SELF, -4.0), BattleCommand.Kind.SKILL)
	equal("a self skill lands on the user", _ids(FieldCommands.targets(_hero, mend)), [&"fixture_hero"])


func _refusing() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0), BattleCommand.Kind.SKILL)
	equal("with an empty gauge, the reason is ATB", FieldCommands.refusal(_hero, bolt), FieldCommands.Reason.ATB)
	AtbMeter.of(_player).gauge.gain(200.0)
	equal("with a bar to spend, it can be used", FieldCommands.refusal(_hero, bolt), FieldCommands.Reason.NONE)
	bolt.skill.cost = 99
	equal("too little mp is the cost reason", FieldCommands.refusal(_hero, bolt), FieldCommands.Reason.COST)
	bolt.skill.cost = 2
	var silence := StatusEffect.new()
	silence.id = &"status/fixture_hush"
	silence.unit = StatusEffect.Unit.SECONDS
	silence.duration = 10.0
	silence.blocks = [StatusEffect.Block.NO_SKILLS]
	StatusSet.of(_player).apply(silence)
	equal("a status that forbids skills is the blocked reason", FieldCommands.refusal(_hero, bolt), FieldCommands.Reason.BLOCKED)
	StatusSet.of(_player).cure(silence.id)
	var tonic := _command(_skill(Skill.Scope.ONE, FactionTable.Target.SELF, -4.0), BattleCommand.Kind.ITEM)
	equal("an item the bag does not hold is the none-left reason", FieldCommands.refusal(_hero, tonic), FieldCommands.Reason.ITEM)
	_player.global_position = Vector3(0, 0, 40)
	equal("with every foe out of reach, nobody to aim at", FieldCommands.refusal(_hero, bolt), FieldCommands.Reason.TARGET)
	_player.global_position = Vector3.ZERO


func _using() -> void:
	var bolt := _command(_skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 4.0), BattleCommand.Kind.SKILL)
	bolt.skill.cost = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gauge: AtbGauge = AtbMeter.of(_player).gauge
	gauge.value = 100.0
	var used: bool = FieldCommands.use(_hero, bolt, rng)
	# The bar is spent, then the spell landing earns its own hit reward, as any landed hit does.
	equal("a use spends the bar and the mp, and lands on the foe",
		[used, gauge.value, Vitals.of(_player).current(&"mp"), Vitals.of(_near).current(&"hp") < 50],
		[true, gauge.rules.on_hit_dealt, 8, true])
	var before: int = Vitals.of(_near).current(&"hp")
	equal("with the bar spent, a second use is refused and changes nothing",
		[FieldCommands.use(_hero, bolt, rng), Vitals.of(_near).current(&"hp"), Vitals.of(_player).current(&"mp")],
		[false, before, 8])
	var tonic := _command(_skill(Skill.Scope.ONE, FactionTable.Target.SELF, -4.0), BattleCommand.Kind.ITEM)
	var bag: Inventory = Inventory.of(_player)
	bag.add(FixtureContent.STACK_ITEM, 1)
	gauge.value = 100.0
	equal("an item use takes the item and spends the bar",
		[FieldCommands.use(_hero, tonic, rng), bag.count_of(FixtureContent.STACK_ITEM), gauge.value], [true, 0, 0.0])


func _problems() -> void:
	var loadout := _loadout()
	var before: int = loadout.problems("fixture").size()
	var swing := BattleCommand.new()
	swing.kind = BattleCommand.Kind.ATTACK
	loadout.commands = [swing]
	equal("a field ATTACK command is one more problem", loadout.problems("fixture").size() - before, 1)
	var skill := _skill(Skill.Scope.ONE, FactionTable.Target.ENEMY, 1.0)
	skill.atb_cost = -1
	equal("a negative ATB cost is a problem", skill.problems().size(), 1)


func _loadout() -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0, &"attack": 5.0}
	var made := ActionLoadout.new()
	made.fighter = def
	made.moves = MoveSet.new()
	made.moves.attack_chain = [ActionMove.new()]
	made.atb = AtbRules.new()
	return made


func _skill(scope: Skill.Scope, target: FactionTable.Target, power: float) -> Skill:
	var made := Skill.new()
	made.id = &"skill/fixture_field"
	made.name_key = "fixture.field_skill"
	made.scope = scope
	made.target = target
	made.power = power
	made.cost_pool = &"mp"
	made.sure_hit = true
	return made


func _command(skill: Skill, kind: BattleCommand.Kind) -> BattleCommand:
	var made := BattleCommand.new()
	made.kind = kind
	made.skill = skill
	if kind == BattleCommand.Kind.ITEM:
		made.item_id = FixtureContent.STACK_ITEM
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


func _lock() -> LockOn:
	for child: Node in _player.get_children():
		if child is LockOn:
			return child as LockOn
	return null


func _hurtbox(actor: Node3D) -> Hurtbox:
	for child: Node in actor.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _ids(fighters: Array[Combatant]) -> Array[StringName]:
	var out: Array[StringName] = []
	for fighter: Combatant in fighters:
		out.append(fighter.combatant_id)
	return out
