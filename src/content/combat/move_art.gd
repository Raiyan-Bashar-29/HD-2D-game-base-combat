class_name MoveArt
extends Resource
## What one move looks like (C9.9d): a strip of frames.
##
## IN PLAIN WORDS: the strip is one row of pictures, left to right, all the same size, drawn
## facing right. The strip is spread evenly over `seconds`, and holds its last picture after
## that. `ArtSwap` (gameplay) shows the strip while the move's timeline runs. A move's sounds
## are not here: they are SOUND events on the move itself (`MoveEvent`, C8.16b).
##
## OWNS: the shape of a move's art.
## MUST NOT: touch a node or know which move it belongs to. `MemberArt.moves` maps a move's id
## to one of these.

@export var strip: Texture2D
## How many pictures the strip holds.
@export var frames: int = 1
## Where the feet are in one picture, in pixels from its top-left corner.
@export var feet: Vector2i = Vector2i.ZERO
## How long the whole strip takes to play.
@export var seconds: float = 0.5


## Which picture shows `elapsed` seconds into the move.
func frame_at(elapsed: float) -> int:
	if frames <= 1 or seconds <= 0.0:
		return 0
	return clampi(int(elapsed / seconds * float(frames)), 0, frames - 1)


## The size of one picture, in pixels.
func cell() -> Vector2i:
	if strip == null:
		return Vector2i.ZERO
	return Vector2i(strip.get_width() / maxi(1, frames), strip.get_height())


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if strip == null:
		found.append("%s has move art with no strip" % context)
	if frames < 1:
		found.append("%s has move art with fewer than 1 frame" % context)
	if strip != null and strip.get_width() % maxi(1, frames) != 0:
		found.append("%s has a strip whose width is not a whole number of frames" % context)
	return found
