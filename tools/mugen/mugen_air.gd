class_name MugenAir
extends RefCounted
## Reads a M.U.G.E.N `.air` file: every animation, frame by frame, with its boxes (C9.9a).
##
## IN PLAIN WORDS: an animation ("action") is a list of frames. Each frame names a sprite
## (group, index), how many ticks it shows (60 ticks a second; -1 means it stays for ever), and
## may carry boxes: `Clsn1` boxes HURT what they touch, `Clsn2` boxes are where the fighter CAN
## BE HIT. A frame with no `Clsn2` box cannot be hit at all. Boxes are in pixels, x forward and
## y DOWN (so up is negative), measured from the fighter's feet.
##
## A frame is `{"group", "index", "time", "x", "y", "flip", "hit": Array[Rect2], "body":
## Array[Rect2]}`: `x` and `y` shift the sprite in pixels, `flip` mirrors it left to right.
##
## OWNS: turning the file into frames, and the tick sums over them.
## MUST NOT: know about states or moves. `MugenMoves` does.

## How long a frame that "stays for ever" counts for when ticks are summed.
const FOREVER: int = -1


## Every action of the file at `path`: action number -> its frames, in order.
static func read(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	return parse(file.get_buffer(file.get_length()).get_string_from_utf8())


## Every action in `text`: action number -> its frames, in order.
static func parse(text: String) -> Dictionary:
	var out: Dictionary = {}
	var frames: Array = []
	# Boxes waiting for a frame: [0] hit and [1] body, each for the next frame or as a default.
	var next: Array = [[], []]
	var kept: Array = [[], []]
	var filling: Array = []
	for raw: String in text.split("\n"):
		var line: String = raw.get_slice(";", 0).strip_edges().to_lower()
		if line.begins_with("[begin action"):
			frames = []
			next = [[], []]
			kept = [[], []]
			out[line.trim_prefix("[begin action").get_slice("]", 0).strip_edges().to_int()] = frames
		elif line.begins_with("clsn") and line.contains(":"):
			filling = []
			var which: int = 0 if line.begins_with("clsn1") else 1
			if line.contains("default"):
				kept[which] = filling
			else:
				next[which] = filling
		elif line.begins_with("clsn") and line.contains("="):
			var n: PackedFloat64Array = MugenIni.numbers(line.get_slice("=", 1))
			if n.size() >= 4:
				filling.append(Rect2(minf(n[0], n[2]), minf(n[1], n[3]), absf(n[2] - n[0]),
					absf(n[3] - n[1])))
		elif line != "" and (line[0].is_valid_int() or line[0] == "-"):
			var f: PackedFloat64Array = MugenIni.numbers(line)
			if f.size() < 5:
				continue
			frames.append({"group": int(f[0]), "index": int(f[1]), "time": int(f[4]),
				"x": int(f[2]), "y": int(f[3]), "flip": line.get_slice(",", 5).contains("h"),
				"hit": next[0] if not (next[0] as Array).is_empty() else kept[0],
				"body": next[1] if not (next[1] as Array).is_empty() else kept[1]})
			next = [[], []]
	return out


## Ticks from the start of `frames` to the start of frame `number` (the first frame is 1).
static func ticks_before(frames: Array, number: int) -> int:
	var total: int = 0
	for i: int in mini(number - 1, frames.size()):
		total += maxi(_time(frames[i]), 0)
	return total


## The whole animation in ticks. A frame that stays for ever counts as nothing.
static func length(frames: Array) -> int:
	return ticks_before(frames, frames.size() + 1)


## The index of the frame shown at `tick` (the last one when `tick` is past the end), or -1.
static func frame_at(frames: Array, tick: int) -> int:
	var total: int = 0
	for i: int in frames.size():
		var time: int = _time(frames[i])
		if time == FOREVER or tick < total + time:
			return i
		total += time
	return frames.size() - 1


## The box around every `kind` ("hit" or "body") box of frame `index`; no area when it has none.
static func bounds(frames: Array, index: int, kind: String) -> Rect2:
	var out: Rect2 = Rect2()
	if index < 0 or index >= frames.size():
		return out
	var boxes: Variant = (frames[index] as Dictionary).get(kind, [])
	if boxes is Array:
		for box: Variant in boxes:
			if box is Rect2:
				out = (box as Rect2) if not out.has_area() else out.merge(box as Rect2)
	return out


## The tick spans [from, to) over which frames have (`having` true) or lack a `kind` box.
static func spans(frames: Array, kind: String, having: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var total: int = 0
	for i: int in frames.size():
		var time: int = maxi(_time(frames[i]), 0)
		if bounds(frames, i, kind).has_area() == having and time > 0:
			if not out.is_empty() and out[-1].y == total:
				out[-1].y = total + time
			else:
				out.append(Vector2i(total, total + time))
		total += time
	return out


static func _time(frame: Variant) -> int:
	return DictRead.get_int(frame as Dictionary, "time", 0) if frame is Dictionary else 0
