class_name EnvironmentDriver
extends Node
## Turns the world clock and the weather into real lighting. This is where "time of day"
## stops being a number and starts being something you can see.
##
## OWNS: the WorldEnvironment's values, the sun and moon transforms, and the HD-2D post
## stack (glow, tonemap, fog).
## MUST NOT: decide what time it is, or what the weather is. It reads Clock and Weather and
## renders their consequences. That separation is why time can be fast-forwarded by a bed,
## or forced by a cutscene, without touching this file.
##
## WHY IT INTERPOLATES EVERY FRAME rather than on the hour: stepping light values once a
## minute is visible as a flicker. Continuous interpolation across a keyframe table costs a
## handful of lerps per frame and looks like an actual sunrise.
##
## THE HD-2D POST STACK, applied once at startup:
##   AgX tonemapping        - rolls off highlights gently, so a bright sky keeps colour
##                            instead of clipping to white. This is a large part of why
##                            modern HD-2D looks filmic rather than flat.
##   Generous glow          - the signature bloom. Threshold kept low so lanterns and
##                            bright sky bleed, but not so low that everything hazes.
##   Volumetric fog         - gives godrays and depth between layers of scenery, which is
##                            what separates foreground, midground and background.
##   No SSAO, no SDFGI      - both are expensive and largely wasted on billboarded sprites
##                            and simple geometry. Revisit only if the look demands it.
##
## SINCE T3.2 EVERY NUMBER IN THAT STACK IS AN @export, not a literal. The descriptions above
## say what each part is FOR; the defaults say what this template ships; and an area that wants
## a different look sets the value in its own scene rather than editing this file. See the
## "Post stack" group below, and docs/ART_CONTRACT.md for the consumer-facing form.

## A single point in the day. `t` is Clock.day_fraction(): 0.0 and 1.0 are midnight.
const KEYFRAMES: Array[Dictionary] = [
	{
		"t": 0.00, "sun": Color(0.36, 0.44, 0.68), "sun_e": 0.06,
		"amb": Color(0.12, 0.16, 0.28), "amb_e": 0.25,
		"fog": Color(0.10, 0.13, 0.22), "fog_d": 0.012,
	},
	{
		"t": 0.21, "sun": Color(0.56, 0.46, 0.58), "sun_e": 0.18,
		"amb": Color(0.22, 0.22, 0.34), "amb_e": 0.34,
		"fog": Color(0.22, 0.20, 0.28), "fog_d": 0.020,
	},
	{
		"t": 0.27, "sun": Color(1.00, 0.62, 0.38), "sun_e": 1.10,
		"amb": Color(0.45, 0.38, 0.42), "amb_e": 0.55,
		"fog": Color(0.62, 0.45, 0.42), "fog_d": 0.028,
	},
	{
		"t": 0.36, "sun": Color(1.00, 0.88, 0.72), "sun_e": 1.50,
		"amb": Color(0.55, 0.58, 0.62), "amb_e": 0.60,
		"fog": Color(0.58, 0.62, 0.68), "fog_d": 0.013,
	},
	{
		"t": 0.50, "sun": Color(1.00, 0.97, 0.90), "sun_e": 1.90,
		"amb": Color(0.62, 0.66, 0.72), "amb_e": 0.70,
		"fog": Color(0.62, 0.70, 0.80), "fog_d": 0.008,
	},
	{
		"t": 0.66, "sun": Color(1.00, 0.90, 0.74), "sun_e": 1.60,
		"amb": Color(0.58, 0.58, 0.60), "amb_e": 0.62,
		"fog": Color(0.62, 0.62, 0.68), "fog_d": 0.012,
	},
	{
		"t": 0.76, "sun": Color(1.00, 0.52, 0.30), "sun_e": 1.00,
		"amb": Color(0.42, 0.34, 0.40), "amb_e": 0.50,
		"fog": Color(0.58, 0.38, 0.36), "fog_d": 0.030,
	},
	{
		"t": 0.84, "sun": Color(0.56, 0.42, 0.62), "sun_e": 0.26,
		"amb": Color(0.24, 0.24, 0.38), "amb_e": 0.35,
		"fog": Color(0.26, 0.24, 0.34), "fog_d": 0.022,
	},
]

