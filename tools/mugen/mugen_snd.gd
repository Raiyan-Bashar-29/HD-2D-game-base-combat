class_name MugenSnd
extends RefCounted
## Reads a M.U.G.E.N `.snd` sound file: a chain of WAV files, each named (group, index) (C9.9c).
##
## IN PLAIN WORDS: after a 512-byte header the file is a linked list. Each link says where the
## next one starts, how long its sound is, and its (group, index) name; the sound itself is an
## ordinary WAV file, so saving it needs no conversion.
##
## OWNS: finding each sound's bytes.
## MUST NOT: play anything, or name a character.

## Every sound in `bytes`: (group, index) as a Vector2i -> its WAV file's bytes.
static func sounds(bytes: PackedByteArray) -> Dictionary:
	var out: Dictionary = {}
	if bytes.size() < 24 or bytes.slice(0, 11).get_string_from_ascii() != "ElecbyteSnd":
		return out
	var at: int = bytes.decode_u32(20)
	for i: int in bytes.decode_u32(16):
		if at <= 0 or at + 16 > bytes.size():
			break
		var length: int = bytes.decode_u32(at + 4)
		var name := Vector2i(bytes.decode_s32(at + 8), bytes.decode_s32(at + 12))
		if not out.has(name):
			out[name] = bytes.slice(at + 16, at + 16 + length)
		at = bytes.decode_u32(at)
	return out
