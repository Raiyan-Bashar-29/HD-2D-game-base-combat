class_name AreaRoot
extends Node3D
## The root of every area scene. One per area, and the contract Director loads against.
##
## WHY EVERY AREA HAS THE SAME ROOT SCRIPT
## Areas differ in content, not in shape. Giving them one root type means Director never
## needs a per-area special case, an area can be validated automatically, and adding the
## fiftieth area requires no code at all. The moment an area needs bespoke behaviour, it
## gets a child node with its own script — the root stays generic.
##
## REQUIRED CHILD STRUCTURE (the validator checks this):
##     AreaRoot
##     |- Environment/         WorldEnvironment, sun, moon, EnvironmentDriver
##     |- Terrain/             ground and building geometry, static collision
##     |- Props/               non-interactive scenery
##     |- Interactables/       anything the player can act on
##     |- Actors/              NPCs
##     |- Spawns/              Marker3D per entry point, named to match travel requests
##     |- Triggers/            Area3D volumes: transitions, plot triggers, audio zones
##     |- Camera/              the HD2DCameraRig for this area
##     |- Navigation/          NavigationRegion3D, baked from this area's own geometry on entry
##     |- Waypoints/           Marker3D per named place an NPC can be sent to
##
## OWNS: the area's identity, its weather rules, its audio beds, and baking its navmesh.
## MUST NOT: contain gameplay logic. It announces itself and configures ambience.

## Must match the folder and file name: scenes/areas/<id>/<id>.tscn
@export var area_id: StringName = &""
## Localization key for the name shown on screen when entering. Never raw text.
@export var display_name_key: String = ""

@export_group("Weather")
## Which kinds may occur here. Empty means anything.
@export var allowed_weather: Array[GameEnums.WeatherKind] = []
## Interiors and caves: weather keeps running but is not visible or felt.
@export var sheltered: bool = false
## Forced on entry, for a story beat that needs a specific sky.
@export var force_weather_on_entry: bool = false
@export var forced_weather: GameEnums.WeatherKind = GameEnums.WeatherKind.CLEAR

@export_group("Audio")
@export var music: AudioStream = null
@export var ambience: AudioStream = null

@export_group("Save")
## Flags for this area are namespaced under this prefix, so an area's world state can be
## found, dumped or cleared as a group.
@export var flag_prefix: String = ""


func _ready() -> void:
	if area_id == &"":
		Log.error("area", "%s has no area_id set — Director cannot match spawns to it" % name)

	Weather.sheltered = sheltered
	Weather.set_allowed(allowed_weather)
	if force_weather_on_entry:
		Weather.force(forced_weather)

	Audio.play_music(music)
	Audio.play_ambience(ambience)

	_bake_navigation()

	Log.info("area", "Area '%s' ready (%d spawns, %d interactables, %d waypoints)" % [
		area_id, _count_in(^"Spawns"), _count_in(^"Interactables"), _count_in(^"Waypoints"),
	])


## Namespace for this area's flags. Use it so two areas cannot collide on a flag name:
##     Flags.set_flag(area.flag_key("gate_open"), true)
func flag_key(local_name: String) -> StringName:
	var prefix: String = flag_prefix if flag_prefix != "" else "area/%s" % area_id
	return StringName("%s/%s" % [prefix, local_name])


func _count_in(group: NodePath) -> int:
	var node: Node = get_node_or_null(group)
	return node.get_child_count() if node != null else 0


## Bake the navmesh from the area's own geometry, here, at load.
##
## WHY AT RUNTIME AND NOT CHECKED IN. A baked NavigationMesh committed beside the scene goes
## stale the moment someone moves a wall, and a stale navmesh fails SILENTLY: NPCs walk through
## the new geometry or refuse to path around it, and nothing errors. Baking from the geometry
## that is actually present cannot disagree with it. The cost is milliseconds per area entry,
## paid where nobody can see it — Director holds the curtain for WARM_UP_FRAMES after this runs,
## so the bake and the shader compile hide behind the same black screen.
##
## SYNCHRONOUS on purpose. The threaded variant returns before the map is usable, and every NPC
## in the area would then ask for a path against an empty navmesh and conclude it had already
## arrived. NpcBrain still waits two physics frames for the map to synchronise.
func _bake_navigation() -> void:
	var region: NavigationRegion3D = get_node_or_null(^"Navigation/Region") as NavigationRegion3D
	if region == null:
		return
	if region.navigation_mesh == null:
		Log.error("area", "%s has a Navigation/Region with no NavigationMesh resource" % area_id)
		return
	var started: int = Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	# The POLYGON COUNT, not just the duration. A bake that produces nothing takes no time at
	# all, so "baked in 0ms" on its own is exactly what a silently empty navmesh looks like -
	# and an empty navmesh means every NPC concludes it has already arrived, everywhere.
	var polygons: int = region.navigation_mesh.get_polygon_count()
	if polygons == 0:
		Log.error("area", "Navmesh for '%s' baked EMPTY; nothing can path here" % area_id)
		return
	Log.info("area", "Navmesh for '%s' baked: %d polygons in %dms" % [
		area_id, polygons, Time.get_ticks_msec() - started,
	])
