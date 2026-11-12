extends TestCase
## Plants in the field (C6.26): the M15 shape and its problems; a use leaves plants spaced along
## the line through the target, at the user or ahead; a second use sets them off one after
## another; the most that may stand; the PROXIMITY, TIMER and ON_HIT triggers; a lifetime; the
## fight clock; a power named to set them off; the kit coming off; and a barrage's missed shots
## staying in the ground. The battle reading is `plant_battle_test`.
##
## OWNS: assertions about `PlantMechanism`, `PlantRun` and `Planted` in the field, and about
## `Projectile.landed`.
## MUST NOT: name a game's kits, powers or characters, or wait for physics frames.

const NOON: float = 12.0

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _foe: Combatant
var _ally: Combatant
var _powers: Dictionary[String, Power] = {}


func run() -> void:
	plan(17)
	Flags.clear_all()
	_rng.seed = 5
	_world = Node3D.new()
	attach(_world)
	_shapes()
	_me = _fighter(&"fixture_plant_me", &"player", Vector3.ZERO, _kit())
	_foe = _fighter(&"fixture_plant_foe", &"enemy", Vector3(0.0, 0.0, -6.0), null)
	_ally = _fighter(&"fixture_plant_ally", &"player", Vector3(0.0, 0.0, -4.0), null)
	_remote()
	_places()
	_triggers()
	_lifetime_and_clock()
	_misses()
	_world.free()
	Flags.clear_all()


func _shapes() -> void:
	var plant: PlantMechanism = _plant(PlantMechanism.Trigger.REMOTE, 1)
	equal("a plant's kind is plant, the base runs it, it aims at foes, and a clean one has no problems",
		[plant.kind(), PowerMechanisms.make(plant) is PlantRun, plant.aims_at_foes(), plant.problems("fixture").size()],
		[&"plant", true, true, 0])
	plant.eruption = null
	plant.mark = null
	plant.count = 0
	plant.trigger = PlantMechanism.Trigger.TIMER
	plant.seconds = 0.0
	plant.set_off_by = [&"power/fixture_plant_other"]
	equal("no eruption, no mark, none planted, a timer with no time and a name to set off a plant that is not remote are problems",
		plant.problems("fixture").size(), 5)


func _remote() -> void:
	_use("remote")
	var plants: Array[Planted] = _standing()
	var spots: Array[float] = []
	for planted: Planted in plants:
		spots.append(snappedf(planted.global_position.z, 0.01))
	equal("a use leaves its plants spaced along the line through the target, striking nothing yet",
		[spots, _hp(_foe)], [[-4.0, -6.0, -8.0], 100])
	_use("remote")
	_watch(0.01)
	_watch(0.01)
	equal("a second use sets them off one after another",
		[plants[0].strike(_hurtbox(_foe)), _hp(_foe) < 100, plants[2].strike(_hurtbox(_foe)), plants[2].armed()],
		[true, true, false, false])
	equal("an eruption does not strike an ally", plants[0].strike(_hurtbox(_ally)), false)
	for step: int in 3:
		_watch(1.0)
	equal("after the ripple every plant has erupted and is gone",
		[plants[0].gone(), plants[2].gone()], [true, true])
	_clear()
	_use("crowded")
	_use("crowded")
	equal("no more than the most that may stand stand", _standing().size(), 2)
	_clear()


func _places() -> void:
	_use("at_user")
	_use("ahead")
	var plants: Array[Planted] = _standing()
	equal("a plant at the user lies at its feet, and one ahead lies along its facing",
		[plants[0].global_position, snappedf(plants[1].global_position.z, 0.01)], [Vector3.ZERO, -3.0])
	_clear()


func _triggers() -> void:
	_use("proximity")
	var mine: Planted = _standing()[0]
	_watch(0.1)
	var waited: bool = mine.armed()
	(_foe.get_parent() as Node3D).position = Vector3(0.5, 0.0, 0.0)
	_watch(0.1)
	equal("a mine waits until a foe comes near", [waited, mine.armed()], [true, false])
	(_foe.get_parent() as Node3D).position = Vector3(0.0, 0.0, -6.0)
	_clear()
	_use("timer")
	var bomb: Planted = _standing()[0]
	_watch(1.0)
	var ticking: bool = bomb.armed()
	_watch(1.5)
	equal("a timer goes off when its seconds run out", [ticking, bomb.armed()], [true, false])
	_clear()
	_use("on_hit")
	var rune: Planted = _standing()[0]
	_me.hit(_ally, 3.0, &"", _rng)
	var after_ally: bool = rune.armed()
	_me.hit(_foe, 3.0, &"", _rng)
	equal("a rune bursts when the foe on it is hit, not when anyone else is", [after_ally, rune.armed()], [true, false])
	_clear()
	_use("remote")
	var named: Array[Planted] = _standing()
	_use("other")
	equal("a power named to set the plants off does", [named.size(), _standing().size()], [3, 0])
	_clear()


func _lifetime_and_clock() -> void:
	_use("timer")
	var bomb: Planted = _standing()[0]
	CombatClock.set_scale(0.0)
	bomb._physics_process(5.0)
	var frozen: bool = bomb.armed()
	CombatClock.reset()
	_clear()
	_use("short")
	var lost: Planted = _standing()[0]
	_watch(1.5)
	equal("a stopped fight holds a timer, and a plant left too long is lost without striking",
		[frozen, lost.gone(), _hp(_foe)], [true, true, 100])
	_clear()
	_use("remote")
	var left: Planted = _standing()[0]
	var powers: PowerSet = PowerSet.of(_me.get_parent())
	var kit: PowerKit = powers.kit
	powers.unequip()
	equal("the kit coming off takes its waiting plants away", left.is_queued_for_deletion(), true)
	powers.equip(kit)
	_clear()


