class_name LinkedDoor
extends Area3D
## One of a pair of linked doors (C8.14c, `DoorsMechanism`).
##
## IN PLAIN WORDS: an area that notices fighters' bodies (`PLAYER` and `NPC`). A body that steps
## in, may pass (`may_pass`) and is not being let be, is put at the linked door, `exit` metres out
## along that door's facing; the far door then lets that body be for `REST` seconds. With no
## linked door it does nothing.
##
## OWNS: the link and who it is letting be.
## MUST NOT: decide when it is made or taken away (`DoorsRun` does), or name a character.

const GROUP: StringName = &"linked_doors"
## Seconds a body that came through is let be by the far door.
const REST: float = 0.6

var other: LinkedDoor
var exit: float = 1.0
## Decides who may pass; null lets anyone.
var may_pass: Callable

var _resting: Dictionary[int, float] = {}


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.NPC
	monitoring = true
	monitorable = false


func _ready() -> void:
	add_to_group(GROUP)
	body_entered.connect(pass_through)


## Shapes it: a standing cylinder `radius` wide.
func shape(radius: float) -> void:
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 2.0
	var held := CollisionShape3D.new()
	held.shape = cylinder
	held.position = Vector3.UP
	add_child(held)


func _physics_process(delta: float) -> void:
	for key: int in _resting.keys():
		_resting[key] -= delta
		if _resting[key] <= 0.0:
			_resting.erase(key)


## `body` stepped in: it comes out of the other door, if it may. True when it went through.
func pass_through(body: Node3D) -> bool:
	if body == null or not is_instance_valid(other) or other.is_queued_for_deletion():
		return false
	if _resting.has(body.get_instance_id()):
		return false
	if may_pass.is_valid() and may_pass.call(body) != true:
		return false
	var way: Vector3 = -other.global_basis.z
	other.let_be(body)
	body.global_position = other.global_position + way * exit
	return true


## Lets `body` be for `REST` seconds.
func let_be(body: Node3D) -> void:
	_resting[body.get_instance_id()] = REST
