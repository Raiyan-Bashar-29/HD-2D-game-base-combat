extends TestCase
## A battlefield's place (C6.9f): the look it gives while it stands, the weather it holds and puts
## back, and the fighters a `moves_fight` field takes to a place of their own and sets back.
##
## OWNS: assertions about `BattlefieldMechanism.place`, `moves_fight`, `has_weather` and `weather`,
## and `BattlefieldStage` as `BattlefieldRun` uses it.
## MUST NOT: name a game's places, powers or characters, or wait for frames.

const NOON: float = 12.0
const PLACE: StringName = &"place/fixture_place_look"
const NEAR: Vector3 = Vector3(0.0, 0.0, -3.0)
const FAR: Vector3 = Vector3(0.0, 0.0, -20.0)

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _me: Combatant
var _near: Combatant
var _far: Combatant
var _power: Power
var _weather_before: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR


func run() -> void:
	plan(15)
	Flags.clear_all()
	_rng.seed = 7
	_weather_before = Weather.current()
	_problems()
	_look()
	_weather()
	_moves()
	_stays()
	if _world != null:
		_world.free()
	Weather.force(_weather_before)
	Flags.clear_all()


# A place look with no id is one problem more than the same look with one.
func _problems() -> void:
	var clean := _field(false)
	var bad := _field(false)
	bad.place = _look_of(&"")
	equal("a place look with no id is one problem more than a named one",
		bad.problems("fixture").size() - clean.problems("fixture").size(), 1)


# Raised, the field gives its place look; ended, the look goes.
func _look() -> void:
	_fresh(_field(false))
	PowerUse.use(_me, _power, [], _rng, NOON)
	equal("a raised battlefield gives its place look", _run().place_stage().place_id(), PLACE)
	PowerSet.of(_me.get_parent()).unequip()
	equal("an ended battlefield's place look goes", _run() == null or
		_run().place_stage().place_id() == &"", true)


# A field with a weather holds it and puts the old one back; one without leaves the weather alone.
func _weather() -> void:
	Weather.force(GameEnums.WeatherKind.CLEAR)
	var stormy := _field(false)
	stormy.has_weather = true
	stormy.weather = GameEnums.WeatherKind.STORM
	_fresh(stormy)
	PowerUse.use(_me, _power, [], _rng, NOON)
	equal("a raised battlefield holds its weather", Weather.current(), GameEnums.WeatherKind.STORM)
	equal("the battlefield says it holds the weather", _run().place_stage().holding_weather(), true)
	PowerSet.of(_me.get_parent()).unequip()
	equal("an ended battlefield puts the old weather back", Weather.current(), GameEnums.WeatherKind.CLEAR)
	Weather.force(GameEnums.WeatherKind.RAIN)
	_fresh(_field(false))
	PowerUse.use(_me, _power, [], _rng, NOON)
	equal("a battlefield with no weather leaves the weather alone", Weather.current(), GameEnums.WeatherKind.RAIN)


# A field that moves the fight takes the fighters in reach, caster too, to its place, keeps them
# there, and sets them back where they stood when it ends. One out of reach waits where it is.
func _moves() -> void:
	_fresh(_field(true))
	PowerUse.use(_me, _power, [], _rng, NOON)
	equal("a fighter in reach is taken to the battlefield's place", _body(_near).global_position.length() > 1000.0, true)
	equal("the caster goes to the place too", _body(_me).global_position.length() > 1000.0, true)
	equal("a fighter out of reach is not taken", _body(_far).global_position, FAR)
	equal("the group keeps its shape in the place",
		is_equal_approx(_body(_near).global_position.distance_to(_body(_me).global_position), 3.0), true)
	PowerSet.of(_me.get_parent()).tick_seconds(0.1)
	equal("a taken fighter stays inside after a tick, whatever its reach",
		_run().place_stage().is_moved(_near.get_instance_id()), true)
	PowerSet.of(_me.get_parent()).unequip()
	equal("an ended battlefield sets the fighter back where it stood", _body(_near).global_position, NEAR)
	equal("an ended battlefield sets the caster back where it stood", _body(_me).global_position, Vector3.ZERO)


# A field that does not move the fight moves nobody.
func _stays() -> void:
	_fresh(_field(false))
	PowerUse.use(_me, _power, [], _rng, NOON)
	equal("a battlefield that does not move the fight moves nobody", _body(_near).global_position, NEAR)


# --- fixtures -----------------------------------------------------------------------------------

# A fresh world: `_me` at the origin wearing a kit of `field`, `_near` in its reach and `_far` out.
func _fresh(field: BattlefieldMechanism) -> void:
	if _world != null:
		_world.free()
	_world = Node3D.new()
	attach(_world)
	_power = Power.new()
	_power.power_id = &"power/fixture_place_field"
	_power.name_key = "fixture.power"
	_power.mechanism = field
	var kit := PowerKit.new()
	kit.kit_id = &"kit/fixture_place_me"
	kit.name_key = "fixture.kit"
	kit.powers = [_power]
	_me = _fighter(&"fixture_place_me", &"player", Vector3.ZERO, kit)
	_near = _fighter(&"fixture_place_near", &"enemy", NEAR, null)
	_far = _fighter(&"fixture_place_far", &"enemy", FAR, null)


# A battlefield 5 m across with one empty effect and the place look; `moves` sets `moves_fight`.
func _field(moves: bool) -> BattlefieldMechanism:
	var field := BattlefieldMechanism.new()
	var status := StatusEffect.new()
	status.id = &"status/fixture_place_field"
	status.name_key = "fixture.status"
	status.duration = 0.0
	field.status = status
	field.effects = [BattlefieldEffect.new()]
	field.radius = 5.0
	field.place = _look_of(PLACE)
	field.moves_fight = moves
	return field


func _look_of(id: StringName) -> PlaceLook:
	var look := PlaceLook.new()
	look.id = id
	look.name_key = "fixture.place"
	return look


# The caster's running battlefield, or null.
func _run() -> BattlefieldRun:
	for run: PowerExecutor in PowerSet.of(_me.get_parent()).running():
		if run is BattlefieldRun:
			return run as BattlefieldRun
	return null


func _body(fighter: Combatant) -> Node3D:
	return fighter.get_parent() as Node3D


func _fighter(id: StringName, faction: StringName, at: Vector3, kit: PowerKit) -> Combatant:
	var actor := Node3D.new()
	actor.position = at
	actor.add_child(Vitals.new())
	actor.add_child(StatusSet.new())
	var fighter := Combatant.new()
	fighter.combatant_id = id
	fighter.faction = faction
	fighter.real_time = true
	fighter.base_stats = {&"max_hp": 100.0, &"max_mp": 10.0, &"attack": 6.0, &"defence": 1.0}
	fighter.formula = DamageFormula.new()
	fighter.formula.stages = [AttackDefenceStage.new()]
	actor.add_child(fighter)
	actor.add_child(PowerSet.new())
	_world.add_child(actor)
	if kit != null:
		PowerSet.of(actor).equip(kit)
	return fighter
