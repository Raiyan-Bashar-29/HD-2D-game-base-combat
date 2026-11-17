extends TestCase
## Conditional outcomes (C8.15b). A spreading status passes to the holder's side when it runs
## out, only within reach, not to a foe, not back to who had it, and not when cured. A
## punishing status puts its answer on a foe that hits at the holder, not on an ally. A
## skill's stat filter keeps only the targets that fit, in a battle's list.
##
## OWNS: assertions about `Contagion`, `StatusEffect.spread_reach` and `punish_status`, and
## `Skill.filter`.
## MUST NOT: name a game's statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func run() -> void:
	plan(8)
	SaveFixture.activate()
	Flags.clear_all()
	_rng.seed = 5
	_spread()
	_clear()
	_punish()
	_clear()
	_filter()
	_clear()
	Flags.clear_all()


func _spread() -> void:
	var first: Combatant = _fighter(&"fixture_rot_first", &"side_a", Vector3.ZERO, 5.0)
	var near: Combatant = _fighter(&"fixture_rot_near", &"side_a", Vector3(2, 0, 0), 5.0)
	var far: Combatant = _fighter(&"fixture_rot_far", &"side_a", Vector3(30, 0, 0), 5.0)
	var foe: Combatant = _fighter(&"fixture_rot_foe", &"side_b", Vector3(1, 0, 0), 5.0)
	var rot: StatusEffect = _status(&"status/fixture_rot", 1.0)
	rot.spread_reach = 4.0
	var endless: StatusEffect = _status(&"status/fixture_rot_never", 0.0)
	endless.spread_reach = 4.0
	equal("a spreading status needs a duration", [rot.problems().size(), endless.problems().size()], [0, 1])
	_statuses(first).apply(rot)
	_statuses(first).tick_turn()
	equal("run out, it passes to the near ally: not the far one, not a foe, and it has left the first",
		[_held(first, rot), _held(near, rot), _held(far, rot), _held(foe, rot)], [0, 1, 0, 0])
	_statuses(near).tick_turn()
	equal("it does not pass back to one who has had it", [_held(first, rot), _held(near, rot)], [0, 0])
	var again: StatusEffect = _status(&"status/fixture_rot_cured", 1.0)
	again.spread_reach = 4.0
	_statuses(first).apply(again)
	_statuses(first).cure(again.id)
	equal("a cure stops the spread", _held(near, again), 0)


func _punish() -> void:
	var cursed: Combatant = _fighter(&"fixture_cursed", &"side_a", Vector3.ZERO, 5.0)
	var friend: Combatant = _fighter(&"fixture_cursed_friend", &"side_a", Vector3.ZERO, 5.0)
	var chaser: Combatant = _fighter(&"fixture_chaser", &"side_b", Vector3.ZERO, 5.0)
	var harm: StatusEffect = _status(&"status/fixture_harm", 3.0)
	var curse: StatusEffect = _status(&"status/fixture_curse", 3.0)
	curse.punish_status = harm
	var looped: StatusEffect = _status(&"status/fixture_loop", 3.0)
	looped.punish_status = looped
	equal("a status cannot punish with itself", [curse.problems().size(), looped.problems().size()], [0, 1])
	_statuses(cursed).apply(curse)
	friend.hit(cursed, 1.0, &"", _rng)
	var by_friend: int = _held(friend, harm)
	chaser.hit(cursed, 1.0, &"", _rng)
	equal("a foe that hits at the holder gets the answer; an ally does not",
		[by_friend, _held(chaser, harm)], [0, 1])


func _filter() -> void:
	var me: Combatant = _fighter(&"fixture_counter", &"side_a", Vector3.ZERO, 9.0, 50.0)
	var five: Combatant = _fighter(&"fixture_five", &"side_b", Vector3.ZERO, 5.0)
	var ten: Combatant = _fighter(&"fixture_ten", &"side_b", Vector3.ZERO, 10.0)
	var seven: Combatant = _fighter(&"fixture_seven", &"side_b", Vector3.ZERO, 7.0)
	var battle := Battle.new([me], [five, ten, seven])
	battle.start()
	battle.next_turn()
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = Skill.new()
	command.skill.id = &"skill/fixture_count"
	command.skill.name_key = "ui.cancel"
	command.skill.scope = Skill.Scope.ALL
	command.skill.power = 1.0
	command.skill.filter = Skill.Filter.MULTIPLE_OF
	command.skill.filter_value = 5.0
	var nameless: int = command.skill.problems().size()
	command.skill.filter_stat = &"defence"
	equal("a filter needs a stat, and keeps only the targets whose stat fits",
		[nameless, command.skill.problems().size(), battle.targets_for(command)], [1, 0, [five, ten]])
	command.skill.filter = Skill.Filter.ABOVE
	command.skill.filter_value = 6.0
	var above: Array[Combatant] = battle.targets_for(command)
	command.skill.filter = Skill.Filter.BELOW
	equal("ABOVE and BELOW compare the stat with the value", [above, battle.targets_for(command)], [[ten, seven], [five]])


func _statuses(fighter: Combatant) -> StatusSet:
	return StatusSet.of(fighter.get_parent())


func _held(fighter: Combatant, effect: StatusEffect) -> int:
	return _statuses(fighter).stacks(effect.id)


func _clear() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _status(id: StringName, lasts: float) -> StatusEffect:
	var made := StatusEffect.new()
	made.id = id
	made.name_key = "ui.cancel"
	made.duration = lasts
	return made


func _fighter(id: StringName, side: StringName, at: Vector3, defence: float,
		speed: float = 1.0) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	var statuses := StatusSet.new()
	statuses.save_id = StringName("statuses/" + String(id))
	actor.add_child(statuses)
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = {&"max_hp": 500.0, &"attack": 10.0, &"defence": defence, &"speed": speed}
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant
