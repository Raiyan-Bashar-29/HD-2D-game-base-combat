class_name MugenSprites
extends RefCounted
## Lays a M.U.G.E.N character's sprites out the way this base draws them (C9.9c).
##
## IN PLAIN WORDS: their sprites are loose pictures of any size, each with a "feet" pixel, and
## an animation lists them with a time each. We draw from grids of equal cells. Two layouts:
## - `strip`: ONE animation as one row, a cell per frame in the animation's own order, with
##   each frame's ticks kept beside it. For a move's animation.
## - `sheet`: several animations as a `SpriteSheetLayout` sheet (facings across, frames down).
##   Each animation is cut to the same number of frames BY TIME: slot i shows whatever frame
##   was on screen at the middle of slot i. Their art faces one way, so the four columns are
##   right, right, left, left (south, east, north, west), the left ones mirrored.
## In both, every cell is as wide to the left of the feet as to the right, so the feet are at
## the middle of the cell and a mirrored cell stays in place. `feet` is that pixel.
##
## OWNS: the cell maths and the pasting.
## MUST NOT: read or write a file (`MugenSpriteFiles` does), or name a character.

## Sheet columns: which way the art looks for south, east, north and west.
const MIRRORED: Array[bool] = [false, false, true, true]


## Where frame `frame`'s sprite lands, in pixels from the feet (x right, y down).
static func placed(sff: MugenSff, frame: Dictionary) -> Rect2i:
	var group: int = DictRead.get_int(frame, "group")
	var index: int = DictRead.get_int(frame, "index")
	var size: Vector2i = sff.size(group, index)
	var axis: Vector2i = sff.axis(group, index)
	var left: int = axis.x - size.x if DictRead.get_bool(frame, "flip") else -axis.x
	return Rect2i(left + DictRead.get_int(frame, "x"), DictRead.get_int(frame, "y") - axis.y, size.x, size.y)


## The cell that holds every frame of `frames`: `{"cell": Vector2i, "feet": Vector2i}`.
static func cell_for(sff: MugenSff, frames: Array) -> Dictionary:
	var half: int = 1
	var top: int = -1
	var bottom: int = 0
	for frame: Dictionary in frames:
		var box: Rect2i = placed(sff, frame)
		if box.size.x <= 0:
			continue
		half = maxi(half, maxi(-box.position.x, box.end.x))
		top = mini(top, box.position.y)
		bottom = maxi(bottom, box.end.y)
	return {"cell": Vector2i(half * 2, bottom - top), "feet": Vector2i(half, -top)}


## One animation as a row of cells: `{"image", "cell", "feet", "ticks": PackedInt32Array}`.
static func strip(sff: MugenSff, frames: Array) -> Dictionary:
	var out: Dictionary = cell_for(sff, frames)
	var cell: Vector2i = out["cell"]
	var image: Image = Image.create_empty(cell.x * maxi(frames.size(), 1), cell.y, false, Image.FORMAT_RGBA8)
	var ticks: PackedInt32Array = PackedInt32Array()
	for i: int in frames.size():
		paste(sff, frames[i] as Dictionary, image, Vector2i(cell.x * i, 0) + (out["feet"] as Vector2i), false)
		ticks.append(DictRead.get_int(frames[i] as Dictionary, "time"))
	out.merge({"image": image, "ticks": ticks})
	return out


## Several animations as one sheet, `per` frames each: `{"image", "cell", "feet"}`.
static func sheet(sff: MugenSff, animations: Array, per: int) -> Dictionary:
	var every: Array = []
	for frames: Array in animations:
		every.append_array(frames)
	var out: Dictionary = cell_for(sff, every)
	var cell: Vector2i = out["cell"]
	var image: Image = Image.create_empty(cell.x * MIRRORED.size(), cell.y * per * animations.size(),
		false, Image.FORMAT_RGBA8)
	for a: int in animations.size():
		var frames: Array = animations[a]
		for slot: int in per:
			var shown: int = slot_frame(frames, slot, per)
			for column: int in MIRRORED.size() if shown >= 0 else 0:
				var corner := Vector2i(cell.x * column, cell.y * (a * per + slot))
				paste(sff, frames[shown] as Dictionary, image, corner + (out["feet"] as Vector2i), MIRRORED[column])
	out["image"] = image
	return out


## THE TIME FORMULA: which frame of `frames` slot `slot` of `per` shows, or -1 for none.
static func slot_frame(frames: Array, slot: int, per: int) -> int:
	var length: int = MugenAir.length(frames)
	if length <= 0:
		return mini(slot, frames.size() - 1)
	return MugenAir.frame_at(frames, int((float(slot) + 0.5) * float(length) / float(per)))


## Pastes `frame`'s sprite into `image` with its feet at `feet`; `mirror` turns it to face left.
static func paste(sff: MugenSff, frame: Dictionary, image: Image, feet: Vector2i, mirror: bool) -> void:
	var picture: Image = sff.image(DictRead.get_int(frame, "group"), DictRead.get_int(frame, "index"))
	if picture == null:
		return
	var box: Rect2i = placed(sff, frame)
	if DictRead.get_bool(frame, "flip") != mirror:
		picture.flip_x()
	if mirror:
		box.position.x = -box.end.x
	image.blit_rect(picture, Rect2i(Vector2i.ZERO, box.size), feet + box.position)
