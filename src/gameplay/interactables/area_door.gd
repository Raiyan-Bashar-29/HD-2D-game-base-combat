class_name AreaDoor
extends Interactable
## A doorway that actually travels. The one thing in the game that asks to change area.
##
## WHY IT NAMES ONLY AN ID AND A SPAWN
## It emits `Events.area_change_requested` and stops. It does not load, does not fade, does
## not place the player, and above all does not know what is on the other side beyond the id
## written on it. `Director` owns the sequence and the guard, and nothing calls
## `change_area()` directly — which is what keeps two doors firing at once from leaving two
## areas in the tree. A door that performed its own transition would be the beginning of a
## second, unguarded transition path, and that is the single most failure-prone operation in
## a game of this kind.
##
## IT IS NOT A GATE. `Gate` opens something in place; this one moves you. They were kept
## apart deliberately: a locked door that also travels is a `Gate` next to an `AreaDoor`, two
## objects with one job each, rather than one object with a flag deciding which it is today.
##
## OWNS: the destination it names, and refusing while a transition is already in flight.
## MUST NOT: load anything, fade anything, move the player, or know what the destination
## contains.

## The area to travel to. Must match scenes/areas/<id>/<id>.tscn.
@export var target_area: StringName = &""
## Which spawn marker to arrive on. Empty means the destination's first spawn.
@export var target_spawn: StringName = &""


func _ready() -> void:
	verb = GameEnums.InteractVerb.ENTER
	super()
	if target_area == &"":
		Log.error("world", "%s names no target_area and will refuse every attempt" % name)
	elif not Director.area_exists(target_area):
		# Loud at load, not at use. A door onto a deleted area must not look like scenery
		# until the player walks the length of the map to try it.
		Log.error("world", "%s travels to '%s', which has no scene" % [name, target_area])


## STORY_GATED for an unnamed destination and ALREADY_DONE while travelling. Both are refusals
## with a message rather than a silent no-op, on the same reasoning that makes a locked gate
## keep offering its prompt: the player must be able to tell a door from a wall.
func refusal(_who: Node3D) -> GameEnums.RefusalReason:
	if target_area == &"":
		return GameEnums.RefusalReason.STORY_GATED
	if Director.is_transitioning():
		return GameEnums.RefusalReason.ALREADY_DONE
	return GameEnums.RefusalReason.NONE


func perform(_who: Node3D) -> void:
	Log.info("world", "%s asks for '%s' (spawn '%s')" % [name, target_area, target_spawn])
	Events.area_change_requested.emit(target_area, target_spawn)
