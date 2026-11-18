class_name CombatSight
extends RefCounted
## Walls between a hit and what it would hit (C9.12).
##
## IN PLAIN WORDS: a swing's box, a shot or a blast is an `Area3D`, and areas pass through walls.
## Before anything lands, the fight asks here whether a wall stands on the straight line from
## where the hit comes from to what it would hit. A wall is anything on `Layers.WORLD` or
## `Layers.SIGHT_BLOCKER`: terrain, buildings, a closed gate. Fighters, props on other layers,
## triggers and water never block.
## - `wall_between`: where the line first meets a wall, or `Vector3.INF` when it is clear.
## - `short_of`: how far along the line a body or a shot may go, stopping `MARGIN` short of the
##   wall, so a blink or a shot never ends inside one.
## - `last_floor`: the furthest point on a way with floor under it, so a blink never lands in the
##   air (C10.15).
## - `drop_ahead`: whether a step along a way would go over an edge (no floor within `STEP_DOWN`
##   below), so a fighter's own lunge or roll stops at a ledge. A knockback is not asked: being
##   knocked off is allowed, and `FallNet` deals with it.
##
## A swing's ray runs from `EYE` above the attacker's feet to `EYE` above the target's, so a wall
## lower than that (a step, a low crate) does not stop it. `aim` gives that point for any body.
##
## OWNS: what counts as a wall for a hit or an edge for a lunge, and the rays that find them.
## MUST NOT: decide what a hit does, or move anything itself.

## What stops a hit.
const MASK: int = Layers.WORLD | Layers.SIGHT_BLOCKER
## Metres above a body's feet a hit is aimed from and at: the middle of a fighter or a prop.
const EYE: float = 0.8
## Metres short of a wall a moved body or a new shot stops.
const MARGIN: float = 0.4
## Metres below a body's feet that still count as floor: a step down, not a drop.
const STEP_DOWN: float = 1.2
## Metres ahead of a body's feet the floor is looked for.
const LOOK_AHEAD: float = 0.6
## How far apart `last_floor` looks for floor, in metres.
const FLOOR_STEP: float = 0.5


## Where the line `from` to `to` first meets a wall, or `Vector3.INF` when it is clear (or
## `space` is not in a world).
static func wall_between(space: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Vector3:
	if space == null or not space.is_inside_tree() or from.is_equal_approx(to):
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	query.collide_with_areas = false
	var hit: Dictionary = space.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var at: Vector3 = hit.get("position", Vector3.INF)
	return at


## `to` when the line from `from` is clear; otherwise the point `MARGIN` back from the wall
## toward `from` (never past `from`).
static func short_of(space: Node3D, from: Vector3, to: Vector3) -> Vector3:
	var wall: Vector3 = wall_between(space, from, to)
	if not wall.is_finite():
		return to
	var back: Vector3 = from - wall
	if back.length() <= MARGIN:
		return from
	return wall + back.normalized() * MARGIN


## The point a hit is aimed from or at for `node`: `EYE` above where it stands.
static func aim(node: Node3D) -> Vector3:
	return node.global_position + Vector3.UP * EYE


## True when going along `way` from `body` would carry it over a drop: no floor within
## `STEP_DOWN` below the point `LOOK_AHEAD` in front of its feet.
static func drop_ahead(body: Node3D, way: Vector3) -> bool:
	var flat := Vector3(way.x, 0.0, way.z)
	if flat.length_squared() < 0.0001:
		return false
	var ahead: Vector3 = body.global_position + flat.normalized() * LOOK_AHEAD
	return not wall_between(body, ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * STEP_DOWN).is_finite()


## The furthest point from `from` toward `to` (both at the feet) with floor under it, looked for
## every `FLOOR_STEP` metres back from `to`; `from` itself when there is none (C10.15). A start
## with no floor under it (in the air, or an empty test space) is left alone: `to` comes back.
static func last_floor(space: Node3D, from: Vector3, to: Vector3) -> Vector3:
	if not _floor_under(space, from):
		return to
	var length: float = from.distance_to(to)
	var along: float = length
	while along > 0.0:
		var point: Vector3 = from.lerp(to, along / length)
		if _floor_under(space, point):
			return point
		along -= FLOOR_STEP
	return from


static func _floor_under(space: Node3D, at: Vector3) -> bool:
	return wall_between(space, at + Vector3.UP * 0.5, at + Vector3.DOWN * STEP_DOWN).is_finite()


## The solid bodies directly under `node` (a construct's wall, C8.14a), so a ray aimed at it is
## not stopped by its own body.
static func solids(node: Node) -> Array[RID]:
	var out: Array[RID] = []
	if node == null:
		return out
	for child: Node in node.get_children():
		var solid: CollisionObject3D = child as CollisionObject3D
		if solid != null:
			out.append(solid.get_rid())
	return out
