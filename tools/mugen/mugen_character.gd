class_name MugenCharacter
extends RefCounted
## Converts one whole M.U.G.E.N character folder into our move data (C9.9a).
##
## IN PLAIN WORDS: give it the character's `.def` file. It finds the other files the `.def`
## names, reads every state, and keeps each one that hurts (an attack) or that makes its user
## untouchable while moving (a dodge). `write` then saves, in a folder of your choosing:
## - `moves.json`: every kept move with its numbers, its button and its notes;
## - `report.md`: the same as a table to read, with what could not be converted;
## - `moves/<prefix>_<state>.tres`: one `ActionMove` per move, ready for a `MoveSet`.
## Nothing is written inside the game's own `data/`: the author picks what to keep.
##
## OWNS: finding the files, choosing the scale, and writing the three outputs.
## MUST NOT: hold a rule of the formula (`MugenFormula`) or name a character.

const DEFAULTS: Dictionary = {"height": 1.7, "power_scale": 0.4, "depth": 1.0, "prefix": "move"}


## What the `.def` at `def_path` says: `name`, `author`, and `files` (each key of its [Files]
## section -> the real path of that file beside it).
static func about(def_path: String) -> Dictionary:
	var out: Dictionary = {"name": "", "author": "", "files": {}}
	for section: Dictionary in MugenIni.read(def_path):
		if section["name"] == "info":
			out["name"] = MugenIni.value(section, "name").replace("\"", "")
			out["author"] = MugenIni.value(section, "author").replace("\"", "")
		elif section["name"] == "files":
			for pair: Array in MugenIni.starting(section, ""):
				(out["files"] as Dictionary)[pair[0]] = _find(def_path.get_base_dir(), str(pair[1]))
	return out


## Reads the character at `def_path`. `options` may override any of `DEFAULTS`. The result has
## `name`, `author`, `scale`, `moves` (see `MugenFormula.numbers`) and `problems`.
static func convert(def_path: String, options: Dictionary = {}) -> Dictionary:
	var settings: Dictionary = DEFAULTS.merged(options, true)
	var out: Dictionary = about(def_path)
	out.merge({"moves": [], "problems": PackedStringArray()})
	var files: Dictionary = out["files"]
	out.erase("files")
	var sections: Array[Dictionary] = []
	for key: String in files:
		if key == "stcommon" or key == "cns" or key.begins_with("st"):
			sections.append_array(MugenIni.read(DictRead.get_string(files, key)))
	var states: Dictionary = MugenState.index(sections)
	var anims: Dictionary = MugenAir.read(DictRead.get_string(files, "anim"))
	if states.is_empty() or anims.is_empty():
		MugenIni.note(out, "problems", "%s has no states or no animations" % def_path)
		return out
	out["scale"] = _scale(sections, anims, settings)
	var inputs: Dictionary = _inputs(MugenIni.read(DictRead.get_string(files, "cmd")))
	var sent: Dictionary = {}
	for number: int in states:
		for spawn: Dictionary in MugenState.facts(number, states, anims, false)["spawns"]:
			sent[spawn["state"]] = true
	for number: int in states:
		var made: Dictionary = MugenFormula.numbers(MugenState.facts(number, states, anims),
			DictRead.get_dict(out, "scale"))
		var dodge: bool = made["iframes_to"] > made["iframes_from"] and made["travel_speed"] != 0.0
		if number < 0 or sent.has(number) or (DictRead.get_int(made, "hits") == 0 and not dodge):
			continue
		made.merge(inputs.get(number, {}) as Dictionary)
		var id := StringName("move/%s_%d" % [settings["prefix"], number])
		made["id"] = id
		for problem: String in MugenFormula.move(made, id).problems(id):
			MugenIni.note(out, "problems", problem)
		(out["moves"] as Array).append(made)
	return out


