extends TestCase
## Barrages in a battle (C6.7): with no shots in flight, a barrage power is offered every standing
## foe as its targets, lands its hits among them at once, and a shot that is a skill lands the
## skill. The field side is `barrage_test`.
##
## OWNS: assertions about `BarrageRun`'s battle reading and the barrage branch of
## `Battle.targets_for`.
## MUST NOT: name a game's kits, powers or characters.

var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(3)
	Flags.clear_all()
	_battle()
	Flags.clear_all()


func _battle() -> void:
	var holder := Node.new()
	attach(holder)
	var hero: CombatantDef = _def(&"fixture_barrage_hero", &"side_a", 9.0)
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_barrage_battle"
	kit.name_key = "fixture.kit"
	var volley: BarrageMechanism = _barrage(BarrageMechanism.Pattern.RAIN, 8, 0.1)
	var marking: BarrageMechanism = _barrage(BarrageMechanism.Pattern.RAIN, 1, 0.1)
	marking.shots = [_marking_shot()]
	kit.powers = [_power("rain", volley), _power("mark", marking)]
	hero.power_kit = kit
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_barrage"
	encounter.enemies = [_def(&"fixture_barrage_one", &"side_b", 1.0), _def(&"fixture_barrage_two", &"side_b", 1.0)]
	var battle: Battle = BattleSetup.build(encounter, [hero], holder, RandomNumberGenerator.new())
	battle.rng.seed = 3
	battle.next_turn()
	var rain := BattleCommand.for_power(_powers["rain"])
	equal("in a battle a barrage aims at the standing foes", battle.targets_for(rain), battle.enemies)
	equal("its hits land at once, spread over the foes",
		[battle.act(rain, []), _hp(battle.enemies[0]) < 99, _hp(battle.enemies[1]) < 99], [true, true, true])
	for turn: int in 4:
		if battle.next_turn() == battle.party[0]:
			break
		battle.act(BattleCommand.new(), [battle.party[0]])
	var mark := BattleCommand.for_power(_powers["mark"])
	battle.act(mark, [])
	var marked: int = 0
	for foe: Combatant in battle.enemies:
		marked += StatusSet.of(foe.get_parent()).stacks(&"status/fixture_barrage_mark")
	equal("a shot that is a skill lands the skill", marked, 1)
	BattleSetup.release(battle)
	holder.free()


func _barrage(pattern: BarrageMechanism.Pattern, count: int, interval: float) -> BarrageMechanism:
	var barrage := BarrageMechanism.new()
	barrage.pattern = pattern
	barrage.count = count
	barrage.interval = interval
	barrage.speed = 10.0
	barrage.shots = [_shot(5.0)]
	return barrage


func _shot(power: float) -> ActionMove:
	var shot := ActionMove.new()
	shot.startup = 0.0
	shot.active = 2.0
	shot.recovery = 0.0
	shot.power = power
	shot.hitbox_size = Vector3(0.5, 0.5, 0.5)
	shot.hitbox_offset = Vector3.ZERO
	return shot


func _marking_shot() -> ActionMove:
	var status := StatusEffect.new()
	status.id = &"status/fixture_barrage_mark"
	status.name_key = "fixture.status"
	status.duration = 3.0
	var skill := Skill.new()
	skill.id = &"skill/fixture_barrage_mark"
	skill.name_key = "fixture.skill"
	skill.power = 1.0
	skill.sure_hit = true
	skill.statuses = [status]
	var shot: ActionMove = _shot(0.0)
	shot.skill = skill
	return shot


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_barrage_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _def(id: StringName, side: StringName, speed: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0, &"defence": 1.0}
	return def


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")