## Peak sun elevation at noon. Lower than 90 so shadows always have some length, which
## reads better in a fixed-camera game than a sun directly overhead.
const MAX_ELEVATION: float = 68.0
## How much heavy weather suppresses direct sun and lifts fog.
const WEATHER_SUN_DAMPING: float = 0.75
const WEATHER_FOG_GAIN: float = 4.0

@export var world_environment: WorldEnvironment = null
@export var sun: DirectionalLight3D = null
## Optional. If present it takes over lighting once the sun is below the horizon.
@export var moon: DirectionalLight3D = null
## Set false for interiors, which should not follow the outdoor sun.
@export var follow_clock: bool = true

@export_group("Interior")
## Applied ONCE, instead of the clock, when follow_clock is false.
##
## WHY THIS GROUP HAD TO EXIST. Before it, follow_clock=false only stopped the driver
## UPDATING — _ready still called _apply_now once, so an interior inherited whatever hour it
## happened to be entered at, and the sun was hidden outright below the horizon. The first
## interior ever built was therefore pitch black at 02:30 and fine at noon, from the same
## scene file. An interior needs its own light, not a frozen sample of someone else's.
@export var interior_ambient: Color = Color(0.30, 0.24, 0.22)
@export_range(0.0, 4.0, 0.05) var interior_ambient_energy: float = 0.85
@export var interior_fog: Color = Color(0.26, 0.19, 0.16)
@export_range(0.0, 0.2, 0.001) var interior_fog_density: float = 0.010


## The settings this driver obeys, named on the consumer so a setting nobody reads has nowhere
## to be written down.
const BLOOM_SETTING: String = "video/bloom"

@export_group("Post stack")
## THE HD-2D LOOK, AS DATA (T3.2). Every one of these was a literal inside _build_post_stack, so
## re-tuning the look of a game built on this template meant editing engine code — which
## docs/AUTHORING.md tells an author they never do. They are @exports on THIS node rather than a
## resource, and per AREA rather than per project, for the reason the header's PER-AREA note
## gives: this driver already lives in the area scene, and the Interior group above already
## varies per area. A game that wants one look everywhere authors its areas from one copy; a
## game that wants a bright market and a smoky cellar has the seam without asking for it.
##
## The defaults below ARE the values T2.1 shipped, to the digit, so no area that leaves them
## alone renders differently. tests/unit/area_look_test.gd fails if a number grows back here.
@export_range(0.0, 4.0, 0.01) var tonemap_exposure: float = 1.0
@export var glow_enabled: bool = true
@export_range(0.0, 4.0, 0.01) var glow_intensity: float = 0.9
@export_range(0.0, 2.0, 0.01) var glow_strength: float = 1.1
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.15
## Above this luminance a surface bleeds. Low enough for lanterns, high enough not to haze.
@export_range(0.0, 4.0, 0.01) var glow_hdr_threshold: float = 0.92
@export_range(0.0, 4.0, 0.01) var glow_hdr_scale: float = 2.0
@export var fog_enabled: bool = true
@export var fog_depth_begin: float = 30.0
@export var fog_depth_end: float = 160.0
@export_range(0.0, 1.0, 0.01) var fog_sky_affect: float = 0.35
## The godrays. Expensive, and the largest single cost in this stack on a weak GPU.
@export var volumetric_fog_enabled: bool = true
@export_range(0.0, 0.1, 0.0001) var volumetric_fog_density: float = 0.005
@export var volumetric_fog_length: float = 96.0
@export_range(-0.9, 0.9, 0.01) var volumetric_fog_anisotropy: float = 0.3
@export_range(0.0, 1.0, 0.01) var volumetric_fog_gi_inject: float = 0.0

@export_group("Expensive effects, off by default")
## All four are OFF and the header says why: they are largely wasted on billboarded sprites and
## simple geometry. They are exports rather than hard-coded `false` because "revisit only if the
## look demands it" is a decision for the game, not for the template — and a value a consuming
## game cannot reach is not a seam, it is an opinion.
@export var ssao_enabled: bool = false
@export var sdfgi_enabled: bool = false
@export var ssil_enabled: bool = false
@export var ssr_enabled: bool = false
var _environment: Environment = null


