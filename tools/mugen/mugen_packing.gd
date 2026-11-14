class_name MugenPacking
extends RefCounted
## Unpacks the ways a M.U.G.E.N sprite file squeezes its pixels (C9.9c).
##
## IN PLAIN WORDS: three small jobs, each bytes in and bytes out.
## - `rle8`: a byte whose top two bits are 01 means "repeat the next byte this many times";
##   any other byte is one pixel.
## - `lz5`: packets in groups of eight behind a control byte. A clear control bit is a run of
##   one colour; a set bit copies pixels already written, from a given distance back.
## - `png_with_palette`: a 256-colour PNG, rebuilt with the colours you give it (the sprite
##   file keeps its palettes apart from its PNGs), and colour 0 made see-through.
##
## OWNS: the three unpackers and the PNG checksum they need.
## MUST NOT: read a file or know what a sprite is. `MugenSff` does.

const _PNG_HEAD: int = 8


## `packed` as one byte a pixel, `count` pixels long.
static func rle8(packed: PackedByteArray, count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	var i: int = 0
	var j: int = 0
	while j < count and i < packed.size():
		var value: int = packed[i]
		var run: int = 1
		i += 1
		if value & 0xC0 == 0x40 and i < packed.size():
			run = value & 0x3F
			value = packed[i]
			i += 1
		for k: int in mini(run, count - j):
			out[j + k] = value
		j += run
	return out


## `packed` as one byte a pixel, `count` pixels long.
static func lz5(packed: PackedByteArray, count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	if packed.is_empty():
		return out
	# [0] where we read, [1] where we write, [2] the saved top bits, [3] how many are saved.
	var s: PackedInt32Array = PackedInt32Array([1, 0, 0, 0])
	var control: int = packed[0]
	var bit: int = 0
	while s[1] < count:
		var d: int = _next(packed, s)
		if control & (1 << bit):
			_copy(packed, out, s, d)
		else:
			var run: int = d >> 5
			if run == 0:
				run = _next(packed, s) + 8
			for k: int in mini(run, count - s[1]):
				out[s[1] + k] = d & 0x1F
			s[1] += run
		bit += 1
		if bit >= 8:
			control = _next(packed, s)
			bit = 0
	return out


# A copy packet: a short one keeps two bits of a distance for later; a long one names its own.
static func _copy(packed: PackedByteArray, out: PackedByteArray, s: PackedInt32Array, d: int) -> void:
	var back: int = 0
	var run: int = 0
	if d & 0x3F == 0:
		back = ((d << 2) | _next(packed, s)) + 1
		run = _next(packed, s) + 3
	else:
		s[2] |= (d & 0xC0) >> s[3]
		s[3] += 2
		run = (d & 0x3F) + 1
		if s[3] < 8:
			back = _next(packed, s) + 1
		else:
			back = s[2] + 1
			s[2] = 0
			s[3] = 0
	for k: int in run:
		if s[1] < out.size() and s[1] - back >= 0:
			out[s[1]] = out[s[1] - back]
		s[1] += 1


static func _next(packed: PackedByteArray, s: PackedInt32Array) -> int:
	var value: int = packed[mini(s[0], packed.size() - 1)]
	s[0] += 1
	return value


## The 256-colour PNG `png` with `colours` (RGBA bytes) as its palette. Empty when not a PNG.
static func png_with_palette(png: PackedByteArray, colours: PackedByteArray) -> PackedByteArray:
	if png.size() < _PNG_HEAD + 25 or colours.is_empty():
		return PackedByteArray()
	var out: PackedByteArray = png.slice(0, _PNG_HEAD)
	var rgb: PackedByteArray = PackedByteArray()
	var alpha: PackedByteArray = PackedByteArray()
	for i: int in colours.size() / 4:
		rgb.append_array(colours.slice(i * 4, i * 4 + 3))
		alpha.append(colours[i * 4 + 3])
	var at: int = _PNG_HEAD
	while at + 12 <= png.size():
		var length: int = _big(png, at)
		var kind: String = png.slice(at + 4, at + 8).get_string_from_ascii()
		if kind == "IHDR":
			out.append_array(png.slice(at, at + 12 + length))
			out.append_array(_chunk("PLTE", rgb))
			out.append_array(_chunk("tRNS", alpha))
		elif kind == "IDAT" or kind == "IEND":
			out.append_array(png.slice(at, at + 12 + length))
		at += 12 + length
	return out


static func _big(bytes: PackedByteArray, at: int) -> int:
	return bytes[at] << 24 | bytes[at + 1] << 16 | bytes[at + 2] << 8 | bytes[at + 3]


# One PNG chunk: length, name, body, checksum.
static func _chunk(kind: String, body: PackedByteArray) -> PackedByteArray:
	var named: PackedByteArray = kind.to_ascii_buffer()
	named.append_array(body)
	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, body.size())
	out.reverse()
	out.append_array(named)
	var sum: int = crc32(named)
	out.append_array(PackedByteArray([sum >> 24 & 0xFF, sum >> 16 & 0xFF, sum >> 8 & 0xFF, sum & 0xFF]))
	return out


## The CRC-32 checksum of `bytes`, the one PNG and zip use.
static func crc32(bytes: PackedByteArray) -> int:
	var sum: int = 0xFFFFFFFF
	for value: int in bytes:
		sum ^= value
		for k: int in 8:
			sum = (sum >> 1) ^ (0xEDB88320 if sum & 1 else 0)
	return sum ^ 0xFFFFFFFF
