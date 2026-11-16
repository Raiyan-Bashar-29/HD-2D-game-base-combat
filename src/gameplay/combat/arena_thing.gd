class_name ArenaThing
extends Node3D
## A thing in the arena (C8.9): something that is not a fighter but can be hit.
##
## IN PLAIN WORDS: place one in an area and give it `hp`. Any fighter's swing or shot hits it,
## but nobody chooses it as a target: lock-on, enemies and followers ignore it.
## - With a `burst` move it is an explosive: when its hp is gone it plays that move where it
##   stands, as a `Planted`, and hits every fighter in the box, friend or foe of whoever
##   broke it. Another thing in the box breaks too, so a row of them goes off in a chain.
## - With a `thrown` move it is a throwable: the first hit that hurts it sends it flying
##   away from whoever struck it, as a `Projectile` that belongs to that fighter and so hits
##   that fighter's foes.
## - With neither it is only breakable: it is gone when its hp is.
## - `solid` (C8.14a) also makes it a wall: bodies, swings and shots stop at it, but it can be
##   struck itself (a ray aimed at it ignores its own body).
##
## It makes its own `Vitals`, `Combatant` and `Hurtbox`, so the usual hit rules apply to it. Its
## faction is its own id, which makes it hostile to everyone and everyone hostile to it.
##
## OWNS: one thing's hp, and what breaking or striking it does.
## MUST NOT: decide what a hit does (`Hurtbox` and `Combatant` do), or fly or burst itself:
## `Projectile` and `Planted` do.

## Unique among the things in an area. Empty uses the node's name.
@export var thing_id: StringName = &""
@export var hp: float = 1.0
## The box a swing must touch, standing on the ground.
@export var size: Vector3 = Vector3(0.8, 1.0, 0.8)
## Played where it stands when its hp is gone. Null does not burst.
@export var burst: ActionMove
## Played as a shot when it is struck. Null is not thrown.
@export var thrown: ActionMove
## Metres a second it flies when thrown.
@export var throw_speed: float = 12.0
## True for a wall (C8.14a): its box is also solid on `Layers.WORLD`, so it stops bodies, swings
## and shots behind it, while it can still be struck itself.
@export var solid: bool = false

var _me: Combatant
var _done: bool = false
var _blast: Planted


func _ready() -> void:
	if thing_id == &"":
		thing_id = StringName("thing/" + String(name))
	add_child(Vitals.new())
	_me = Combatant.new()
	_me.combatant_id = thing_id
	_me.faction = thing_id
	_me.base_stats = {&"max_hp": hp}
	_me.add_to_group(Unseen.INERT)
	add_child(_me)
	Vitals.of(self).set_to(&"hp", roundi(hp))
	var hurtbox := Hurtbox.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y / 2.0, 0.0)
	hurtbox.add_child(shape)
	add_child(hurtbox)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var block := CollisionShape3D.new()
		block.shape = box
		block.position = shape.position
		body.add_child(block)
		add_child(body)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = shape.position
	add_child(mesh)
	Events.combatant_damaged.connect(_on_damaged)
	Events.combatant_defeated.connect(_on_defeated)


# It must outlive its own blast, which strikes in its name; then it is gone.
func _physics_process(_delta: float) -> void:
	if _done and burst != null and (not is_instance_valid(_blast) or _blast.gone()):
		queue_free()


func _exit_tree() -> void:
	if Events.combatant_damaged.is_connected(_on_damaged):
		Events.combatant_damaged.disconnect(_on_damaged)
		Events.combatant_defeated.disconnect(_on_defeated)


# Struck: a throwable flies away from whoever struck it, as that fighter's shot.
func _on_damaged(who: StringName, by: StringName, amount: int, _critical: bool) -> void:
	if who != thing_id or thrown == null or amount <= 0 or _done:
		return
	var striker: Combatant = Combatant.find(get_tree(), by)
	var from: Node3D = striker.get_parent() as Node3D if striker != null else null
	if from == null or get_parent() == null:
		return
	_done = true
	var way: Vector3 = global_position - from.global_position
	way.y = 0.0
	var shot := Projectile.new()
	shot.attacker = striker
	shot.speed = throw_speed
	shot.launch(thrown)
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector3(0.0, size.y / 2.0, 0.0)
	shot.direction = way.normalized() if way.length() > 0.01 else Vector3.FORWARD
	queue_free()


# Broken: an explosive bursts where it stands; anything else is simply gone.
func _on_defeated(who: StringName) -> void:
	if who != thing_id or _done:
		return
	_done = true
	if burst == null or get_parent() == null:
		queue_free()
		return
	visible = false
	_blast = Planted.new()
	_blast.attacker = _me
	_blast.plant(burst)
	get_parent().add_child(_blast)
	_blast.global_position = global_position
	_blast.set_off()