func _ready() -> void:
	_discover_siblings()
	if world_environment == null:
		Log.error("world", "EnvironmentDriver has no WorldEnvironment — lighting will not update")
		return

	_environment = world_environment.environment
	if _environment == null:
		_environment = Environment.new()
		world_environment.environment = _environment
	_build_post_stack()
	if follow_clock:
		_apply_now()
	else:
		_apply_interior()
	Events.setting_changed.connect(_on_setting_changed)
	Log.info("world", "Environment driver ready (follow_clock=%s)" % str(follow_clock))


func _process(_delta: float) -> void:
	if follow_clock and _environment != null:
		_apply_now()


## The one-time HD-2D look configuration. Every VALUE here is an @export above; what stays in
## code is the STRUCTURE — which tonemapper, which fog mode, that ambient comes from a colour —
## because those are what the rest of this file assumes rather than what an area tunes.
func _build_post_stack() -> void:
	_environment.background_mode = Environment.BG_SKY
	if _environment.sky == null:
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		_environment.sky = sky

	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = tonemap_exposure

	# THE PLAYER'S VETO OVER THE AREA AUTHOR'S DEFAULT, on `HD2DCameraRig`'s reasoning: an area
	# that wants no glow keeps none, and a player who turned bloom off gets none anywhere. This
	# is where `video/bloom` had to land - the Environment is this node's, and nothing else may
	# touch it, so no other file could have consumed that setting.
	_environment.glow_enabled = glow_enabled and Settings.get_bool(BLOOM_SETTING)
	_environment.glow_intensity = glow_intensity
	_environment.glow_strength = glow_strength
	_environment.glow_bloom = glow_bloom
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.glow_hdr_threshold = glow_hdr_threshold
	_environment.glow_hdr_scale = glow_hdr_scale

	_environment.fog_enabled = fog_enabled
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_environment.fog_depth_begin = fog_depth_begin
	_environment.fog_depth_end = fog_depth_end
	_environment.fog_sky_affect = fog_sky_affect

	_environment.volumetric_fog_enabled = volumetric_fog_enabled
	_environment.volumetric_fog_density = volumetric_fog_density
	_environment.volumetric_fog_length = volumetric_fog_length
	_environment.volumetric_fog_gi_inject = volumetric_fog_gi_inject
	_environment.volumetric_fog_anisotropy = volumetric_fog_anisotropy

	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	# Off by default, and see the group's note for why they are exports rather than literals.
	_environment.ssao_enabled = ssao_enabled
	_environment.sdfgi_enabled = sdfgi_enabled
	_environment.ssil_enabled = ssil_enabled
	_environment.ssr_enabled = ssr_enabled


func _apply_now() -> void:
	var t: float = Clock.day_fraction()
	var frame: Dictionary = _sample(t)
	var wetness: float = Weather.intensity()

	var sun_energy: float = DictRead.get_float(frame, "sun_e") * (1.0 - wetness * WEATHER_SUN_DAMPING)
	var elevation: float = sin((t - 0.25) * TAU) * MAX_ELEVATION
	var azimuth: float = t * 360.0 - 90.0

	if sun != null:
		sun.light_color = DictRead.get_color(frame, "sun")
		sun.light_energy = maxf(0.0, sun_energy)
		sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
		# Hide the sun entirely below the horizon so it cannot light the scene from beneath.
		sun.visible = elevation > -2.0

	if moon != null:
		moon.visible = elevation <= -2.0
		moon.rotation_degrees = Vector3(-(-elevation), azimuth + 180.0, 0.0)

	_environment.ambient_light_color = DictRead.get_color(frame, "amb")
	_environment.ambient_light_energy = DictRead.get_float(frame, "amb_e")

	var fog_colour: Color = DictRead.get_color(frame, "fog")
	_environment.fog_light_color = fog_colour
	_environment.fog_density = DictRead.get_float(frame, "fog_d") * (1.0 + wetness * WEATHER_FOG_GAIN)
	_environment.volumetric_fog_albedo = fog_colour

	var sky_material: ProceduralSkyMaterial = _environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material != null:
		sky_material.sky_top_color = fog_colour.darkened(0.35)
		sky_material.sky_horizon_color = fog_colour.lightened(0.15)
		sky_material.ground_horizon_color = fog_colour.lightened(0.05)
		sky_material.ground_bottom_color = fog_colour.darkened(0.5)


