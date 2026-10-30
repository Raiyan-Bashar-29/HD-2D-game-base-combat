extends TestCase
## Weakness and Break (C2.17): a hit matching a weakness takes a shield point and reveals the
## weakness, the last point breaks the target, a broken target takes more damage and loses its
## next turn, and its shield comes back afterwards. One code path, which C3's poise and C4's
## pressure reuse.
##
## OWNS: assertions about weaknesses, shields and Break.
## MUST NOT: name a game's skills, statuses or fighters. Every name here is made up for the case.

var _actors: Array[Node] = []
var _revealed: int = 0
var _broken: int = 0


func run() -> void:
	plan(14)
	SaveFixture.activate()
	Flags.clear_all()
	Events.weakness_revealed.connect(_on_revealed)
	Events.combatant_broken.connect(_on_broken)
	_chipping_the_shield()
	_a_break_in_battle()
	Events.weakness_revealed.disconnect(_on_revealed)
	Events.combatant_broken.disconnect(_on_broken)
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float],
		weak_to: Array[StringName] = []) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.weak_to = weak_to
	# Accuracy, attack against defence, then vulnerability: no crit or variance, exact numbers.
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AccuracyStage.new(), AttackDefenceStage.new(), VulnerabilityStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	return combatant


func _free_all() -> void:
	for actor: Node in _actors:
		actor.free()
	_actors.clear()


func _vitals(fighter: Combatant) -> Vitals:
	return Vitals.of(fighter.get_parent())


func _skill(name: String, power: float, element: StringName) -> Skill:
	var made := Skill.new()
	made.id = StringName("skill/" + name)
	made.name_key = "fixture." + name
	made.power = power
	made.element = element
	return made


func _chipping_the_shield() -> void:
	Flags.clear_all()
	var mage := _fighter(&"fixture_mage", &"side_a", {&"max_hp": 50.0})
	var wisp := _fighter(&"fixture_wisp", &"side_b", {&"max_hp": 99.0, &"max_shield": 2.0}, [&"fixture_fire"])
	var rng := RandomNumberGenerator.new()
	_revealed = 0
	_broken = 0
	var flame: Skill = _skill("fixture_flame", 1.0, &"fixture_fire")
	SkillUse.apply(mage, flame, [wisp], rng)
	equal("a hit matching a weakness takes one shield point", _vitals(wisp).current(&"shield"), 1)
	equal("and reveals the weakness, remembered in Flags", Weakness.revealed(wisp, &"fixture_fire"), true)
	equal("the reveal is announced once", _revealed, 1)
	SkillUse.apply(mage, _skill("fixture_frost", 1.0, &"fixture_ice"), [wisp], rng)
	equal("a hit that matches nothing leaves the shield alone", _vitals(wisp).current(&"shield"), 1)
	SkillUse.apply(mage, flame, [wisp], rng)
	equal("the last shield point breaks it", StatusSet.of(wisp.get_parent()).stacks(Weakness.broken_status().id), 1)
	equal("and the break is announced", _broken, 1)
	var before: int = _vitals(wisp).current(&"hp")
	SkillUse.apply(mage, _skill("fixture_jab", 10.0, &""), [wisp], rng)
	equal("a broken target takes half as much again: 10 becomes 15", before - _vitals(wisp).current(&"hp"), 15)
	var twin := _fighter(&"fixture_wisp_2", &"side_b", {&"max_hp": 9.0}, [&"fixture_fire"])
	twin.kind = &"fixture_wisp"
	equal("a weakness is revealed for the whole kind, so its twin shows it too",
		Weakness.revealed(twin, &"fixture_fire"), true)
	var ghost := _fighter(&"fixture_ghost", &"side_b", {&"max_hp": 9.0, &"max_shield": 3.0,
		&"evasion": 1.0}, [&"fixture_fire"])
	SkillUse.apply(mage, flame, [ghost], rng)
	equal("a hit that missed chips nothing", _vitals(ghost).current(&"shield"), 3)
	equal("the standard formula applies vulnerability",
		DamageFormula.standard().stages.any(func(s: DamageStage) -> bool: return s is VulnerabilityStage), true)
	_free_all()


func _a_break_in_battle() -> void:
	Flags.clear_all()
	var knight := _fighter(&"fixture_knight", &"side_a", {&"speed": 9.0, &"attack": 1.0, &"max_hp": 50.0})
	knight.attack_tags = [&"fixture_blade"]
	var brute := _fighter(&"fixture_brute", &"side_b", {&"speed": 1.0, &"max_hp": 50.0,
		&"max_shield": 1.0}, [&"fixture_blade"])
	var battle := Battle.new([knight], [brute], null, RandomNumberGenerator.new())
	battle.start()
	battle.next_turn()
	var attack := BattleCommand.new()
	attack.kind = BattleCommand.Kind.ATTACK
	battle.act(attack, [brute])
	equal("a plain attack carries its attack_tags, and breaks the brute", _vitals(brute).current(&"shield"), 0)
	equal("the broken brute loses its turn, so the knight moves again", battle.next_turn(), knight)
	equal("the shield comes back once the break is over", _vitals(brute).current(&"shield"), 1)
	equal("and the break has worn off", StatusSet.of(brute.get_parent()).stacks(Weakness.broken_status().id), 0)
	_free_all()


func _on_revealed(_who: StringName, _key: StringName) -> void:
	_revealed += 1


func _on_broken(_who: StringName) -> void:
	_broken += 1
