extends TestCase
## Followers share the lead's aim, and a taunt binds the player's aim (C10.8): with the player
## locked on the far foe, a follower's pick and its brain's first target are that foe; a taunt
## still outranks it and takes the player's own one-target skill too; a follower is not
## "fighting" while every foe in reach idles, and is once one chases.
##
## OWNS: assertions about `FieldCommands.aim_of`, `Aggro.pick`'s favoured foe, the taunt in
## `FieldCommands.targets`, and `FieldBrainContext`'s aim and `fighting`.
## MUST NOT: name a game's fighters, or wait for frames.

var _player: PlayerController
var _foes: Array[ActionEnemy] = []


func run() -> void:
	plan(5)
	SaveFixture.activate()
	Flags.clear_all()
	var lead: ActionLoadout = _loadout(&"fixture_aim_lead")
	lead.companions = [_loadout(&"fixture_aim_mate")]
	_player = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_player)
	ActionHost.equip(_player, lead)
	var follower: PartyFollower = FieldParty.spawn(_player, lead)[0]
	follower.global_position = Vector3(1.0, 0.0, 0.0)
	var near: ActionEnemy = _foe(&"fixture_aim_near", Vector3(0.0, 0.0, -3.0))
	var far: ActionEnemy = _foe(&"fixture_aim_far", Vector3(0.0, 0.0, -6.0))
	_checks(follower, near, far)
	for foe: ActionEnemy in _foes:
		foe.free()
	follower.free()
	_player.free()
	Flags.clear_all()


func _checks(follower: PartyFollower, near: ActionEnemy, far: ActionEnemy) -> void:
	var mate: Combatant = Combatant.of(follower)
	var ctx := FieldBrainContext.new()
	ctx.actor = mate
	ctx.rng = RandomNumberGenerator.new()
	var bolt: BattleCommand = _bolt()
	near.decider.state = ActionDecider.State.IDLE
	far.decider.state = ActionDecider.State.WANDER
	var idle: bool = ctx.fighting()
	far.decider.state = ActionDecider.State.CHASE
	equal("a follower is not fighting while every foe in reach idles, and is once one chases",
		[idle, ctx.fighting()], [false, true])
	_lock_of(_player).target = _hurtbox(far)
	equal("with the player locked on the far foe, a follower aims there too",
		[FieldCommands.aim_of(mate) == Combatant.of(far), Aggro.pick(follower, INF, FieldCommands.aim_of(mate)) == _hurtbox(far),
			Aggro.pick(follower) == _hurtbox(near)], [true, true, true])
	equal("and its brain's first target is that foe", ctx.targets_for(bolt)[0] == Combatant.of(far), true)
	var taunt := StatusEffect.new()
	taunt.id = &"status/fixture_aim_taunt"
	taunt.tags = [Aggro.TAG]
	StatusSet.of(near).apply(taunt)
	equal("a taunt still outranks the lead's aim, in the pick and the brain",
		[Aggro.pick(follower, INF, FieldCommands.aim_of(mate)) == _hurtbox(near), ctx.targets_for(bolt)],
		[true, [Combatant.of(near)] as Array[Combatant]])
	equal("and it takes the player's own one-target skill while another foe is locked",
		FieldCommands.targets(Combatant.of(_player), bolt), [Combatant.of(near)] as Array[Combatant])


func _bolt() -> BattleCommand:
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	command.skill.id = &"skill/fixture_aim_bolt"
	command.skill.power = 1.0
	return command


func _foe(id: StringName, at: Vector3) -> ActionEnemy:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"fixture_aim_foes"
	def.base_stats = {&"max_hp": 50.0}
	var made := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	made.fighter = def
	made.brain = ActionBrain.new()
	attach(made)
	made.global_position = at
	_foes.append(made)
	return made


func _hurtbox(body: Node) -> Hurtbox:
	for child: Node in body.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _lock_of(body: Node) -> LockOn:
	for child: Node in body.get_children():
		if child is LockOn:
			return child as LockOn
	return null


func _loadout(id: StringName) -> ActionLoadout:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_mp": 10.0}
	def.level_curve = LevelCurve.new()
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	return loadout
