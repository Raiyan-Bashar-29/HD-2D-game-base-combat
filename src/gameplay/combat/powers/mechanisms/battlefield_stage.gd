class_name BattlefieldStage
extends RefCounted
## What a battlefield does to the place and to where its fighters stand (C6.9f): the place's look,
## the weather held while it stands, and the fighters taken to a place of their own when it moves
## the fight (a reality marble's arena).
##
## IN PLAIN WORDS: `BattlefieldRun` tells this when the field rises, when it lowers, and when a
## fighter comes inside or leaves. The look is kept for the HUD to name (C6.9g). The weather is
## forced to the field's kind and put back as it was when the field ends, unless someone else
## changed it meanwhile. A fighter taken in for `moves_fight` is set down at a far pocket and set
## back where it stood when it leaves. The caster goes too, and the whole group takes one shift so
## it keeps its shape; once there, nobody outside is in reach, so the rest of the fight waits.
##
## THE POCKET: a stand-in place far from any fight, until art gives the place a real one.
##
## OWNS: the place look, the weather the field holds, and the bodies moved to the pocket.
## MUST NOT: decide who is inside (`BattlefieldRun` does), or touch statuses or modifiers.

## Where the fighters of a `moves_fight` field are set down: far from any fight.
const POCKET: Vector3 = Vector3(5000.0, 0.0, 5000.0)

# The place the field gives, or &"" for none. Kept for the HUD to name.
var _place_id: StringName = &""
# True while the field holds the weather.
var _holding: bool = false
# The weather the field holds, and the weather it found when it rose.
var _held: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR
var _before: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR
# Where each moved fighter stood before it went to the pocket, by instance id.
var _home: Dictionary[int, Vector3] = {}
# Fighters let in but not yet moved; `settle` moves them.
var _pending: Array[Combatant] = []
# The one shift every moved fighter takes, set when the first ones go, so the group keeps its shape.
var _shift: Vector3 = Vector3.ZERO


## The field rises: its place look goes on, and its weather is held when it names one.
func raise(field: BattlefieldMechanism) -> void:
	_place_id = field.place.id if field.place != null else &""
	if field.has_weather and not _holding:
		_holding = true
		_before = Weather.current()
		_held = field.weather
		Weather.force(_held)


## The field lowers: its place look goes, and the weather goes back unless someone changed it.
func lower() -> void:
	_place_id = &""
	if _holding:
		_holding = false
		if Weather.current() == _held:
			Weather.force(_before)


## The place look the field gives while it stands, or &"" (C6.9f).
func place_id() -> StringName:
	return _place_id


## True while the field holds the weather.
func holding_weather() -> bool:
	return _holding


## `other` comes inside a field that moves the fight: it is queued for the pocket, and `settle`
## moves it once everyone in reach has been let in, so reach is never measured from the pocket.
func take_in(other: Combatant, moves: bool) -> void:
	if moves and not _home.has(other.get_instance_id()) and not _pending.has(other):
		_pending.append(other)


## Moves the queued fighters to the pocket, all by the one shift, so they keep how they stood
## around the caster `me`.
func settle(me: Combatant) -> void:
	var centre: Node3D = (me.get_parent() as Node3D) if me != null else null
	if _pending.is_empty() or centre == null:
		return
	if _home.is_empty():
		_shift = POCKET - centre.global_position
	for other: Combatant in _pending:
		var body: Node3D = (other.get_parent() as Node3D) if is_instance_valid(other) else null
		if body != null:
			_home[other.get_instance_id()] = body.global_position
			body.global_position += _shift
	_pending.clear()


## `other` leaves (or the field ends): its body goes back to where it stood before the pocket.
func send_back(other: Combatant) -> void:
	_pending.erase(other)
	var id: int = other.get_instance_id()
	var body: Node3D = other.get_parent() as Node3D
	if not _home.has(id):
		return
	if body != null and is_instance_valid(body):
		body.global_position = _home[id]
	_home.erase(id)


## True while the fighter with `id` is in the pocket.
func is_moved(id: int) -> bool:
	return _home.has(id)
