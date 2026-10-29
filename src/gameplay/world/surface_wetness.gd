class_name SurfaceWetness
extends Node3D
## Makes the ground look rained on: darker, and shiny where the light catches it.
##
## WHY IT DUPLICATES EVERY MATERIAL IT TOUCHES
## The terrain materials are sub-resources of the area scene, and a sub-resource is SHARED
## between every instantiation of that scene. Writing roughness straight onto one would leave
## the courtyard wet after the area was unloaded and reloaded on a clear day — the change
## would outlive the rain that caused it, and worse, would outlive the area itself and follow
## the player into the next one that happened to use the same material. Each mesh gets its own
## duplicate as a surface override instead, so the wetness dies with the area.
##
## WHY DARKEN AND SHINE, RATHER THAN A PUDDLE TEXTURE
## Wet ground is not a decal, it is a change in how the surface answers light: it absorbs more
## and scatters less. Dropping roughness and lifting specular reproduces that on any material,
## including the fiftieth one nobody has authored yet — a puddle texture would need art per
## surface, which is exactly the dependency this project is refusing to take on.
##
## OWNS: the overridden materials and the dry baseline it has to return them to.
## MUST NOT: read Weather or the clock. It is handed a 0..1 and paints it. WeatherVisuals owns
## the decision; keeping it out of here is what lets a cutscene soak one courtyard on demand.

## How far towards black a fully soaked surface is pulled.
const MAX_DARKEN: float = 0.34
## Roughness at full soak. Low enough to catch a hard specular from the sun and the lanterns.
const WET_ROUGHNESS: float = 0.09
const WET_SPECULAR: float = 0.85
## A clearcoat IS a wet film: a thin smooth layer of something else sitting on the surface.
## Darkening alone came back reading as "in shadow" rather than "wet" in the first captures,
## because a low roughness only shows where the sun's mirror angle happens to point — and on a
## flat courtyard under a fixed camera, it mostly does not. A coat reflects the sky instead,
## which is visible from any angle and is the cue that actually says rain.
const WET_CLEARCOAT: float = 0.85
const WET_CLEARCOAT_ROUGHNESS: float = 0.03

## Subtrees to make wet. Empty means "this node's parent", which is the sane default for a
## SurfaceWetness dropped straight under Terrain.
@export var roots: Array[NodePath] = []

var _surfaces: Array[Dictionary] = []
var _applied: float = -1.0
var _wanted: float = 0.0


func _ready() -> void:
	for path: NodePath in _search_roots():
		var root: Node = get_node_or_null(path)
		if root == null:
			Log.warn("world", "SurfaceWetness found nothing at '%s'" % path)
			continue
		_collect(root)
	# Paint whatever was asked for BEFORE this ran. WeatherVisuals sits under Environment and
	# this node under Terrain, so it is readied first and drives a value at a list that is
	# still empty. Without this line, arriving in an area mid-downpour shows a dry courtyard
	# until the wetness happens to move — and it does not move once it has reached its target.
	_paint(_wanted)
	Log.info("world", "SurfaceWetness governs %d surface(s)" % _surfaces.size())


## Paint a wetness of 0.0 to 1.0. Cheap to call every frame: a value that has not moved
## perceptibly since the last call does nothing at all.
func apply(wetness: float) -> void:
	var value: float = clampf(wetness, 0.0, 1.0)
	_wanted = value
	if absf(value - _applied) < 0.002:
		return
	_paint(value)


func _paint(value: float) -> void:
	_applied = value
	for surface: Dictionary in _surfaces:
		var material: StandardMaterial3D = _material_of(surface)
		if material == null:
			continue
		material.albedo_color = DictRead.get_color(surface, "albedo").darkened(MAX_DARKEN * value)
		material.roughness = lerpf(DictRead.get_float(surface, "roughness"), WET_ROUGHNESS, value)
		material.metallic_specular = lerpf(DictRead.get_float(surface, "specular"), WET_SPECULAR, value)
		# Off entirely when dry, rather than left enabled at zero strength: an enabled coat is
		# a whole extra term in the shader, and a dry courtyard should cost what it always did.
		material.clearcoat_enabled = value > 0.01 or DictRead.get_bool(surface, "coated")
		material.clearcoat = lerpf(DictRead.get_float(surface, "coat"), WET_CLEARCOAT, value)
		material.clearcoat_roughness = lerpf(
			DictRead.get_float(surface, "coat_rough"), WET_CLEARCOAT_ROUGHNESS, value
		)


## What was last painted. The assertions read this rather than a material, because a headless
## run shades nothing and a colour read back from one would prove only that a setter ran.
func applied() -> float:
	return maxf(0.0, _applied)


func surface_count() -> int:
	return _surfaces.size()


func _search_roots() -> Array[NodePath]:
	if not roots.is_empty():
		return roots
	var fallback: Array[NodePath] = []
	if get_parent() != null:
		fallback.append(^"..")
	return fallback


func _collect(node: Node) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null:
		_adopt(mesh_instance)
	for child: Node in node.get_children():
		_collect(child)


## Take a private copy of whatever material the surface is already using and record its dry
## values, so drying out returns to what the author set rather than to an engine default.
func _adopt(mesh_instance: MeshInstance3D) -> void:
	var active: Material = mesh_instance.get_active_material(0)
	var standard: StandardMaterial3D = active as StandardMaterial3D
	if standard == null:
		return
	var copy: StandardMaterial3D = standard.duplicate() as StandardMaterial3D
	mesh_instance.set_surface_override_material(0, copy)
	_surfaces.append({
		"material": copy,
		"albedo": copy.albedo_color,
		"roughness": copy.roughness,
		"specular": copy.metallic_specular,
		"coated": copy.clearcoat_enabled,
		"coat": copy.clearcoat,
		"coat_rough": copy.clearcoat_roughness,
	})


func _material_of(surface: Dictionary) -> StandardMaterial3D:
	var held: Variant = surface.get("material")
	return held as StandardMaterial3D
