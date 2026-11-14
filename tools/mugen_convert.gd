extends SceneTree
## Converts a M.U.G.E.N character into our move data (C9.9a). Works on any character folder.
##
## RUN:  godot --headless --script tools/mugen_convert.gd -- <character.def> <output folder>
##           [--height=1.7] [--power-scale=0.4] [--depth=1.0] [--prefix=name]
##
## IN PLAIN WORDS: point it at the character's `.def` file and at an empty folder. It writes
## `moves.json`, `report.md` and one `ActionMove` file per attack and dodge. `--height` is how
## tall our fighter is in metres, `--power-scale` turns their damage into our power, `--depth`
## is how thick a hitbox is, and `--prefix` names the moves. The formula is `MugenFormula`'s,
## written out in `docs/POWERS.md` § Converting a M.U.G.E.N character.
##
## Only use a character whose author allows it, and keep the author's name with the output.
##
## MUST NOT: write into `data/`. The author copies what the game keeps.


func _init() -> void:
	var paths: PackedStringArray = PackedStringArray()
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var key: String = arg.trim_prefix("--").get_slice("=", 0).replace("-", "_")
			var text: String = arg.get_slice("=", 1)
			options[key] = text if key == "prefix" else text.to_float()
		else:
			paths.append(arg)
	if paths.size() < 2:
		print("usage: -- <character.def> <output folder> [--height=1.7] [--power-scale=0.4] "
			+ "[--depth=1.0] [--prefix=name]")
		quit(2)
		return
	var result: Dictionary = MugenCharacter.convert(paths[0], options)
	var written: PackedStringArray = MugenCharacter.write(result, paths[1])
	print("%s by %s: %d moves, %d files written to %s" % [result["name"], result["author"],
		(result["moves"] as Array).size(), written.size(), paths[1]])
	for problem: String in result["problems"]:
		print("  PROBLEM: %s" % problem)
	quit(0 if not (result["moves"] as Array).is_empty() else 1)
