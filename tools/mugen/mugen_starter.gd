class_name MugenStarter
extends RefCounted
## Writes a character's starter kit, loadout and art files from one choices file (C9.9e).
##
## IN PLAIN WORDS: after `tools/mugen_convert.gd` (the moves) and `tools/mugen_sprites.gd` (the
## pictures and sounds), the author writes a small JSON file of choices and runs
## `tools/mugen_build.gd` on it. This file does the work. The choices file says:
## - `moves`: the path of the converter's `moves.json`;
## - `sprites`: the folder the sprites were unpacked into (leave out for no art);
## - `out`: `{kit, loadout, art, strings}`, the path of each file to write (leave one out to
##   skip it; `strings` is a list of the CSV keys the author still has to translate);
## - and the choices themselves, listed in `MugenKit` (`anims` in `MugenArt`).
## The art is saved first and put on the fighter; the kit second; the loadout last, pointing at
## both by path. An example for one real character: `tools/mugen/examples/arima_choices.json`.
##
## OWNS: reading the choices, calling `MugenKit` and `MugenArt`, and saving the files.
## MUST NOT: decide a number (the formula and the choices do), or name a character.


## Builds and saves everything `choices_path` asks for. The result has `written` (paths),
## `strings` (CSV keys to add) and `problems`.
static func write(choices_path: String) -> Dictionary:
	var out: Dictionary = {"written": PackedStringArray(), "strings": PackedStringArray(),
		"problems": PackedStringArray()}
	var choices: Variant = JSON.parse_string(FileAccess.get_file_as_string(choices_path))
	var data: Variant = null
	if choices is Dictionary:
		data = JSON.parse_string(FileAccess.get_file_as_string(DictRead.get_string(choices as Dictionary, "moves")))
	if not data is Dictionary:
		MugenIni.note(out, "problems", "%s: no choices, or its `moves` file is missing" % choices_path)
		return out
	var asked: Dictionary = choices
	var moves: Dictionary = {}
	for made: Dictionary in DictRead.get_array(data as Dictionary, "moves"):
		moves[DictRead.get_int(made, "state")] = made
	var built: Dictionary = MugenKit.build(asked, moves)
	var paths: Dictionary = DictRead.get_dict(asked, "out")
	var loadout: ActionLoadout = built["loadout"]
	if asked.has("sprites") and paths.has("art"):
		var drawn: Dictionary = MugenArt.build(asked, moves, chosen(asked), DictRead.get_string(asked, "sprites"))
		for problem: String in drawn["problems"]:
			MugenIni.note(built, "problems", problem)
		if drawn["art"] != null and _save(drawn["art"] as Resource, DictRead.get_string(paths, "art"), out):
			loadout.fighter.art = drawn["art"]
	if paths.has("kit"):
		_save(built["kit"] as Resource, DictRead.get_string(paths, "kit"), out)
	if paths.has("loadout"):
		_save(loadout, DictRead.get_string(paths, "loadout"), out)
	out["strings"] = built["strings"]
	for problem: String in built["problems"]:
		MugenIni.note(out, "problems", problem)
	if paths.has("strings"):
		var file: FileAccess = FileAccess.open(DictRead.get_string(paths, "strings"), FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(built["strings"] as PackedStringArray) + "\n")
			MugenIni.note(out, "written", DictRead.get_string(paths, "strings"))
	return out


## Every state the choices use: the basic chain, the specials, and each stance's own.
static func chosen(choices: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for group: Dictionary in [choices] + DictRead.get_array(choices, "stances"):
		for number: Variant in DictRead.get_array(group, "chain"):
			out.append(int(DictRead.to_float(number)))
		for special: Dictionary in DictRead.get_array(group, "specials"):
			out.append(DictRead.get_int(special, "state"))
	return out


static func _save(resource: Resource, path: String, out: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error: Error = ResourceSaver.save(resource, path)
	if error == OK:
		# So a file saved after this one points at it by path and does not hold a copy.
		resource.take_over_path(path)
		MugenIni.note(out, "written", path)
	else:
		MugenIni.note(out, "problems", "could not save %s (error %d)" % [path, error])
	return error == OK
