extends TestCase
## A wander target is clamped to somewhere a walk can end, never handed out raw.
##
## THE DEFECT, MEASURED: a random offset from a post landed on a riser the body cannot climb, and
## `NpcBrain._check_reachable()` logged an ERROR for a destination nobody authored, in one
## windowed capture of six. `NpcBrain.reachable_point()` is the pure seam under `_tick_wander`.
##
## A HAND-BUILT MAP, NOT A BAKE. `TestCase.run()` is synchronous and a bake needs frames, so the
## map is two polygons placed by hand and synchronised with `map_force_update`: a floor, and an
## island beside it that no edge joins, the shape a dais with a high riser bakes to.
## **In 4.7 `map_force_update` does NOTHING while async iterations are on**, which is the
## default for a map and a region alike: the iteration id stays 0 and every query answers empty,
## so `reachable_point` would return `from` and the island case would pass for the wrong reason.
## Both are switched off here, and the first assertion is that the map synchronised at all.
##
## OWNS: assertions about `NpcBrain.reachable_point`.
## MUST NOT: name demo content, or bake a navmesh.

## How close two points must be to count as the same, in metres.
const NEAR: float = 0.05

var _map: RID
var _region: RID
var _empty_map: RID


func run() -> void:
	plan(7)
	_set_up()
	_open_floor_is_left_alone()
	_a_target_on_the_island_is_pulled_back()
	_a_target_off_the_mesh_is_pulled_in()
	_no_map_means_stand_still()
	_tear_down()


func _set_up() -> void:
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4),
		Vector3(6, 0.4, 0), Vector3(8, 0.4, 0), Vector3(8, 0.4, 2), Vector3(6, 0.4, 2),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	mesh.add_polygon(PackedInt32Array([4, 5, 6, 7]))
	_map = _synchronous_map()
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(_region, false)
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	NavigationServer3D.map_force_update(_map)
	_empty_map = _synchronous_map()
	NavigationServer3D.map_force_update(_empty_map)
	equal("the hand-built map synchronised", NavigationServer3D.map_get_iteration_id(_map) > 0, true)


func _synchronous_map() -> RID:
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.map_set_active(map, true)
	return map


func _open_floor_is_left_alone() -> void:
	var wish := Vector3(2.5, 0, 2.5)
	var got: Vector3 = NpcBrain.reachable_point(_map, Vector3(1, 0, 1), wish, 1)
	equal("a target on open floor is kept", got.distance_to(wish) < NEAR, true)


## THE HEADLINE. The island is navmesh, so a closest-point query alone would happily answer a
## point on it; only the end of an actual path from the NPC is somewhere it can walk to.
func _a_target_on_the_island_is_pulled_back() -> void:
	var from := Vector3(1, 0, 1)
	var wish := Vector3(7, 0.4, 1)
	var got: Vector3 = NpcBrain.reachable_point(_map, from, wish, 1)
	equal("a target on an unjoined island is moved", got.distance_to(wish) > 0.5, true)
	equal("onto the floor the NPC stands on", got.x <= 4.0 + NEAR, true)
	var walk: PackedVector3Array = NavigationServer3D.map_get_path(_map, from, got, true, 1)
	var ends: Vector3 = walk[walk.size() - 1] if not walk.is_empty() else from
	equal("and a walk there ends on it", ends.distance_to(got) < NEAR, true)


func _a_target_off_the_mesh_is_pulled_in() -> void:
	var got: Vector3 = NpcBrain.reachable_point(_map, Vector3(1, 0, 1), Vector3(2, 0, 9), 1)
	equal("a target beyond the edge is pulled in", got.z <= 4.0 + NEAR, true)


func _no_map_means_stand_still() -> void:
	var from := Vector3(1, 0, 1)
	var got: Vector3 = NpcBrain.reachable_point(_empty_map, from, Vector3(3, 0, 3), 1)
	equal("with no navmesh the NPC stays where it is", got, from)


func _tear_down() -> void:
	NavigationServer3D.free_rid(_region)
	NavigationServer3D.free_rid(_map)
	NavigationServer3D.free_rid(_empty_map)
