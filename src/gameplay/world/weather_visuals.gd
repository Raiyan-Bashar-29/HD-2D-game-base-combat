class_name WeatherVisuals
extends Node3D
## The one node that makes Weather visible. Drop it in an area and rain falls, snow drifts,
## motes blow past, the ground darkens and dries, and the ambience bed rises with the storm.
##
## WHY THIS NODE EXISTS AT ALL
## `Weather` has published a kind, a blend and an intensity since Phase 0 and NOTHING read
## them except the fog density in the environment driver. A weather system nobody can see is a
## number in a log file. This is the listener that was missing.
##
## OWNS: three generated emitters, this area's wetness value, and the ambience levels.
## MUST NOT: decide what the weather is, ever — not even "if it has been clear too long".
## Every number here is read from Weather. That is the same line environment_driver.gd draws
## and for the same reason: forcing a storm for a story beat must stay ONE call to
## Weather.force(), not an edit to a presentation node that a designer will never find.
##
## HOW AN AREA USES IT
## One node under the area root, optionally pointed at a SurfaceWetness. Nothing else. An
## interior needs neither: AreaRoot sets Weather.sheltered and every weight here goes to zero.

## Per weather kind, how heavy each emitter runs: x rain, y snow, z blown motes. One table
## rather than three functions, so "what does a storm look like" is a single readable row and
## a new kind cannot be half-wired.
const MIX: Dictionary[int, Vector3] = {
	GameEnums.WeatherKind.CLEAR: Vector3(0.00, 0.00, 0.00),
	GameEnums.WeatherKind.CLOUDY: Vector3(0.00, 0.00, 0.10),
	GameEnums.WeatherKind.OVERCAST: Vector3(0.00, 0.00, 0.18),
	GameEnums.WeatherKind.RAIN: Vector3(0.60, 0.00, 0.16),
	GameEnums.WeatherKind.STORM: Vector3(1.00, 0.00, 0.72),
	GameEnums.WeatherKind.FOG: Vector3(0.00, 0.00, 0.04),
	GameEnums.WeatherKind.SNOW: Vector3(0.00, 1.00, 0.26),
	GameEnums.WeatherKind.WIND: Vector3(0.00, 0.00, 1.00),
}

## Localization key of the toast shown when the sky turns. Never a literal — the weather name
## substituted into it is itself a key, computed from the enum the same way `verb.*` is.
const TURNS_KEY: String = "notify.weather.turns"
const NAME_KEY: String = "weather.%s"
## Ambience sits under music and never leads. This is the ceiling on both layers.
const AMBIENCE_GAIN: float = 0.7

## Half-size of the box weather falls out of, centred above the player.
@export var extents: Vector3 = Precipitation.DEFAULT_EXTENTS
## How far above the player the box sits. Rain has to start above the tallest thing on screen.
@export var height_offset: float = 5.0
## Optional. The surfaces that get wet; usually a SurfaceWetness under Terrain.
@export var surfaces: NodePath = NodePath()
## Toast when the sky turns. Off for an area where the change is a scripted beat.
@export var announce_changes: bool = true

var _emitters: Dictionary[int, Precipitation] = {}
var _wet: WetnessModel = WetnessModel.new()
var _surfaces: SurfaceWetness = null


func _ready() -> void:
	# Spelled out rather than looped over an array literal: an untyped literal would have to
	# be cast back to the enum for every call, and CLEAR through FOG have nothing to emit.
	_add(GameEnums.WeatherKind.RAIN)
	_add(GameEnums.WeatherKind.SNOW)
	_add(GameEnums.WeatherKind.WIND)
	_surfaces = get_node_or_null(surfaces) as SurfaceWetness
	if not surfaces.is_empty() and _surfaces == null:
		Log.warn("world", "WeatherVisuals found no SurfaceWetness at '%s'" % surfaces)
	Events.weather_changing.connect(_on_weather_changing)
	drive(0.0)
	Log.info("world", "Weather visuals ready: %d emitter(s), wet surfaces=%s" % [
		_emitters.size(), str(_surfaces != null),
	])


func _process(delta: float) -> void:
	_follow()
	drive(delta)


