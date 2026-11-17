class_name Carried
extends Node
## A thing held overhead (C8.18b). It sits under the carrier's body, named `NAME`.
##
## IN PLAIN WORDS:
## - `lift` puts an `ArenaThing` over the body's head; it follows the body each frame.
## - `throw` sends it the way the carrier faces, as the carrier's shot. `ActionFighter` calls it
##   when the attack button is pressed, so the press throws instead of swinging.
## - The carrier falling, being stunned or thrown into the air sets it down where it stands.
##
## OWNS: which thing a body holds, and keeping it overhead.
## MUST NOT: decide what the throw hits (`Projectile` does) or offer the pick-up (`CarryPoint`).

const NAME: StringName = &"Carried"
## Where the thing is held, above the carrier's feet.
const HOLD: Vector3 = Vector3(0.0, 2.0, 0.0)
## How far in front of the carrier a thing is set down.
const SET_DOWN: float = 1.0

var thing: ArenaThing


## What `body` holds, or null.
static func of(body: Node) -> Carried:
	return body.get_node_or_null(NodePath(String(NAME))) as Carried if body != null else null


## Lifts `made` over `body`'s head. False when either is missing or the body already holds one.
static func lift(body: Node3D, made: ArenaThing) -> bool:
	if body == null or made == null or of(body) != null or not made.is_inside_tree():
		return false
	var held := Carried.new()
	held.name = NAME
	held.thing = made
	body.add_child(held)
	made.carried(true)
	held._hold()
	return true


## Throws what `body` holds along `way`, as the body's shot. False when it holds nothing.
static func throw(body: Node3D, way: Vector3) -> bool:
	var held: Carried = of(body)
	if held == null:
		return false
	var made: ArenaThing = held._let_go()
	if made != null:
		if made.thrown == null:
			made.global_position = body.global_position + _ahead(way) * SET_DOWN
		made.throw_from(Combatant.of(body), way)
	return true


## Sets down what `body` holds, a step in front of it. False when it holds nothing.
static func drop(body: Node3D, way: Vector3) -> bool:
	var held: Carried = of(body)
	if held == null:
		return false
	var made: ArenaThing = held._let_go()
	if made != null:
		made.carried(false)
		made.global_position = body.global_position + _ahead(way) * SET_DOWN
	return true


func _physics_process(_delta: float) -> void:
	var body: Node3D = get_parent() as Node3D
	if not is_instance_valid(thing):
		_let_go()
		return
	var vitals: Vitals = Vitals.of(body)
	var statuses: StatusSet = StatusSet.of(body)
	if (vitals != null and vitals.is_defeated()) or (statuses != null and statuses.halts()) \
			or Juggle.airborne(body) or Grab.held(body):
		drop(body, Vector3.ZERO)
		return
	_hold()


func _hold() -> void:
	var body: Node3D = get_parent() as Node3D
	if body != null and is_instance_valid(thing):
		thing.global_position = body.global_position + HOLD


# Leaves the body at once, so `of` sees nothing, and hands back what it held.
func _let_go() -> ArenaThing:
	var made: ArenaThing = thing if is_instance_valid(thing) else null
	thing = null
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
	return made


static func _ahead(way: Vector3) -> Vector3:
	var flat := Vector3(way.x, 0.0, way.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
