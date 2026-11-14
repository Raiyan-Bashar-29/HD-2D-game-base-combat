class_name MugenSpriteFiles
extends RefCounted
## Unpacks a whole M.U.G.E.N character's sprites and sounds into a folder (C9.9c).
##
## IN PLAIN WORDS: give it the character's `.def` and a folder. It writes there:
## - `sheet.png` and `sheet_layout.tres`: standing, walking and running as a sheet any
##   `CharacterVisual` draws (the `walk` option names the three animations);
## - `strips/anim_<number>.png`: one row of frames for each animation asked for (default:
##   every one whose cell is no bigger than `max_cell` pixels, so a body and not a screen-wide
##   effect);
## - `sounds/<group>_<index>.wav`: the sounds asked for (default: all);
## - `sprites.json`: the index. For each strip its frame count, cell, feet pixel and ticks; and
##   `pixel_size`, the metres one pixel stands for, THE SAME scale the move converter uses, so
##   the art and the hitboxes agree;
## - `CREDITS.md`: the character's name and its author, from the `.def`.
##
## OWNS: choosing what to unpack and writing the files.
## MUST NOT: hold cell maths (`MugenSprites`) or name a character.

const DEFAULTS: Dictionary = {"height": 1.7, "frames": 8, "max_cell": 256, "walk": "0,20,100",
	"actions": "", "sounds": "all"}


## Unpacks the character at `def_path` into `directory`. Returns the index, with `problems`.
static func write(def_path: String, directory: String, options: Dictionary = {}) -> Dictionary:
	var settings: Dictionary = DEFAULTS.merged(options, true)
	var about: Dictionary = MugenCharacter.about(def_path)
	var files: Dictionary = about["files"]
	var scale: Dictionary = MugenCharacter.convert(def_path, {"height": settings["height"]}).get("scale", {})
	var out: Dictionary = {"name": about["name"], "author": about["author"], "strips": {}, "sounds": [],
		"pixel_size": DictRead.get_float(scale, "metres_per_pixel"), "problems": PackedStringArray()}
	var sff: MugenSff = MugenSff.open(DictRead.get_string(files, "sprite"))
	var anims: Dictionary = MugenAir.read(DictRead.get_string(files, "anim"))
	if sff.problem != "" or anims.is_empty():
		(out["problems"] as PackedStringArray).append("%s: %s" % [def_path, sff.problem if sff.problem != "" else "no animations"])
		return out
	DirAccess.make_dir_recursive_absolute(directory.path_join("strips"))
	DirAccess.make_dir_recursive_absolute(directory.path_join("sounds"))
	_sheet(sff, anims, directory, settings, out)
	for action: int in _wanted(sff, anims, settings):
		_strip(sff, anims.get(action, []) as Array, action, directory, out)
	_sounds(DictRead.get_string(files, "sound"), directory, DictRead.get_string(settings, "sounds"), out)
	var credit: String = "# %s\n\nSprites and sounds from the M.U.G.E.N character \"%s\" by **%s**.\n" % [
		about["name"], about["name"], about["author"]]
	_save(directory.path_join("CREDITS.md"), credit + "Unpacked by `tools/mugen_sprites.gd`. Used with the owner's say-so; keep this file with them.\n")
	_save(directory.path_join("sprites.json"), JSON.stringify(out, "\t") + "\n")
	return out


# The actions to make strips of: the ones named, else every one that fits `max_cell`.
static func _wanted(sff: MugenSff, anims: Dictionary, settings: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var named: String = DictRead.get_string(settings, "actions")
	if named != "":
		for part: String in named.split(","):
			out.append(part.to_int())
		return out
	var limit: int = DictRead.get_int(settings, "max_cell")
	for action: int in anims:
		var cell: Vector2i = MugenSprites.cell_for(sff, anims[action] as Array)["cell"]
		if cell.x > 2 and cell.x <= limit and cell.y <= limit:
			out.append(action)
	out.sort()
	return out


static func _sheet(sff: MugenSff, anims: Dictionary, directory: String, settings: Dictionary, out: Dictionary) -> void:
	var blocks: Array = []
	var actions: Array[int] = []
	for part: String in DictRead.get_string(settings, "walk").split(","):
		if anims.has(part.to_int()):
			blocks.append(anims[part.to_int()])
			actions.append(part.to_int())
	if blocks.is_empty():
		(out["problems"] as PackedStringArray).append("no standing animation for a sheet")
		return
	var per: int = DictRead.get_int(settings, "frames")
	var made: Dictionary = MugenSprites.sheet(sff, blocks, per)
	(made["image"] as Image).save_png(directory.path_join("sheet.png"))
	var layout := SpriteSheetLayout.new()
	layout.facings = MugenSprites.MIRRORED.size()
	layout.frames = per
	layout.animations = blocks.size()
	layout.cell_size = made["cell"]
	layout.walk_row = mini(1, blocks.size() - 1)
	layout.run_row = 2 if blocks.size() > 2 else -1
	ResourceSaver.save(layout, directory.path_join("sheet_layout.tres"))
	var cell: Vector2i = made["cell"]
	var feet: Vector2i = made["feet"]
	# The cell's bottom edge sits on the ground, so pixels under the feet must sink below it.
	out["sheet"] = {"file": "sheet.png", "layout": "sheet_layout.tres", "actions": actions, "frames": per,
		"cell": [cell.x, cell.y], "feet": [feet.x, feet.y],
		"ground_offset": -float(cell.y - feet.y) * DictRead.get_float(out, "pixel_size")}


static func _strip(sff: MugenSff, frames: Array, action: int, directory: String, out: Dictionary) -> void:
	if frames.is_empty():
		(out["problems"] as PackedStringArray).append("animation %d is not in the file" % action)
		return
	var made: Dictionary = MugenSprites.strip(sff, frames)
	var file: String = "strips/anim_%d.png" % action
	(made["image"] as Image).save_png(directory.path_join(file))
	var cell: Vector2i = made["cell"]
	var feet: Vector2i = made["feet"]
	(out["strips"] as Dictionary)[str(action)] = {"file": file, "frames": frames.size(), "cell": [cell.x, cell.y],
		"feet": [feet.x, feet.y], "ticks": made["ticks"], "seconds": float(MugenAir.length(frames)) / 60.0}


# Saves the sounds `wanted` names: "all", "none", or a list like "0_1,5_0".
static func _sounds(path: String, directory: String, wanted: String, out: Dictionary) -> void:
	if wanted == "none" or not FileAccess.file_exists(path):
		return
	var all: Dictionary = MugenSnd.sounds(FileAccess.get_file_as_bytes(path))
	var names: PackedStringArray = wanted.split(",")
	for key: Vector2i in all:
		var name: String = "%d_%d" % [key.x, key.y]
		if wanted != "all" and not names.has(name):
			continue
		var file: FileAccess = FileAccess.open(directory.path_join("sounds/%s.wav" % name), FileAccess.WRITE)
		if file != null:
			file.store_buffer(all[key] as PackedByteArray)
			(out["sounds"] as Array).append("sounds/%s.wav" % name)


static func _save(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
