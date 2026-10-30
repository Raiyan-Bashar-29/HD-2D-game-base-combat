extends TestCase
## Pressure and stagger (C4.6): the real-time side of Weakness and Break. A fighter that lives
## in real time is PRESSURED by a hit on its weakness (double poise for a while), STAGGERED when
## its shield empties (it stands still and takes more damage, counted in seconds), and gets its
## shield back when the stagger wears off. A fighter in a turn-based battle keeps BROKEN.
##
## OWNS: assertions about pressure, stagger and their recovery in the field.
## MUST NOT: name a game's skills, statuses or fighters. Every name here is made up for the case.

const S := ActionDecider.State
const DT: float = 0.1

var _actors: Array[Node] = []
var _broken: int = 0


func run() -> void:
	plan(16)
	SaveFixture.activate()
	Flags.clear_all()
	Events.combatant_broken.connect(_on_broken)
	_pressure_then_stagger()
	_stagger_wears_off()
	_a_battle_still_breaks()
	_a_game_swaps_the_stagger()
	_an_enemy_stands_still()
	_the_player_stands_still()
	Events.combatant_broken.disconnect(_on_broken)
	for actor: Node in _actors:
		actor.free()
	_actors.clear()
	Flags.clear_all()


func _fighter(id: StringName, side: StringName, stats: Dictionary[StringName, float],
		real_time: bool, weak_to: Array[StringName] = []) -> Combatant:
	var actor := Node.new()
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var combatant := Combatant.new()
	combatant.combatant_id = id
	combatant.faction = side
	combatant.base_stats = stats
	combatant.weak_to = weak_to
	combatant.real_time = real_time
	# Attack against defence, then vulnerability: no misses, crits or variance, exact numbers.
	combatant.formula = DamageFormula.new()
	combatant.formula.stages = [AttackDefenceStage.new(), VulnerabilityStage.new()]
	actor.add_child(combatant)
	attach(actor)
	_actors.append(actor)
	var vitals: Vitals = Vitals.of(actor)
	vitals.set_to(&"shield", vitals.maximum(&"shield"))
	return combatant


func _flame() -> Skill:
	var made := Skill.new()
	made.id = &"skill/fixture_flame"
	made.name_key = "fixture.flame"
	made.power = 1.0
	made.element = &"fixture_fire"
	return made


func _shield(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"shield")


func _statuses(fighter: Combatant) -> StatusSet:
	return StatusSet.of(fighter.get_parent())


func _pressure_then_stagger() -> void:
	var mage := _fighter(&"fixture_mage", &"side_a", {&"max_hp": 50.0, &"attack": 10.0}, true)
	var moth := _fighter(&"fixture_moth", &"side_b", {&"max_hp": 999.0, &"max_shield": 3.0}, true,
		[&"fixture_fire"])
	var twin := _fighter(&"fixture_twin", &"side_b", {&"max_hp": 999.0}, true)
	var rng := RandomNumberGenerator.new()
	_broken = 0
	SkillUse.apply(mage, _flame(), [moth], rng)
	equal("a weakness hit in real time takes a shield point and pressures the target",
		[_shield(moth), _statuses(moth).stacks(Weakness.pressured_status().id),
			_statuses(moth).halts()], [2, 1, false])
	Weakness.wear(moth, 1)
	equal("pressured, one point of poise takes two and empties the shield", _shield(moth), 0)
	equal("an empty shield in real time staggers, counted in seconds, and never BROKEN",
		[_statuses(moth).stacks(Weakness.staggered_status().id),
			_statuses(moth).stacks(Weakness.broken_status().id),
			_statuses(moth).remaining(Weakness.staggered_status().id)], [1, 0, 4.0])
	equal("the stagger ends the pressure, and is announced as a break",
		[_statuses(moth).stacks(Weakness.pressured_status().id), _broken], [0, 1])
	equal("a staggered fighter halts", _statuses(moth).halts(), true)
	var before: int = Vitals.of(twin.get_parent()).current(&"hp")
	mage.hit(twin, 1.0, &"", rng)
	var plain: int = before - Vitals.of(twin.get_parent()).current(&"hp")
	var hp: int = Vitals.of(moth.get_parent()).current(&"hp")
	mage.hit(moth, 1.0, &"", rng)
	equal("a staggered fighter takes 60% more from the same hit",
		hp - Vitals.of(moth.get_parent()).current(&"hp"), roundi(plain * 1.6))


