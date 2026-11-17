extends TestCase
## Unseen (C8.12): a fighter holding a status marked `unseen` is left out of a battle's target
## list for a one-target command but not for a skill that hits everyone; an ally still sees
## it; lock-on, the nearest-foe search and a field command's candidates skip it, and a lock
## already on it is dropped; hitting a foe or being hit by one ends it; a DISPEL by its tag
## ends it too.
##
## OWNS: assertions about `Unseen` and `StatusEffect.unseen`.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []


func run() -> void:
	plan(9)
	SaveFixture.activate()
	Flags.clear_all()
	_battle()
	_clear()
	_field()
	_clear()
	_ending()
	_clear()
	Flags.clear_all()


func _battle() -> void:
	var me: Combatant = _fighter(&"fixture_seeker", &"side_a", Vector3.ZERO, 9.0)
	var friend: Combatant = _fighter(&"fixture_seeker_friend", &"side_a", Vector3.ZERO, 1.0)
	var hidden: Combatant = _fighter(&"fixture_hidden", &"side_b", Vector3.ZERO, 2.0)
	var plain: Combatant = _fighter(&"fixture_plain", &"side_b", Vector3.ZERO, 2.0)
	StatusSet.of(hidden.get_parent()).apply(_veil())
	var battle := Battle.new([me, friend], [hidden, plain])
	battle.start()
	battle.next_turn()
	var attack := BattleCommand.new()
	equal("a plain attack cannot be aimed at an unseen foe", battle.targets_for(attack), [plain])
	equal("and choosing it anyway is refused", battle.act(attack, [hidden]), false)
	var wide := BattleCommand.new()
	wide.kind = BattleCommand.Kind.SKILL
	wide.skill = Skill.new()
	wide.skill.id = &"skill/fixture_sweep"
	wide.skill.name_key = "ui.cancel"
	wide.skill.scope = Skill.Scope.ALL
	wide.skill.power = 1.0
	equal("a skill that hits everyone reaches it", battle.targets_for(wide), [hidden, plain])
	battle.act(wide, [])
	equal("and that hit ends the unseen status", Unseen.hides(hidden), false)
	StatusSet.of(friend.get_parent()).apply(_veil())
	equal("an unseen ally is still seen by its own side",
		[Unseen.open(me, friend, FactionTable.Target.ALLY), Unseen.open(plain, friend, FactionTable.Target.ENEMY)],
		[true, false])


func _field() -> void:
	var me: Combatant = _fighter(&"fixture_hunter", &"side_c", Vector3.ZERO, 1.0)
	var body: Node3D = me.get_parent() as Node3D
	var lock := LockOn.new()
	body.add_child(lock)
	var near: Combatant = _fighter(&"fixture_prey_near", &"side_d", Vector3(0, 0, -2), 1.0)
	var far: Combatant = _fighter(&"fixture_prey_far", &"side_d", Vector3(0, 0, -5), 1.0)
	lock.cycle()
	var first: Combatant = lock.target.fighter()
	StatusSet.of(near.get_parent()).apply(_veil())
	lock.refresh()
	equal("a lock on a fighter that turns unseen is dropped, and it is no longer a candidate",
		[first, lock.target, lock.candidates().size()], [near, null, 1])
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	equal("the nearest-foe search, the threat pick and a field command all skip it",
		[Hurtbox.nearest_hostile(body).fighter(), Aggro.pick(body).fighter(),
			FieldCommands.candidates(me, command)], [far, far, [far]])


func _ending() -> void:
	var sneak: Combatant = _fighter(&"fixture_sneak", &"side_e", Vector3(50, 0, 0), 1.0)
	var mark: Combatant = _fighter(&"fixture_mark", &"side_f", Vector3(51, 0, 0), 1.0)
	var statuses: StatusSet = StatusSet.of(sneak.get_parent())
	statuses.apply(_veil())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	sneak.hit(mark, 0.0, &"", rng)
	equal("an unseen fighter that hits a foe is seen again", Unseen.hides(sneak), false)
	statuses.apply(_veil())
	var light := Skill.new()
	var effect := SkillEffect.new()
	effect.kind = SkillEffect.Kind.DISPEL
	effect.tag = &"fixture_veil"
	light.effects = [effect]
	SkillUse.apply(mark, light, [sneak], rng)
	equal("a DISPEL by the status's tag reveals it", Unseen.hides(sneak), false)


func _clear() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _veil() -> StatusEffect:
	var made := StatusEffect.new()
	made.id = &"status/fixture_veil"
	made.name_key = "ui.cancel"
	made.duration = 9.0
	made.unseen = true
	made.tags = [&"fixture_veil"]
	return made


func _fighter(id: StringName, side: StringName, at: Vector3, speed: float) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"speed": speed}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	actor.add_child(Hurtbox.new())
	attach(actor)
	_actors.append(actor)
	return combatant
