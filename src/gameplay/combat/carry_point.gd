class_name CarryPoint
extends Interactable
## The interact prompt on a `carryable` `ArenaThing` (C8.18b): pressing it lifts the thing.
##
## IN PLAIN WORDS: the thing makes one as its child (`reach`), with a small sphere the sensor
## can find. Whoever already carries something is refused with "hands full".
##
## OWNS: offering one thing to be picked up.
## MUST NOT: hold or throw it (`Carried` does), or decide what a throw hits.

## How far from the thing's middle the prompt reaches, in metres.
const RADIUS: float = 1.0

var thing: ArenaThing


## Makes the prompt for `made`, named on screen by `label`, and adds it as its child.
static func reach(made: ArenaThing, label: String) -> CarryPoint:
	var point := CarryPoint.new()
	point.thing = made
	point.label_key = label
	point.verb = GameEnums.InteractVerb.TAKE
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	shape.shape = ball
	shape.position = Vector3(0.0, made.size.y / 2.0, 0.0)
	point.add_child(shape)
	made.add_child(point)
	return point


func refusal(who: Node3D) -> GameEnums.RefusalReason:
	if Carried.of(who) != null:
		return GameEnums.RefusalReason.HANDS_FULL
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	Carried.lift(who, thing)
