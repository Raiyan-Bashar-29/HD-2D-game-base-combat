extends TestCase
## Older sprite files (C10.35): RLE5 unpacks to the expected pixels; a version 1 file with one
## 256-colour PCX sprite gives its name, size, axis and colours, colour 0 see-through; a file cut
## short says so.
##
## OWNS: assertions about `MugenPacking.rle5`, `MugenPacking.pcx` and `MugenSff`'s version 1 path.
## MUST NOT: use fan assets. Every byte here is built by hand.

func run() -> void:
	plan(3)
	var rle: PackedByteArray = PackedByteArray([1, 0x81, 5, (5 << 5) | 3])
	equal("RLE5: a run of colour 5, then a packet of six 3s", MugenPacking.rle5(rle, 8),
		PackedByteArray([5, 5, 3, 3, 3, 3, 3, 3]))
	var sff := MugenSff.new()
	sff.read(_v1_file(true))
	var picture: Image = sff.image(9000, 0)
	equal("a version 1 file gives the sprite's name, size, axis and colours, colour 0 see-through",
		[sff.problem, sff.size(9000, 0), sff.axis(9000, 0), picture.get_pixel(0, 0).a8, picture.get_pixel(1, 0).r8,
			picture.get_pixel(1, 0).g8], ["", Vector2i(2, 1), Vector2i(3, 4), 0, 200, 100])
	var cut := MugenSff.new()
	cut.read(_v1_file(false))
	equal("a file cut short says so", cut.problem != "", true)


# A version 1 file holding one 2 by 1 sprite (pixels 0 and 1) at (9000, 0); `whole` false cuts
# the sprite's data off.
func _v1_file(whole: bool) -> PackedByteArray:
	var head := PackedByteArray()
	head.resize(512)
	var sign: PackedByteArray = "ElecbyteSpr".to_ascii_buffer()
	for i: int in sign.size():
		head[i] = sign[i]
	head[15] = 1
	head.encode_u32(16, 1)
	head.encode_u32(20, 1)
	head.encode_u32(24, 512)
	head.encode_u32(28, 32)
	var pcx := PackedByteArray()
	pcx.resize(128)
	pcx[0] = 0x0A
	pcx[1] = 5
	pcx[2] = 1
	pcx[3] = 8
	pcx.encode_u16(8, 1)
	pcx.encode_u16(10, 0)
	pcx[65] = 1
	pcx.encode_u16(66, 2)
	pcx.append_array(PackedByteArray([0, 1, 0x0C]))
	var palette := PackedByteArray()
	palette.resize(768)
	palette[0] = 10
	palette[3] = 200
	palette[4] = 100
	palette[5] = 50
	pcx.append_array(palette)
	var sub := PackedByteArray()
	sub.resize(32)
	sub.encode_u32(4, pcx.size())
	sub.encode_s16(8, 3)
	sub.encode_s16(10, 4)
	sub.encode_u16(12, 9000)
	head.append_array(sub)
	if whole:
		head.append_array(pcx)
	return head