## An interior, lit once and then left alone. It deliberately does NOT touch the sun: indoors
## that light is an authored fill at whatever angle and energy the scene set, and the outdoor
## code path would swing it round the sky and hide it below the horizon at night.
func _apply_interior() -> void:
	_environment.ambient_light_color = interior_ambient
	_environment.ambient_light_energy = interior_ambient_energy
	_environment.fog_light_color = interior_fog
	_environment.fog_density = interior_fog_density
	_environment.volumetric_fog_albedo = interior_fog
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = interior_fog.darkened(0.6)


## Blend between the two keyframes surrounding `t`, wrapping around midnight.
func _sample(t: float) -> Dictionary:
	var wrapped: float = fposmod(t, 1.0)
	var count: int = KEYFRAMES.size()
	var next_index: int = 0
	for i: int in count:
		if DictRead.get_float(KEYFRAMES[i], "t") > wrapped:
			next_index = i
			break
	var previous_index: int = posmod(next_index - 1, count)

	var previous: Dictionary = KEYFRAMES[previous_index]
	var upcoming: Dictionary = KEYFRAMES[next_index]
	var from_t: float = DictRead.get_float(previous, "t")
	var to_t: float = DictRead.get_float(upcoming, "t")
	# Crossing midnight means the span wraps past 1.0.
	if to_t <= from_t:
		to_t += 1.0
		if wrapped < from_t:
			wrapped += 1.0
	var span: float = maxf(0.0001, to_t - from_t)
	var mix: float = clampf((wrapped - from_t) / span, 0.0, 1.0)

	return {
		"sun": DictRead.get_color(previous, "sun").lerp(DictRead.get_color(upcoming, "sun"), mix),
		"sun_e": lerpf(DictRead.get_float(previous, "sun_e"), DictRead.get_float(upcoming, "sun_e"), mix),
		"amb": DictRead.get_color(previous, "amb").lerp(DictRead.get_color(upcoming, "amb"), mix),
		"amb_e": lerpf(DictRead.get_float(previous, "amb_e"), DictRead.get_float(upcoming, "amb_e"), mix),
		"fog": DictRead.get_color(previous, "fog").lerp(DictRead.get_color(upcoming, "fog"), mix),
		"fog_d": lerpf(DictRead.get_float(previous, "fog_d"), DictRead.get_float(upcoming, "fog_d"), mix),
	}


## Find the WorldEnvironment, sun and moon among our siblings when they were not wired in
## the scene. A forgotten @export used to leave the sun frozen at its default energy, which
## looks like "the day/night cycle does not work" and wastes an afternoon. Now it is found
## automatically, and says so.
func _discover_siblings() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	if world_environment == null:
		world_environment = host.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
		if world_environment != null:
			Log.warn("world", "WorldEnvironment was not wired in the scene; found by name instead")
	if sun == null:
		sun = host.get_node_or_null(^"Sun") as DirectionalLight3D
		if sun == null:
			Log.warn("world", "No sun found: the day/night cycle will not light this area")
		else:
			Log.warn("world", "Sun was not wired in the scene; found by name instead")
	if moon == null:
		moon = host.get_node_or_null(^"Moon") as DirectionalLight3D


## Only the glow line is re-applied, not the whole stack: `_build_post_stack` also rebuilds the
## sky, and doing that on a settings change would drop the procedural sky material mid-frame.
func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if _environment == null or "%s/%s" % [section, key] != BLOOM_SETTING:
		return
	_environment.glow_enabled = glow_enabled and Settings.get_bool(BLOOM_SETTING)
