extends TestCase
## `SkillUse` and `SkillEffect` (C2.13): every effect kind, multi-hit, statuses rolling once per
## target, a reviving skill aiming only at the fallen, and the revived rejoining the turn order.
##
## OWNS: assertions about what a skill does when it lands.
## MUST NOT: name a game's skills or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []


func run() -> void:
	plan(19)
	SaveFixture.activate()
	Flags.clear_all()
	_problems()
	_damage_heal_restore_and_hits()
	_drain()
	_cure_and_dispel()
	_revive_in_battle()
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float]) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _skill(effects: Array[SkillEffect], target: FactionTable.Target = FactionTable.Target.ENEMY) -> Skill:
	var skill := Skill.new()
	skill.id = &"skill/fixture"
	skill.name_key = "fixture.skill"
	skill.target = target
	skill.effects = effects
	return skill


func _effect(kind: SkillEffect.Kind, amount: float) -> SkillEffect:
	var effect := SkillEffect.new()
	effect.kind = kind
	effect.amount = amount
	return effect


func _pool(fighter: Combatant, pool: StringName = &"hp") -> int:
	return Vitals.of(fighter.get_parent()).current(pool)


func _problems() -> void:
	var only_effects := _skill([_effect(SkillEffect.Kind.DAMAGE, 3.0)])
	equal("a skill made only of effects does something", only_effects.problems(), PackedStringArray())
	var zero_hits := _skill([_effect(SkillEffect.Kind.DAMAGE, 3.0)])
	zero_hits.hits = 0
	equal("hits below 1 is caught", zero_hits.problems().size(), 1)
	var kind := _skill([_effect(SkillEffect.Kind.REVIVE, 0.5)])
	equal("a revive aimed at enemies is caught", kind.problems().size(), 1)
	var empty_cure := _effect(SkillEffect.Kind.CURE, 0.0)
	equal("a CURE naming no status is caught", empty_cure.problems("fixture").size(), 1)


func _damage_heal_restore_and_hits() -> void:
	Flags.clear_all()
	var user := _fighter(&"fixture_user", &"side_a", {&"attack": 0.0, &"max_hp": 40.0, &"max_mp": 20.0})
	var foe := _fighter(&"fixture_foe", &"side_b", {&"max_hp": 40.0})
	var rng := RandomNumberGenerator.new()
	var flurry := _skill([_effect(SkillEffect.Kind.DAMAGE, 2.0)])
	flurry.hits = 3
	var mark := StatusEffect.new()
	mark.id = &"status/fixture_mark"
	mark.stacking = StatusEffect.Stacking.STACK
	mark.max_stacks = 5
	flurry.statuses = [mark]
	SkillUse.apply(user, flurry, [foe], rng)
	equal("three hits of 2 power: 40 - 6", _pool(foe), 34)
	equal("its status rolled once, not once per hit", StatusSet.of(foe.get_parent()).stacks(mark.id), 1)
	Vitals.of(user.get_parent()).change(&"hp", -30)
	Vitals.of(user.get_parent()).change(&"mp", -15)
	SkillUse.apply(user, _skill([_effect(SkillEffect.Kind.HEAL, 12.0)], FactionTable.Target.SELF), [user], rng)
	equal("HEAL adds straight to hp: 10 + 12", _pool(user), 22)
	var ether := _effect(SkillEffect.Kind.RESTORE, 4.0)
	SkillUse.apply(user, _skill([ether], FactionTable.Target.SELF), [user], rng)
	equal("RESTORE fills another pool: 5 + 4 mp", _pool(user, &"mp"), 9)
	var pricey := _skill([_effect(SkillEffect.Kind.DAMAGE, 1.0)])
	pricey.cost_pool = &"mp"
	pricey.cost = 10
	equal("a cost above the pool is not affordable", SkillUse.affordable(user, pricey), false)
	pricey.cost = 9
	SkillUse.pay(user, pricey)
	equal("paying takes exactly the cost", _pool(user, &"mp"), 0)
	_free_all()


func _drain() -> void:
	Flags.clear_all()
	var user := _fighter(&"fixture_leech", &"side_a", {&"attack": 0.0, &"max_hp": 40.0})
	var foe := _fighter(&"fixture_host", &"side_b", {&"max_hp": 40.0})
	Vitals.of(user.get_parent()).change(&"hp", -20)
	var sap := _effect(SkillEffect.Kind.DRAIN, 10.0)
	sap.fraction = 0.5
	SkillUse.apply(user, _skill([sap]), [foe], RandomNumberGenerator.new())
	equal("DRAIN hurts the target by its power", _pool(foe), 30)
	equal("and gives the user half of what was taken: 20 + 5", _pool(user), 25)
	_free_all()


func _cure_and_dispel() -> void:
	Flags.clear_all()
	var user := _fighter(&"fixture_cleric", &"side_a", {})
	var friend := _fighter(&"fixture_friend", &"side_a", {&"max_hp": 10.0})
	var statuses := StatusSet.of(friend.get_parent())
	var sick := StatusEffect.new()
	sick.id = &"status/fixture_sick"
	var blessing := StatusEffect.new()
	blessing.id = &"status/fixture_blessing"
	blessing.tags = [&"buff"]
	var curse := StatusEffect.new()
	curse.id = &"status/fixture_curse"
	curse.tags = [&"debuff"]
	statuses.apply(sick)
	statuses.apply(blessing)
	statuses.apply(curse)
	var cure := _effect(SkillEffect.Kind.CURE, 0.0)
	cure.status_id = sick.id
	SkillUse.apply(user, _skill([cure], FactionTable.Target.ALLY), [friend], RandomNumberGenerator.new())
	equal("CURE ends the named status", statuses.stacks(sick.id), 0)
	var purge := _effect(SkillEffect.Kind.DISPEL, 0.0)
	purge.tag = &"debuff"
	SkillUse.apply(user, _skill([purge], FactionTable.Target.ALLY), [friend], RandomNumberGenerator.new())
	equal("DISPEL ends every status with its tag", statuses.stacks(curse.id), 0)
	equal("and leaves the others", statuses.stacks(blessing.id), 1)
	_free_all()


func _revive_in_battle() -> void:
	Flags.clear_all()
	var healer := _fighter(&"fixture_healer", &"side_a", {&"speed": 10.0, &"max_hp": 20.0})
	var fallen := _fighter(&"fixture_fallen", &"side_a", {&"speed": 5.0, &"max_hp": 20.0})
	var foe := _fighter(&"fixture_watcher", &"side_b", {&"speed": 1.0, &"max_hp": 99.0})
	var battle := Battle.new([healer, fallen], [foe], null, RandomNumberGenerator.new())
	battle.start()
	Vitals.of(fallen.get_parent()).change(&"hp", -20)
	battle.next_turn()
	var raise := BattleCommand.new()
	raise.kind = BattleCommand.Kind.SKILL
	raise.skill = _skill([_effect(SkillEffect.Kind.REVIVE, 0.5)], FactionTable.Target.ALLY)
	var mend := BattleCommand.new()
	mend.kind = BattleCommand.Kind.SKILL
	mend.skill = _skill([_effect(SkillEffect.Kind.HEAL, 5.0)], FactionTable.Target.ALLY)
	equal("a reviving skill aims only at the fallen", battle.targets_for(raise), [fallen] as Array[Combatant])
	equal("a heal aims only at those standing", battle.targets_for(mend), [healer] as Array[Combatant])
	battle.act(raise, [fallen])
	equal("REVIVE stands them up at half of max hp", _pool(fallen), 10)
	equal("and they rejoin the turn order", battle.scheduler.has(fallen.combatant_id), true)
	_free_all()