func _misses() -> void:
	_use("volley")
	var shot: Projectile = _shots()[0]
	shot.fly(3.0)
	var shards: Array[Planted] = _standing()
	equal("a shot that ends its flight striking nobody leaves a plant where it ended",
		[shards.size(), shards[0].global_position.is_equal_approx(shot.global_position)], [1, true])
	_use("volley")
	var struck: Projectile = _shots()[0]
	struck.fly(0.01)
	struck.strike(_hurtbox(_foe))
	equal("a shot that strikes leaves none", _standing().size(), 1)
	_use("shards")
	equal("using the plant power sets the shards off", [shards[0].armed(), _standing().size()], [false, 0])
	_clear()


func _kit() -> PowerKit:
	var remote: PlantMechanism = _plant(PlantMechanism.Trigger.REMOTE, 3)
	remote.spread = 2.0
	remote.chain_delay = 0.5
	var crowded: PlantMechanism = _plant(PlantMechanism.Trigger.TIMER, 2)
	crowded.max_standing = 2
	var at_user: PlantMechanism = _plant(PlantMechanism.Trigger.TIMER, 1)
	at_user.where = PlantMechanism.Where.AT_USER
	var ahead: PlantMechanism = _plant(PlantMechanism.Trigger.TIMER, 1)
	ahead.where = PlantMechanism.Where.AHEAD
	var proximity: PlantMechanism = _plant(PlantMechanism.Trigger.PROXIMITY, 1)
	proximity.where = PlantMechanism.Where.AT_USER
	var on_hit: PlantMechanism = _plant(PlantMechanism.Trigger.ON_HIT, 1)
	var short: PlantMechanism = _plant(PlantMechanism.Trigger.REMOTE, 1)
	short.lifetime = 1.0
	remote.set_off_by = [&"power/fixture_plant_other"]
	var shards: PlantMechanism = _plant(PlantMechanism.Trigger.REMOTE, 1)
	shards.where = PlantMechanism.Where.WHERE_PROJECTILES_LAND
	var volley := BarrageMechanism.new()
	volley.pattern = BarrageMechanism.Pattern.LINE
	volley.count = 1
	volley.speed = 1.0
	volley.shots = [_move_of(1.0, 2.0)]
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_plant"
	kit.powers = [_power("remote", remote), _power("crowded", crowded), _power("at_user", at_user),
		_power("ahead", ahead), _power("proximity", proximity), _power("timer", _plant(PlantMechanism.Trigger.TIMER, 1)),
		_power("on_hit", on_hit), _power("short", short), _power("shards", shards), _power("volley", volley),
		_power("other", volley)]
	return kit


func _plant(trigger: PlantMechanism.Trigger, count: int) -> PlantMechanism:
	var plant := PlantMechanism.new()
	plant.trigger = trigger
	plant.count = count
	plant.eruption = _move_of(6.0, 0.3)
	plant.eruption.hitbox_size = Vector3(1.0, 3.0, 1.0)
	plant.eruption.hitbox_offset = Vector3(0.0, 1.5, 0.0)
	plant.mark = StatusEffect.new()
	plant.mark.id = &"status/fixture_plant_mark"
	plant.mark.name_key = "fixture.status"
	return plant


func _move_of(power: float, active: float) -> ActionMove:
	var move := ActionMove.new()
	move.startup = 0.0
	move.active = active
	move.recovery = 0.0
	move.power = power
	move.hitbox_size = Vector3(0.5, 0.5, 0.5)
	move.hitbox_offset = Vector3.ZERO
	return move


func _power(short: String, mechanism: PowerMechanism) -> Power:
	var power := Power.new()
	power.power_id = StringName("power/fixture_plant_" + short)
	power.name_key = "fixture.power"
	power.mechanism = mechanism
	_powers[short] = power
	return power


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(Hurtbox.new())
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	Vitals.of(fighter.get_parent()).set_to(&"hp", 100)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter


func _use(short: String) -> bool:
	return PowerUse.use(_me, _powers[short], [], _rng, NOON)


func _standing() -> Array[Planted]:
	var out: Array[Planted] = []
	for node: Node in _world.get_children():
		var planted: Planted = node as Planted
		if planted != null and planted.armed() and not planted.is_queued_for_deletion():
			out.append(planted)
	return out


func _shots() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for node: Node in _world.get_children():
		var shot: Projectile = node as Projectile
		if shot != null and not shot.gone():
			out.append(shot)
	return out


func _watch(dt: float) -> void:
	for node: Node in _world.get_children():
		if node is Planted:
			(node as Planted).watch(dt)


# Removes every plant and shot, puts hp back, and lets every power be used again.
func _clear() -> void:
	for node: Node in _world.get_children():
		if node is Planted or node is Projectile:
			node.free()
	for fighter: Combatant in [_me, _foe, _ally]:
		Vitals.of(fighter.get_parent()).set_to(&"hp", 100)
	var powers: PowerSet = PowerSet.of(_me.get_parent())
	var kit: PowerKit = powers.kit
	powers.unequip()
	powers.equip(kit)


func _hurtbox(fighter: Combatant) -> Hurtbox:
	for child: Node in fighter.get_parent().get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _hp(fighter: Combatant) -> int:
	return Vitals.of(fighter.get_parent()).current(&"hp")
