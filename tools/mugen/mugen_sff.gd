class_name MugenSff
extends RefCounted
## Reads a M.U.G.E.N `.sff` sprite file, version 2, and hands out its pictures (C9.9c).
##
## IN PLAIN WORDS: the file is a list of sprites. Each has a (group, index) name, a size, an
## "axis" (the pixel that sits on the fighter's feet), and its pixels packed one of several
## ways. Most are 256-colour pictures that name a palette kept elsewhere in the file. `image`
## unpacks one sprite into an ordinary RGBA picture; colour 0 of a palette is see-through.
## - Packings read: raw, RLE8, LZ5, PNG8, PNG24, PNG32, and a sprite that links to another.
## - Not read: RLE5, and version 1 files (PCX). `problem` or a null picture says so.
##
## OWNS: the file's bytes, its sprite table and its palettes.
## MUST NOT: know about animations or sheets (`MugenSprites` does), or name a character.

const RAW: int = 0
const RLE8: int = 2
const LZ5: int = 4
const PNG8: int = 10

## Why the file could not be read, or "".
var problem: String = ""
## (group, index) as a Vector2i -> the sprite's place in `_nodes`.
var names: Dictionary = {}

var _data: PackedByteArray = PackedByteArray()
var _nodes: Array[Dictionary] = []
var _palettes: Array[Dictionary] = []
var _literal: int = 0
var _translate: int = 0


## The file at `path`, read. Check `problem` before use.
static func open(path: String) -> MugenSff:
	var sff := MugenSff.new()
	sff.read(FileAccess.get_file_as_bytes(path))
	return sff


## Reads a whole file's `bytes`.
func read(bytes: PackedByteArray) -> void:
	_data = bytes
	if bytes.size() < 68 or bytes.slice(0, 11).get_string_from_ascii() != "ElecbyteSpr":
		problem = "not a sprite file"
		return
	if bytes[15] != 2:
		problem = "version %d sprite files are not read, only version 2" % bytes[15]
		return
	_literal = bytes.decode_u32(52)
	_translate = bytes.decode_u32(60)
	for i: int in bytes.decode_u32(48):
		var at: int = bytes.decode_u32(44) + i * 16
		_palettes.append({"colours": bytes.decode_u16(at + 4), "link": bytes.decode_u16(at + 6),
			"at": _literal + bytes.decode_u32(at + 8), "length": bytes.decode_u32(at + 12)})
	for i: int in bytes.decode_u32(40):
		var at: int = bytes.decode_u32(36) + i * 28
		var block: int = _translate if bytes.decode_u16(at + 26) & 1 else _literal
		_nodes.append({"size": Vector2i(bytes.decode_u16(at + 4), bytes.decode_u16(at + 6)),
			"axis": Vector2i(bytes.decode_s16(at + 8), bytes.decode_s16(at + 10)),
			"link": bytes.decode_u16(at + 12), "format": bytes[at + 14],
			"at": block + bytes.decode_u32(at + 16), "length": bytes.decode_u32(at + 20),
			"palette": bytes.decode_u16(at + 24)})
		names[Vector2i(bytes.decode_u16(at), bytes.decode_u16(at + 2))] = i


## The size of sprite (group, index) in pixels, or zero when it is not in the file.
func size(group: int, index: int) -> Vector2i:
	return _node(group, index).get("size", Vector2i.ZERO)


## The pixel of sprite (group, index) that sits on the fighter's feet.
func axis(group: int, index: int) -> Vector2i:
	return _node(group, index).get("axis", Vector2i.ZERO)


## Sprite (group, index) as an RGBA picture, or null when missing or packed a way not read.
func image(group: int, index: int) -> Image:
	var node: Dictionary = _node(group, index)
	if node.is_empty():
		return null
	var own: Vector2i = node["size"]
	if DictRead.get_int(node, "length") == 0:
		node = _nodes[DictRead.get_int(node, "link")] if DictRead.get_int(node, "link") < _nodes.size() else {}
	if node.is_empty() or own.x <= 0 or own.y <= 0:
		return null
	var format: int = node["format"]
	# Every packing but raw starts with four bytes of unpacked length.
	var from: int = DictRead.get_int(node, "at") + (0 if format == RAW else 4)
	var packed: PackedByteArray = _data.slice(from, DictRead.get_int(node, "at") + DictRead.get_int(node, "length"))
	if format >= PNG8:
		return _png(packed, format, DictRead.get_int(node, "palette"))
	var pixels: PackedByteArray = packed
	if format == RLE8:
		pixels = MugenPacking.rle8(packed, own.x * own.y)
	elif format == LZ5:
		pixels = MugenPacking.lz5(packed, own.x * own.y)
	elif format != RAW:
		return null
	return _coloured(pixels, own, _colours(DictRead.get_int(node, "palette")))


func _node(group: int, index: int) -> Dictionary:
	var at: int = names.get(Vector2i(group, index), -1)
	return _nodes[at] if at >= 0 else {}


# The palette at `index` as RGBA bytes, four a colour, colour 0 see-through.
func _colours(index: int) -> PackedByteArray:
	if index >= _palettes.size():
		return PackedByteArray()
	var palette: Dictionary = _palettes[index]
	if DictRead.get_int(palette, "length") == 0 and DictRead.get_int(palette, "link") < _palettes.size():
		palette = _palettes[DictRead.get_int(palette, "link")]
	var from: int = palette["at"]
	var out: PackedByteArray = _data.slice(from, from + DictRead.get_int(palette, "colours") * 4)
	for i: int in out.size() / 4:
		out[i * 4 + 3] = 0 if i == 0 else 255
	return out


# One byte a pixel, each naming a colour of `colours`, as an RGBA picture.
func _coloured(pixels: PackedByteArray, own: Vector2i, colours: PackedByteArray) -> Image:
	var out: PackedByteArray = PackedByteArray()
	out.resize(own.x * own.y * 4)
	for i: int in mini(pixels.size(), own.x * own.y):
		var c: int = pixels[i] * 4
		if c + 3 < colours.size():
			out[i * 4] = colours[c]
			out[i * 4 + 1] = colours[c + 1]
			out[i * 4 + 2] = colours[c + 2]
			out[i * 4 + 3] = colours[c + 3]
	return Image.create_from_data(own.x, own.y, false, Image.FORMAT_RGBA8, out)


# A PNG inside the file. A 256-colour one takes its colours from the FILE's palette, not its own.
func _png(packed: PackedByteArray, format: int, palette: int) -> Image:
	var picture := Image.new()
	var bytes: PackedByteArray = packed
	if format == PNG8:
		bytes = MugenPacking.png_with_palette(packed, _colours(palette))
	if bytes.is_empty() or picture.load_png_from_buffer(bytes) != OK:
		return null
	picture.convert(Image.FORMAT_RGBA8)
	return picture
