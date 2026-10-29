class_name Precipitation
extends GPUParticles3D
## One weather emitter — rain, snow or blown motes — that builds itself entirely in code.
##
## WHY NOTHING HERE IS AUTHORED IN A SCENE OR A TEXTURE
## Art is deferred and stays deferred, so there is no rain sprite and there is not going to be
## one. The mesh is a quad, the flake is a generated radial gradient, and every curve is a
## number in this file. That also means the three emitters cannot quietly drift apart in an
## inspector: the shape of rain is decided once, here, and a fourth area inherits it free.
##
## WHY IT IS TOLD ITS WEIGHT INSTEAD OF READING Weather
## An emitter that polled the weather would be a second place the rules live, and the two
## would disagree the first time a cross-fade was half done. WeatherVisuals decides; this node
## renders. Same split as Weather and EnvironmentDriver, one level down.
##
## OWNS: its mesh, its process material, its draw material, and how heavy it is right now.
## MUST NOT: reference Weather, Clock or Director.

## Rain and snow fall from a box above the player rather than a dome around the camera: the
## HD-2D rig sees roughly twelve metres across, so a box this size is comfortably off-screen
## on every side and nothing is ever seen to spawn.
const DEFAULT_EXTENTS: Vector3 = Vector3(9.0, 5.0, 9.0)
## Below this the emitter is switched off rather than left drawing nothing, so a clear day
## costs no draw call at all.
const OFF_BELOW: float = 0.005

var _kind: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR


## Build an emitter for `kind`. Returns null for a kind that has nothing to draw — CLEAR,
## CLOUDY, OVERCAST and FOG are the environment driver's business, not this one's.
static func make(kind: GameEnums.WeatherKind, extents: Vector3 = DEFAULT_EXTENTS) -> Precipitation:
	var node := Precipitation.new()
	node._kind = kind
	node.name = "Emitter_%s" % GameEnums.WeatherKind.keys()[kind]
	# World space, not local: the box follows the player, and local coordinates would drag
	# every falling drop sideways with it as if the rain were nailed to the character.
	node.local_coords = false
	node.emitting = false
	node.amount_ratio = 0.0
	node.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	node.visibility_aabb = AABB(-extents * 2.0, extents * 4.0)
	match kind:
		GameEnums.WeatherKind.RAIN:
			node._build_rain(extents)
		GameEnums.WeatherKind.SNOW:
			node._build_snow(extents)
		GameEnums.WeatherKind.WIND:
			node._build_motes(extents)
		_:
			node.free()
			return null
	return node


func kind() -> GameEnums.WeatherKind:
	return _kind


## How heavy this emitter is, 0.0 off to 1.0 full. Driven every frame; `amount_ratio` exists
## precisely so a particle count can be faded without restarting the system.
func set_weight(weight: float) -> void:
	var was_on: bool = emitting
	amount_ratio = clampf(weight, 0.0, 1.0)
	emitting = amount_ratio > OFF_BELOW
	# Restart on the way ON, so `preprocess` runs again and the sky is already full rather
	# than filling from the top over the next second — which is the whole span of a capture.
	if emitting and not was_on and is_inside_tree():
		restart()


func weight() -> float:
	return amount_ratio if emitting else 0.0


func _build_rain(extents: Vector3) -> void:
	amount = 2200
	lifetime = 1.2
	# A streak has to lie along the direction it is falling or it reads as confetti.
	transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	# Start mid-storm rather than with an empty sky: a capture is taken thirty frames in.
	preprocess = 1.2
	var process: ParticleProcessMaterial = _process_material(extents)
	process.direction = Vector3(0.16, -1.0, 0.06)
	process.spread = 3.0
	process.gravity = Vector3(1.2, -30.0, 0.4)
	process.initial_velocity_min = 11.0
	process.initial_velocity_max = 15.0
	process.color = Color(0.74, 0.84, 0.98, 0.62)
	process_material = process
	# Measured, not guessed: the rig is 14 m out at a 27 degree vertical FOV, so one metre is
	# about 143 px at 960 wide. A 0.62 m streak came back 89 px long and read as a white stick.
	draw_pass_1 = _quad(Vector2(0.028, 0.38), null)


func _build_snow(extents: Vector3) -> void:
	amount = 900
	lifetime = 7.0
	transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	preprocess = 6.0
	var process: ParticleProcessMaterial = _process_material(extents)
	process.direction = Vector3(0.2, -1.0, 0.1)
	process.spread = 12.0
	process.gravity = Vector3(0.3, -1.5, 0.15)
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.1
	process.scale_min = 0.7
	process.scale_max = 1.6
	# Turbulence is what stops snow falling in visible vertical columns.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 2.4
	process.turbulence_noise_speed = Vector3(0.4, 0.0, 0.3)
	process.color = Color(1.0, 1.0, 1.0, 0.92)
	process_material = process
	draw_pass_1 = _quad(Vector2(0.11, 0.11), _flake())


func _build_motes(extents: Vector3) -> void:
	amount = 500
	lifetime = 3.4
	transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	preprocess = 3.0
	var process: ParticleProcessMaterial = _process_material(extents)
	process.direction = Vector3(1.0, 0.12, 0.25)
	process.spread = 22.0
	process.gravity = Vector3(2.0, -0.5, 0.4)
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 12.0
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.angular_velocity_min = -220.0
	process.angular_velocity_max = 220.0
	process.color = Color(0.80, 0.73, 0.50, 0.55)
	process_material = process
	draw_pass_1 = _quad(Vector2(0.09, 0.16), _flake())


func _process_material(extents: Vector3) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.particle_flag_disable_z = false
	return process


## Unshaded, alpha-blended, two-sided and shadowless. Weather is a screen effect wearing a
## mesh: lighting it would make rain vanish at night, which is when it matters most.
func _quad(size: Vector2, texture: Texture2D) -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	# BILLBOARD stays DISABLED on purpose: transform_align on the node above already orients
	# every particle, and the two mechanisms fight if both are on.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	if texture != null:
		material.albedo_texture = texture

	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


## A soft round dot, generated. Radial fill from opaque white to transparent, which is a
## snowflake and a dust mote at the distance this camera sits.
func _flake() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.75),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
