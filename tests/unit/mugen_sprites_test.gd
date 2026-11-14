extends TestCase
## The M.U.G.E.N sprite and sound unpacker (C9.9c): a tiny made-up sprite file, built here byte
## by byte, is read back, laid out as a strip and a sheet, and written to the scratch folder.
##
## OWNS: assertions about `MugenPacking`, `MugenSff`, `MugenSnd`, `MugenSprites` and
## `MugenSpriteFiles`.
## MUST NOT: name a real character, or read a file from outside the scratch folder.

const RED: Color = Color(1, 0, 0, 1)
const GREEN: Color = Color(0, 1, 0, 1)
const CLEAR: Color = Color(0, 0, 0, 0)
const DEF: String = "[Info]\nname = \"Fixture Fighter\"\nauthor = \"nobody\"\n[Files]\n" \
	+ "cns = fx.cns\nsprite = fx.sff\nanim = fx.air\nsound = fx.snd\n"
const AIR: String = "[Begin Action 0]\nClsn2Default: 1\n Clsn2[0] = -1,-2,1,0\n1,0, 0,0, 4\n1,1, 0,0, 12\n" \
	+ "[Begin Action 20]\n1,2, 0,0, 5, H\n"

var _sff: MugenSff


func run() -> void:
	plan(7)
	equal("the checksum is the PNG one, RLE8 repeats, and LZ5 runs and copies back",
		[MugenPacking.crc32("123456789".to_ascii_buffer()), MugenPacking.rle8(PackedByteArray([0x43, 2, 1]), 4),
		MugenPacking.lz5(PackedByteArray([0x04, 0x41, 0x22, 0x02, 0x02]), 6)],
		[0xCBF43926, PackedByteArray([2, 2, 2, 1]), PackedByteArray([1, 1, 2, 1, 1, 2])])
	_sff = MugenSff.new()
	_sff.read(_file())
	_reading()
	_laying_out()
	_writing()


# A version 2 sprite file: one palette (clear, red, green), and five sprites in group 1:
# 0 raw 2x2, 1 RLE8 4x1, 2 LZ5 3x2, 3 a link to sprite 0, 4 a PNG with no palette of its own.
func _file() -> PackedByteArray:
	var bodies: Array[PackedByteArray] = [PackedByteArray([1, 2, 2, 0]),
		PackedByteArray([4, 0, 0, 0, 0x44, 2]), PackedByteArray([6, 0, 0, 0, 0x04, 0x41, 0x22, 0x02, 0x02]),
		PackedByteArray(), PackedByteArray([2, 0, 0, 0]) + _png()]
	var sizes: Array[Vector2i] = [Vector2i(2, 2), Vector2i(4, 1), Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 1)]
	var formats: PackedByteArray = PackedByteArray([0, 2, 4, 0, 10])
	var out: PackedByteArray = "ElecbyteSpr".to_ascii_buffer()
	out.resize(68 + 5 * 28 + 16)
	out[15] = 2
	var literal: int = out.size()
	for pair: Array in [[36, 68], [40, 5], [44, 68 + 5 * 28], [48, 1], [52, literal], [60, literal]]:
		out.encode_u32(pair[0] as int, pair[1] as int)
	out.encode_u16(68 + 5 * 28 + 4, 3)
	out.encode_u32(68 + 5 * 28 + 12, 12)
	var data: PackedByteArray = PackedByteArray([0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0])
	for i: int in 5:
		var at: int = 68 + i * 28
		for pair: Array in [[0, 1], [2, i], [4, sizes[i].x], [6, sizes[i].y], [8, 1], [10, 2]]:
			out.encode_u16(at + (pair[0] as int), pair[1] as int)
		out[at + 14] = formats[i]
		out.encode_u32(at + 16, data.size())
		out.encode_u32(at + 20, bodies[i].size())
		data.append_array(bodies[i])
	return out + data


# A 2x1 PNG of colour numbers 1 and 2, with no palette inside it.
func _png() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	var parts: Dictionary = {"IHDR": PackedByteArray([0, 0, 0, 2, 0, 0, 0, 1, 8, 3, 0, 0, 0]),
		"IDAT": PackedByteArray([0, 1, 2]).compress(FileAccess.COMPRESSION_DEFLATE), "IEND": PackedByteArray()}
	for kind: String in parts:
		var named: PackedByteArray = kind.to_ascii_buffer() + (parts[kind] as PackedByteArray)
		var sum: int = MugenPacking.crc32(named)
		out.append_array(PackedByteArray([0, 0, 0, named.size() - 4]) + named
			+ PackedByteArray([sum >> 24 & 0xFF, sum >> 16 & 0xFF, sum >> 8 & 0xFF, sum & 0xFF]))
	return out