func _stagger_wears_off() -> void:
	var moth: Combatant = Combatant.of(_actors[1])
	_statuses(moth).tick_seconds(3.0)
	Weakness.recover(moth)
	equal("mid-stagger the shield stays empty", _shield(moth), 0)
	_statuses(moth).tick_seconds(1.5)
	Weakness.recover(moth)
	equal("when the stagger wears off the shield refills and the fighter moves again",
		[_shield(moth), _statuses(moth).halts()], [3, false])


func _a_battle_still_breaks() -> void:
	var mage := _fighter(&"fixture_mage_b", &"side_a", {&"max_hp": 50.0, &"attack": 10.0}, false)
	var wisp := _fighter(&"fixture_wisp", &"side_b", {&"max_hp": 999.0, &"max_shield": 2.0}, false,
		[&"fixture_fire"])
	var rng := RandomNumberGenerator.new()
	SkillUse.apply(mage, _flame(), [wisp], rng)
	equal("in a battle a weakness hit pressures nothing",
		_statuses(wisp).stacks(Weakness.pressured_status().id), 0)
	SkillUse.apply(mage, _flame(), [wisp], rng)
	equal("and an empty shield is still BROKEN, counted in turns",
		[_statuses(wisp).stacks(Weakness.broken_status().id),
			_statuses(wisp).stacks(Weakness.staggered_status().id)], [1, 0])


func _a_game_swaps_the_stagger() -> void:
	var own := StatusEffect.new()
	own.id = &"status/fixture_reel"
	own.unit = StatusEffect.Unit.SECONDS
	own.duration = 1.0
	Weakness.staggered = own
	var brute := _fighter(&"fixture_brute", &"side_b", {&"max_hp": 99.0, &"max_shield": 1.0}, true)
	Weakness.wear(brute, 1)
	equal("a game's own stagger status replaces the default", _statuses(brute).stacks(own.id), 1)
	Weakness.staggered = null


func _an_enemy_stands_still() -> void:
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_beast"
	def.faction = &"side_b"
	def.base_stats = {&"max_hp": 40.0, &"max_shield": 2.0}
	var brain := ActionBrain.new()
	brain.wander_radius = 0.0
	var enemy := build("res://scenes/objects/action_enemy.tscn") as ActionEnemy
	enemy.fighter = def
	enemy.brain = brain
	attach(enemy)
	_actors.append(enemy)
	var me: Combatant = Combatant.of(enemy)
	equal("a field enemy lives in real time", me.real_time, true)
	var swing := ActionMove.new()
	swing.startup = 1.0
	enemy.timeline.start(swing)
	Weakness.wear(me, 2)
	equal("staggered, it drops its swing and stands STAGGERED",
		[enemy.act(DT), enemy.timeline.busy()], [S.STAGGERED, false])
	for i: int in 45:
		enemy.act(DT)
	equal("after the stagger its own frames refill the shield", Vitals.of(enemy).current(&"shield"), 2)


func _the_player_stands_still() -> void:
	var player := build("res://scenes/characters/player.tscn") as PlayerController
	attach(player)
	_actors.append(player)
	var def := CombatantDef.new()
	def.combatant_id = &"fixture_hero"
	def.faction = &"player"
	def.base_stats = {&"max_hp": 40.0, &"max_shield": 1.0}
	var loadout := ActionLoadout.new()
	loadout.fighter = def
	loadout.moves = MoveSet.new()
	var fighter: ActionFighter = ActionHost.equip(player, loadout)
	var me: Combatant = Combatant.of(player)
	Vitals.of(player).set_to(&"shield", 1)
	Weakness.wear(me, 1)
	fighter.drive(DT, false, false)
	equal("an equipped player is staggered like anyone in the field",
		[me.real_time, fighter.stunned()], [true, true])
	for i: int in 45:
		fighter.drive(DT, false, false)
	equal("and recovers on its own frames", [fighter.stunned(), Vitals.of(player).current(&"shield")],
		[false, 1])


func _on_broken(_who: StringName) -> void:
	_broken += 1