## Saves `result` (from `convert`) under `directory`. Returns the files written.
static func write(result: Dictionary, directory: String) -> PackedStringArray:
	var written: PackedStringArray = PackedStringArray()
	DirAccess.make_dir_recursive_absolute(directory.path_join("moves"))
	var rows: PackedStringArray = PackedStringArray(["# %s, by %s" % [result["name"], result["author"]],
		"", "Scale: `%s`" % JSON.stringify(result.get("scale", {})), "",
		"| move | anim | button | meter | startup | active | recovery | hits | power | i-frames | notes |",
		"|---|---|---|---|---|---|---|---|---|---|---|"])
	for made: Dictionary in result["moves"]:
		var path: String = directory.path_join("moves/%s.tres" % str(made["id"]).get_file())
		if ResourceSaver.save(MugenFormula.move(made, made["id"] as StringName), path) == OK:
			written.append(path)
		rows.append("| %s | %d | %s | %d | %.2f | %.2f | %.2f | %d | %.1f | %.2f-%.2f | %s |" % [
			made["id"], made["anim"], made.get("button", ""), made.get("meter", 0), made["startup"],
			made["active"], made["recovery"], made["hits"], made["power"], made["iframes_from"],
			made["iframes_to"], "; ".join(made["notes"] as PackedStringArray)])
	for problem: String in result["problems"]:
		rows.append("- PROBLEM: %s" % problem)
	for name: String in ["moves.json", "report.md"]:
		var file: FileAccess = FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t") if name == "moves.json" else "\n".join(rows) + "\n")
			written.append(directory.path_join(name))
	return written


# Metres for one pixel: our height over the standing body box (animation 0), else [Size] height.
static func _scale(sections: Array[Dictionary], anims: Dictionary, settings: Dictionary) -> Dictionary:
	var body: float = MugenAir.bounds(anims.get(0, []) as Array, 0, "body").size.y
	for section: Dictionary in sections:
		if body <= 0.0 and section["name"] == "size":
			body = MugenIni.number(section, "height", 60.0)
	body = body if body > 0.0 else 60.0
	return {"metres_per_pixel": DictRead.get_float(settings, "height") / body, "body_height": body,
		"power_scale": DictRead.get_float(settings, "power_scale"), "depth": DictRead.get_float(settings, "depth")}


# What the command file asks for each state: state -> {"button": the input, "meter": the cost}.
static func _inputs(sections: Array[Dictionary]) -> Dictionary:
	var keys: Dictionary = {}
	for section: Dictionary in sections:
		if section["name"] == "command":
			keys[MugenIni.value(section, "name").replace("\"", "")] = MugenIni.value(section, "command")
	var out: Dictionary = {}
	var named := RegEx.create_from_string("command\\s*=\\s*\"([^\"]+)\"")
	var meter := RegEx.create_from_string("power\\s*>=\\s*(\\d+)")
	for ctrl: Dictionary in DictRead.get_array(MugenState.index(sections).get(-1, {}) as Dictionary, "ctrls"):
		var state: int = int(MugenIni.number(ctrl, "value", -1.0))
		if MugenIni.value(ctrl, "type").to_lower() != "changestate" or out.has(state):
			continue
		var found: Dictionary = {}
		for pair: Array in MugenIni.starting(ctrl, "trigger"):
			var text: String = str(pair[1])
			var hit: RegExMatch = named.search(text)
			if hit != null and not found.has("button"):
				found["button"] = "%s (%s)" % [keys.get(hit.get_string(1), hit.get_string(1)), hit.get_string(1)]
			hit = meter.search(text.to_lower())
			if hit != null:
				found["meter"] = hit.get_string(1).to_int()
		out[state] = found
	return out


# The file `name` beside the .def, whatever its letter case; spaces may be underscores.
static func _find(directory: String, name: String) -> String:
	var wanted: String = name.strip_edges().to_lower()
	for file: String in DirAccess.get_files_at(directory):
		if file.to_lower() == wanted or file.to_lower() == wanted.replace(" ", "_"):
			return directory.path_join(file)
	return directory.path_join(name.strip_edges())