func _reading() -> void:
	var raw: Image = _sff.image(1, 0)
	equal("a raw sprite takes the file's palette, colour 0 is see-through, and its feet pixel is kept",
		[_sff.problem, _sff.size(1, 0), _sff.axis(1, 0), raw.get_pixel(0, 0), raw.get_pixel(1, 0), raw.get_pixel(1, 1)],
		["", Vector2i(2, 2), Vector2i(1, 2), RED, GREEN, CLEAR])
	var png: Image = _sff.image(1, 4)
	equal("RLE8, LZ5, a link and a PNG are all unpacked; a missing sprite and a wrong file are not",
		[_sff.image(1, 1).get_pixel(3, 0), _sff.image(1, 2).get_pixel(2, 1), _sff.image(1, 3).get_pixel(0, 0),
		png.get_pixel(0, 0), png.get_pixel(1, 0), _sff.image(9, 9), MugenSff.open(_dir() + "/none.sff").problem],
		[GREEN, GREEN, RED, RED, GREEN, null, "not a sprite file"])


func _laying_out() -> void:
	var frames: Array = MugenAir.parse(AIR)[0]
	var strip: Dictionary = MugenSprites.strip(_sff, frames)
	var image: Image = strip["image"]
	equal("a strip is one cell a frame, as wide each side of the feet as the widest frame",
		[strip["cell"], strip["feet"], image.get_size(), strip["ticks"], image.get_pixel(2, 0), image.get_pixel(7, 1)],
		[Vector2i(6, 2), Vector2i(3, 2), Vector2i(12, 2), PackedInt32Array([4, 12]), RED, CLEAR])
	equal("a sheet slot shows the frame on screen at its middle tick",
		[MugenSprites.slot_frame(frames, 0, 4), MugenSprites.slot_frame(frames, 1, 4), MugenSprites.slot_frame(frames, 3, 4)],
		[0, 1, 1])
	var sheet: Dictionary = MugenSprites.sheet(_sff, [frames], 4)
	image = sheet["image"]
	equal("a sheet has four columns, the last two mirrored about the feet",
		[image.get_size(), image.get_pixel(2, 0), image.get_pixel(3, 0), image.get_pixel(12 + 2, 0), image.get_pixel(12 + 3, 0)],
		[Vector2i(24, 8), RED, GREEN, GREEN, RED])


func _writing() -> void:
	var sound: PackedByteArray = "ElecbyteSnd".to_ascii_buffer()
	sound.resize(24 + 16)
	sound.encode_u32(16, 1)
	sound.encode_u32(20, 24)
	sound.encode_u32(24 + 4, 4)
	sound.encode_u32(24 + 8, 5)
	sound.encode_u32(24 + 12, 7)
	sound.append_array("RIFF".to_ascii_buffer())
	var files: Dictionary = {"fx.def": DEF.to_utf8_buffer(), "fx.air": AIR.to_utf8_buffer(), "fx.sff": _file(),
		"fx.snd": sound, "fx.cns": "[Statedef 0]\ntype = S\nanim = 0\n".to_utf8_buffer()}
	for name: String in files:
		var file: FileAccess = FileAccess.open(_dir().path_join(name), FileAccess.WRITE)
		file.store_buffer(files[name] as PackedByteArray)
		file.close()
	var out: String = _dir().path_join("out")
	var index: Dictionary = MugenSpriteFiles.write(_dir().path_join("fx.def"), out, {"height": 1.0, "frames": 4})
	var layout: SpriteSheetLayout = load(out.path_join("sheet_layout.tres"))
	var sheet: Image = Image.load_from_file(out.path_join("sheet.png"))
	equal("the folder holds a sheet with its layout, a strip per animation, the sound, an index and the credit",
		[index["problems"], (index["strips"] as Dictionary).keys(), index["sounds"], index["pixel_size"],
		layout.problems(ImageTexture.create_from_image(sheet)), layout.animations, layout.run_row,
		FileAccess.get_file_as_bytes(out.path_join("sounds/5_7.wav")).get_string_from_ascii(),
		FileAccess.get_file_as_string(out.path_join("CREDITS.md")).contains("nobody"),
		FileAccess.file_exists(out.path_join("strips/anim_20.png")), FileAccess.file_exists(out.path_join("sprites.json"))],
		[PackedStringArray(), ["0", "20"], ["sounds/5_7.wav"], 0.5, PackedStringArray(), 2, -1, "RIFF", true, true, true])


func _dir() -> String:
	var path: String = RunScratch.path("mugen_sprites_fixture")
	DirAccess.make_dir_recursive_absolute(path)
	return path
