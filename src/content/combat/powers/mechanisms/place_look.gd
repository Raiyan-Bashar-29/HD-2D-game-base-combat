class_name PlaceLook
extends Resource
## What a battlefield's place looks like while it stands (C6.9f): a name and a tint laid over the
## ground, sky and light. A placeholder until art exists (GEAR.md Part 4's dummy rule).
##
## IN PLAIN WORDS: a battlefield with a `place` changes how the ground and sky read while it stands,
## and the HUD (C6.9g) names it. Only the id, the name and a colour are here; nothing draws them yet.
##
## OWNS: the shape of a place look.
## MUST NOT: hold running state, or name a game's places. `BattlefieldPlace` (gameplay) applies it.

## The id a battlefield names, e.g. `place/torn_sky`.
@export var id: StringName = &""
## The localisation key for the place's name.
@export var name_key: String = ""
## The tint laid over the ground and sky while the place stands.
@export var tint: Color = Color.WHITE


func problems(context: String) -> PackedStringArray:
	var found := PackedStringArray()
	if id == &"":
		found.append("%s is a place look with no id" % context)
	if name_key.is_empty():
		found.append("%s is a place look with no name key" % context)
	return found
