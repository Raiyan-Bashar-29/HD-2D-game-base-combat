class_name MemberArt
extends Resource
## The art of one fighter (C9.9d): the sheet it walks with, and a strip and sounds per move.
##
## IN PLAIN WORDS: a `CombatantDef` names one of these in `art`, and a form's `LookDef` may
## name another (a second costume). While that member is on a body, `ArtSwap` (gameplay) puts
## `sheet` on the body's `CharacterVisual` and, during a move whose id is in `moves`, shows
## that move's strip and plays its sounds. A member with no art keeps the body's own sheet.
##
## OWNS: the shape of a fighter's art.
## MUST NOT: touch a node. `ArtSwap` applies it.

## The walking sheet and how it is cut up. A null sheet leaves the body's own sheet on.
@export var sheet: Texture2D
@export var layout: SpriteSheetLayout
## World size of one sheet pixel, and how far the sprite is lifted (negative lowers it) so the
## drawn feet sit on the ground.
@export var pixel_size: float = 0.035
@export var ground_offset: float = 0.0
## A move's id (`ActionMove.id`) -> its art.
@export var moves: Dictionary[StringName, MoveArt] = {}


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if sheet != null and layout == null:
		found.append("%s has art with a sheet and no layout" % context)
	if sheet != null and layout != null:
		for problem: String in layout.problems(sheet):
			found.append("%s art: %s" % [context, problem])
	if pixel_size <= 0.0:
		found.append("%s has art whose pixel_size is not above 0" % context)
	for id: StringName in moves:
		if moves[id] == null:
			found.append("%s has no art under move '%s'" % [context, id])
		else:
			found.append_array(moves[id].problems("%s move '%s'" % [context, id]))
	return found