## What each emitter should be doing this frame, cross-faded across an in-flight change.
## Sheltered wins outright: AreaRoot sets it for interiors and caves, and the point of it is
## that the storm keeps running in the state while none of it reaches you.
func mix_now() -> Vector3:
	if Weather.sheltered:
		return Vector3.ZERO
	return mix_for(Weather.current()).lerp(mix_for(Weather.target()), Weather.blend())


static func mix_for(kind: GameEnums.WeatherKind) -> Vector3:
	if not MIX.has(kind):
		return Vector3.ZERO
	var found: Vector3 = MIX[kind]
	return found


## Current wetness, 0 dry to 1 soaked. Read by the assertions and by the capture flags.
func wetness() -> float:
	return _wet.wetness()


## Force a wetness, for a capture that has to photograph one moment of a twenty-six second
## dry-out, and for entering an area that is already in a downpour.
func soak(value: float) -> void:
	_wet.reset_to(value)
	drive(0.0)


## Run the wetness forward without frames, under whatever the weather currently is. This is
## how "and dries out" is photographed without waiting half a minute per screenshot.
func evaporate(seconds: float) -> float:
	var result: float = _wet.advance(seconds, _soak_target(mix_now()))
	drive(0.0)
	return result


func emitter(kind: GameEnums.WeatherKind) -> Precipitation:
	if not _emitters.has(kind):
		return null
	return _emitters[kind]


func _add(kind: GameEnums.WeatherKind) -> void:
	var built: Precipitation = Precipitation.make(kind, extents)
	if built == null:
		return
	add_child(built)
	_emitters[kind] = built


## The single place the published state becomes a picture. Everything downstream of here is
## told what to do; nothing downstream asks Weather anything.
##
## PUBLIC ON PURPOSE. Gotcha 10: `TestCase.run()` is synchronous, so no assertion can wait for
## a `_process` frame. A private `_drive` would mean the only way to test that a storm reaches
## the emitters is to look at a screenshot, and screenshots do not fail a build.
func drive(delta: float) -> void:
	var mix: Vector3 = mix_now()
	_set_weight(GameEnums.WeatherKind.RAIN, mix.x)
	_set_weight(GameEnums.WeatherKind.SNOW, mix.y)
	_set_weight(GameEnums.WeatherKind.WIND, mix.z)

	var soaked: float = _wet.step(delta, _soak_target(mix))
	if _surfaces != null:
		_surfaces.apply(soaked)

	if Audio.beds != null:
		Audio.beds.set_level(&"rain", mix.x * AMBIENCE_GAIN)
		Audio.beds.set_level(&"wind", maxf(mix.z, mix.y * 0.5) * AMBIENCE_GAIN)


## How wet the world is trying to get. Gated on Weather.is_wet() rather than on the rain
## weight alone, because is_wet() is the published contract for "the player should be getting
## wet" and footsteps and interactions are meant to key off the same answer.
func _soak_target(mix: Vector3) -> float:
	return mix.x if Weather.is_wet() else 0.0


func _set_weight(kind: GameEnums.WeatherKind, weight: float) -> void:
	var found: Precipitation = emitter(kind)
	if found != null:
		found.set_weight(weight)


## Keep the box over the player. World-space particles mean moving it only changes where the
## NEXT drop spawns, so nothing already falling is dragged sideways.
func _follow() -> void:
	if Director.player == null or not is_instance_valid(Director.player):
		return
	var who: Node3D = Director.player
	var at: Vector3 = who.global_position
	global_position = Vector3(at.x, at.y + height_offset, at.z)


## The sky turning is a fact about the world, so it is announced the way every other fact is:
## a localization key on the bus. Weather does not do this itself — it must not know a screen
## exists — which is why the emit lives in the presentation node that already listens.
func _on_weather_changing(to: GameEnums.WeatherKind, _seconds: float) -> void:
	if not announce_changes or Weather.sheltered:
		return
	var name_key: String = NAME_KEY % Weather.kind_name(to).to_lower()
	Events.notify_requested.emit(TURNS_KEY, 3.0, {"weather": tr(name_key)})
