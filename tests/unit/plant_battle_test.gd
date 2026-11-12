extends TestCase
## Plants in a battle (C6.26): nothing stands in the ground, so a plant is a mark on a foe. A
## plant power is offered every standing foe; a use marks foes at random; a REMOTE plant's next
## use sets every mark off, each foe taking the eruption once per mark; a TIMER mark goes off
## after its turns; a PROXIMITY mark when the marked foe next deals damage; an ON_HIT mark when
## it is next hit; and a barrage's shot that misses marks the foe it was aimed at.
##
## OWNS: assertions about `PlantRun`'s battle reading.
## MUST NOT: name a game's kits, powers or characters.

const MARK: StringName = &"status/fixture_plant_battle_mark"

var _powers: Dictionary[String, Power] = {}
var _holder: Node
var _battle: Battle


func run() -> void:
	plan(6)
	Flags.clear_all()
	_holder = Node.new()
	attach(_holder)
	_remote()
	_timer()
	_proximity_and_hit()
	_misses()
	_holder.free()
	Flags.clear_all()


func _remote() -> void:
	_start(0.0)
	var mark := BattleCommand.for_power(_powers["remote"])
	equal("in a battle a plant aims at the standing foes", _battle.targets_for(mark), _battle.enemies)
	_battle.act(mark, [])
	equal("a use marks foes at random, striking nobody yet", [_marks(), _hurt()], [3, 0])
	_hero_turn()
	_battle.act(mark, [])
	equal("the next use sets every mark off, once per mark, and they are gone",
		[_marks(), _hurt() > 0], [0, true])
	_end()


func _timer() -> void:
	_start(0.0)
	_battle.act(BattleCommand.for_power(_powers["timer"]), [])
	_hero_turn()
	var waiting: int = _marks()
	_hero_turn()
	equal("a timer mark goes off after its turns", [waiting, _marks(), _hurt() > 0], [1, 0, true])
	_end()


func _proximity_and_hit() -> void:
	_start(0.0)
	var foe: Combatant = _battle.enemies[0]
	_marked_run("proximity").projectile_landed(Vector3.ZERO, foe)
	_marked_run("on_hit").projectile_landed(Vector3.ZERO, _battle.enemies[1])
	_battle.enemies[1].hit(_battle.party[0], 3.0, &"", _battle.rng)
	var after_other: int = _marks()
	foe.hit(_battle.party[0], 3.0, &"", _battle.rng)
	var after_attack: int = _marks()
	_battle.party[0].hit(_battle.enemies[1], 3.0, &"", _battle.rng)
	equal("a mine mark goes off when its foe deals damage, a rune mark when its foe is hit",
		[after_other, after_attack, _marks()], [2, 1, 0])
	_end()


func _misses() -> void:
	_start(1.0)
	_battle.act(BattleCommand.for_power(_powers["volley"]), [])
	equal("each barrage shot that misses marks the foe it was aimed at, once for each plant waiting on landings",
		_marks(), 4)
	_end()


func _start(evasion: float) -> void:
	var hero: CombatantDef = _def(&"fixture_plant_hero", &"side_a", 9.0, 0.0)
	hero.power_kit = _kit()
	var encounter := Encounter.new()
	encounter.id = &"encounter/fixture_plant"
	encounter.enemies = [_def(&"fixture_plant_one", &"side_b", 1.0, evasion),
		_def(&"fixture_plant_two", &"side_b", 1.0, evasion)]
	_battle = BattleSetup.build(encounter, [hero], _holder, RandomNumberGenerator.new())
	_battle.rng.seed = 4
	_battle.next_turn()


func _end() -> void:
	BattleSetup.release(_battle)
	for child: Node in _holder.get_children():
		child.free()


# Plays turns until it is the hero's again, the foes waiting.
func _hero_turn() -> void:
	for turn: int in 6:
		if _battle.next_turn() == _battle.party[0]:
			return
		_battle.act(BattleCommand.new(), [_battle.party[0]])


func _marked_run(short: String) -> PowerExecutor:
	return PowerSet.of(_battle.party[0].get_parent()).executor(_powers[short].power_id)


func _marks() -> int:
	var total: int = 0
	for foe: Combatant in _battle.enemies:
		total += StatusSet.of(foe.get_parent()).stacks(MARK)
	return total


# How much hp the foes have lost in all.
func _hurt() -> int:
	var total: int = 0
	for foe: Combatant in _battle.enemies:
		total += 99 - Vitals.of(foe.get_parent()).current(&"hp")
	return total


func _kit() -> PowerKit:
	var remote: PlantMechanism = _plant(PlantMechanism.Trigger.REMOTE)
	remote.count = 3
	var timer: PlantMechanism = _plant(PlantMechanism.Trigger.TIMER)
	timer.turns = 2
	var landing_mine: PlantMechanism = _plant(PlantMechanism.Trigger.PROXIMITY)
	landing_mine.where = PlantMechanism.Where.WHERE_PROJECTILES_LAND
	var landing_rune: PlantMechanism = _plant(PlantMechanism.Trigger.ON_HIT)
	landing_rune.where = PlantMechanism.Where.WHERE_PROJECTILES_LAND
	var volley := BarrageMechanism.new()
	volley.count = 2
	volley.shots = [_move_of(5.0)]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_plant_battle"
	kit.name_key = "fixture.kit"
	kit.powers = [_power("remote", remote), _power("timer", timer), _power("proximity", landing_mine),
		_power("on_hit", landing_rune), _power("volley", volley)]
	return kit


func _plant(trigger: PlantMechanism.Trigger) -> PlantMechanism:
	var plant := PlantMechanism.new()
	plant.trigger = trigger
	plant.eruption = _move_of(1.0)
	plant.mark = StatusEffect.new()
	plant.mark.id = MARK
	plant.mark.name_key = "fixture.status"
	plant.mark.duration = 9.0
	plant.mark.stacking = StatusEffect.Stacking.STACK
	plant.mark.max_stacks = 9
	return plant


func _move_of(power: float) -> ActionMove:
	var move := ActionMove.new()
	move.startup = 0.0
	move.active = 0.2
	move.recovery = 0.0
	move.power = power
	move.hitbox_size = Vector3(0.5, 0.5, 0.5)
	return move


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_plant_battle_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _def(id: StringName, side: StringName, speed: float, evasion: float) -> CombatantDef:
	var def := CombatantDef.new()
	def.combatant_id = id
	def.name_key = "fixture.name." + String(id)
	def.faction = side
	def.base_stats = {&"max_hp": 99.0, &"max_mp": 20.0, &"speed": speed, &"attack": 6.0,
		&"defence": 1.0, &"evasion": evasion}
	return def
