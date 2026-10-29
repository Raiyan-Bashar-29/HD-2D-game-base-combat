class_name ClimbPoint
extends Interactable
## A ladder, a trellis or a set of handholds: the authored way up. This is what "no jumping"
## implies - if the player cannot leap at a ledge, the level has to offer the ledge deliberately.
##
## WHY VERTICAL MOVEMENT IS AN INTERACTABLE AND NOT A MOVE
## A free jump makes the player try every ledge in the level, and every collision gap becomes
## a bug report. An authored climb inverts that: the ways up are exactly the ones the level
## meant, they are visible because they carry a prompt, and a climb the plot has not unlocked
## refuses with a reason instead of failing silently as an unreachable jump.
##
## TWO ENDS, ONE OBJECT. The climb runs between two markers and always goes to the far end
## from whoever is climbing, so one object serves both up and down. Modelling up and down as
## two objects doubles the placement work and lets them drift out of alignment.
##
## OWNS: where the climb starts and ends, and whether it may be climbed now.
## MUST NOT: move the body itself. It asks the mover to climb and the mover owns its own
## position - the same boundary that keeps the player controller ignorant of interaction.

## The two ends of the climb. Both are required; a climb point with either missing is inert.
@export var bottom_point: Marker3D = null
@export var top_point: Marker3D = null
## Must be true before this may be climbed. Empty means it is never locked.
@export var requires_flag: StringName = &""

## Local listeners. `destination` is the end the climber is heading for.
signal climbed(destination: Vector3)


func _ready() -> void:
	verb = GameEnums.InteractVerb.CLIMB
	super()
	if bottom_point == null or top_point == null:
		Log.error("interact", "%s has no bottom_point/top_point, so it cannot be climbed" % name)
		set_available(false)


func refusal(who: Node3D) -> GameEnums.RefusalReason:
	if requires_flag != &"" and not Flags.get_bool(requires_flag):
		return GameEnums.RefusalReason.LOCKED
	var mover: PlayerController = who as PlayerController
	if mover == null:
		# Whoever this is has no climb, which is a different thing from being refused one.
		return GameEnums.RefusalReason.MISSING_SKILL
	if not mover.can_climb():
		# Mid-air, or already climbing. Grounding is the body's own rule, asked not assumed.
		return GameEnums.RefusalReason.NOT_GROUNDED
	return GameEnums.RefusalReason.NONE


func perform(who: Node3D) -> void:
	var mover: PlayerController = who as PlayerController
	if mover == null:
		return
	var destination: Vector3 = far_end_from(mover.global_position)
	if not mover.begin_climb(destination):
		return
	climbed.emit(destination)
	Log.info("interact", "%s climbing to %s" % [name, str(destination)])


## The end furthest from a position: stand at the foot and you go up, stand at the head and
## you come down. Falls back to this node's own position when either marker is missing.
func far_end_from(from: Vector3) -> Vector3:
	if bottom_point == null or top_point == null:
		return global_position
	var to_bottom: float = from.distance_squared_to(bottom_point.global_position)
	var to_top: float = from.distance_squared_to(top_point.global_position)
	return top_point.global_position if to_bottom <= to_top else bottom_point.global_position
