extends SceneTree
## The command that unpacks a M.U.G.E.N character's sprites and sounds (C9.9c).
##
## IN PLAIN WORDS:
##   godot --headless --script tools/mugen_sprites.gd -- <character.def> <output folder>
##       [--height=1.7] [--frames=8] [--max-cell=256] [--walk=0,20,100]
##       [--actions=200,201] [--sounds=all|none|0_1,5_0]
## It writes a walking sheet, a strip per animation, the sounds, an index and a credits file.
## What each is, and the options, are in `tools/mugen/mugen_sprite_files.gd`. The companion
## `tools/mugen_convert.gd` converts the moves. ONLY use a character the owner has said is
## usable, and keep `CREDITS.md` with the output.
##
## OWNS: reading the command line and printing the result.
## MUST NOT: hold any rule of the unpacking.

const TEXT_OPTIONS: PackedStringArray = ["walk", "actions", "sounds"]


func _init() -> void:
	var paths: PackedStringArray = PackedStringArray()
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var key: String = arg.trim_prefix("--").get_slice("=", 0).replace("-", "_")
			var text: String = arg.get_slice("=", 1)
			options[key] = text if TEXT_OPTIONS.has(key) else text.to_float()
		else:
			paths.append(arg)
	if paths.size() < 2:
		print("usage: -- <character.def> <output folder> [--height=1.7] [--frames=8] "
			+ "[--max-cell=256] [--walk=0,20,100] [--actions=200,201] [--sounds=all|none|0_1,5_0]")
		quit(2)
		return
	var index: Dictionary = MugenSpriteFiles.write(paths[0], paths[1], options)
	print("%s by %s: %d strips, %d sounds, sheet %s, written to %s" % [index["name"], index["author"],
		(index["strips"] as Dictionary).size(), (index["sounds"] as Array).size(),
		"yes" if index.has("sheet") else "NO", paths[1]])
	for problem: String in index["problems"]:
		print("  PROBLEM: %s" % problem)
	quit(0 if index.has("sheet") else 1)
