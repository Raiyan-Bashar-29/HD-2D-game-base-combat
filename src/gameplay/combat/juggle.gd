class_name Juggle
extends Node
## A fighter knocked into the air (C8.8a): launch and juggle.
##
## IN PLAIN WORDS:
## - A landed hit from a move with a `launch` time puts its victim in the air for that many
##   seconds. In the air a fighter cannot start a move (the player's fighter and a field foe
##   both ask `airborne`).
## - Every further landed hit before it comes down is a JUGGLE: it keeps the victim up a
##   little longer. A launching move adds its `launch` again, any other move adds `HANG`
##   seconds. Each juggle is worth `DECAY` times the one before, so a juggle always ends.
## - When the time runs out the fighter has landed, and the count starts again.
## - A `CharacterBody3D` is also thrown upward, fast enough to rise and fall in the time left.
##
## The `Hurtbox` makes this node under the victim's body the first time it is launched.
##
## OWNS: one fighter's time left in the air and its juggle count.
## MUST NOT: land a hit, decide whether a hit launches (the `Hurtbox` does), or move the body
## sideways (the knockback does).

## Seconds a hit with no `launch` of its own adds to a fighter already in the air.
const HANG: float = 0.25
## What each further juggle is worth, as a share of the one before.
const DECAY: float = 0.7

## Seconds until the fighter lands. 0 means it is on its feet.
var left: float = 0.0
## Hits taken since it left the ground, the launching hit included.
var count: int = 0


func _physics_process(delta: float) -> void:
	pass_time(CombatClock.scaled(delta))


## The `Juggle` on `body`, or null.
static func of(body: Node) -> Juggle:
	if body == null:
		return null
	for child: Node in body.get_children():
		if child is Juggle:
			return child as Juggle
	return null


## True while `body` is in the air from a launch.
static func airborne(body: Node) -> bool:
	var juggle: Juggle = Juggle.of(body)
	return juggle != null and juggle.left > 0.0


## A landed `move` lifts `body`, or keeps it up. Returns the seconds it now has left in the air.
static func lift(body: Node, move: ActionMove) -> float:
	var juggle: Juggle = Juggle.of(body)
	if juggle == null:
		juggle = Juggle.new()
		body.add_child(juggle)
	var worth: float = pow(DECAY, float(juggle.count))
	if juggle.left <= 0.0:
		juggle.left = move.launch
	else:
		juggle.left += (move.launch if move.launch > 0.0 else HANG) * worth
	juggle.count += 1
	var solid: CharacterBody3D = body as CharacterBody3D
	if solid != null:
		# Up at this speed, gravity brings it back down in `left` seconds.
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
		solid.velocity.y = gravity * juggle.left / 2.0
	return juggle.left


## `seconds` of fight time passed. At 0 the fighter has landed and the count starts again.
func pass_time(seconds: float) -> void:
	if left <= 0.0:
		return
	left = maxf(0.0, left - seconds)
	if left <= 0.0:
		count = 0
