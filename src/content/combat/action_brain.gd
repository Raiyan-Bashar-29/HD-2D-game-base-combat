class_name ActionBrain
extends Resource
## How a real-time enemy behaves (C3.6): when it notices the player, how far it will follow,
## how close it fights, when it runs, and which moves it uses.
##
## IN PLAIN WORDS, in metres and seconds:
## - It stands about its home, wandering within `wander_radius` every `wander_every` seconds.
## - A hostile within `aggro_radius` is chased. One that gets beyond `give_up_radius` is let go.
## - Within `attack_range` it attacks, with one of `moves`, then waits `attack_cooldown`.
## - Below `retreat_below` of its hp it backs away from a target nearer than `retreat_distance`.
## - Dragged further than `leash_radius` from home, it gives up and walks back, and will not
##   chase again until it is home.
##
## OWNS: the numbers and the move list of one kind of enemy.
## MUST NOT: decide anything at run time. `ActionDecider` (systems) does that, from these.

@export var aggro_radius: float = 6.0
@export var give_up_radius: float = 10.0
@export var leash_radius: float = 14.0
@export var attack_range: float = 1.6
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 2.5
@export var wander_radius: float = 2.0
@export var wander_every: float = 3.0
## Below this fraction of max hp it retreats. 0 means it never does.
@export_range(0.0, 1.0, 0.01) var retreat_below: float = 0.0
@export var retreat_distance: float = 3.0
@export var moves: Array[ActionBrainEntry] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if moves.is_empty():
		found.append("%s has no moves, so it can never attack" % context)
	for i: int in moves.size():
		if moves[i] == null:
			found.append("%s has an empty move slot %d" % [context, i])
		else:
			found.append_array(moves[i].problems("%s move %d" % [context, i]))
	if give_up_radius < aggro_radius:
		found.append("%s gives up nearer than it notices, so it would chase and drop at once" % context)
	if attack_range <= 0.0 or move_speed < 0.0:
		found.append("%s has no attack range, or a negative speed" % context)
	return found
