class_name MugenArt
extends RefCounted
## Builds a `MemberArt` from the unpacked sprites and the converted moves (C9.9e).
##
## IN PLAIN WORDS: `MugenSpriteFiles` wrote a folder with a walking sheet, one strip per
## animation, the sounds and `sprites.json`. The converter's `moves.json` says which animation
## each move plays. This file joins the two: the sheet and its layout, and for each chosen
## move a `MoveArt` with the strip, its frames, feet and length. (A move's sounds are events
## on the move itself since C8.16b: `MugenEvents`.)
## A choices file may say `anims: {"<state>": <animation>}` when a move's strip is under a
## different animation number than the one its state names.
## Run `godot --headless --import` after unpacking, so the pictures load as game textures; a
## picture that is not imported yet is still read, and a problem says so.
##
## OWNS: turning `sprites.json` and the moves into a `MemberArt`.
## MUST NOT: unpack a sprite or a sound (`MugenSpriteFiles`), or name a character.


## The art for the states in `chosen`. `folder` holds `sprites.json`. The result has `art`
## (null when the folder has no index) and `problems`.
static func build(choices: Dictionary, moves: Dictionary, chosen: PackedInt32Array, folder: String) -> Dictionary:
	var out: Dictionary = {"art": null, "problems": PackedStringArray()}
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("sprites.json")))
	if not index is Dictionary:
		MugenIni.note(out, "problems", "%s has no sprites.json" % folder)
		return out
	var info: Dictionary = index
	var art := MemberArt.new()
	var sheet: Dictionary = DictRead.get_dict(info, "sheet")
	art.sheet = _picture(folder.path_join(DictRead.get_string(sheet, "file")), out)
	art.layout = load(folder.path_join(DictRead.get_string(sheet, "layout"))) as SpriteSheetLayout
	art.pixel_size = DictRead.get_float(info, "pixel_size", art.pixel_size)
	art.ground_offset = DictRead.get_float(sheet, "ground_offset")
	var name: String = DictRead.get_string(choices, "name", "fighter")
	var anims: Dictionary = DictRead.get_dict(choices, "anims")
	for state: int in chosen:
		var made: Dictionary = moves.get(state, {})
		var anim: int = DictRead.get_int(anims, str(state), DictRead.get_int(made, "anim", state))
		var strip: Dictionary = DictRead.get_dict(DictRead.get_dict(info, "strips"), str(anim))
		if strip.is_empty():
			MugenIni.note(out, "problems", "state %d: no strip for animation %d" % [state, anim])
			continue
		art.moves[StringName("move/%s_%d" % [name, state])] = _move(strip, folder, out)
	out["art"] = art
	return out


static func _move(strip: Dictionary, folder: String, out: Dictionary) -> MoveArt:
	var art := MoveArt.new()
	art.strip = _picture(folder.path_join(DictRead.get_string(strip, "file")), out)
	art.frames = DictRead.get_int(strip, "frames", 1)
	var feet: Array = DictRead.get_array(strip, "feet")
	if feet.size() >= 2:
		art.feet = Vector2i(int(DictRead.to_float(feet[0])), int(DictRead.to_float(feet[1])))
	art.seconds = DictRead.get_float(strip, "seconds", art.seconds)
	return art


# The picture at `path`: the imported texture, else the file read as it is (with a problem).
static func _picture(path: String, out: Dictionary) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	MugenIni.note(out, "problems", "%s is %s" % [path,
		"not imported yet (run --import, then build again)" if image != null else "missing"])
	return ImageTexture.create_from_image(image) if image != null else null
