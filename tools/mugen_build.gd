extends SceneTree
## The command that writes a converted character's kit, loadout and art files (C9.9e).
##
## IN PLAIN WORDS:
##   godot --headless --script tools/mugen_build.gd -- <choices.json>
## Run it after `tools/mugen_convert.gd` (the moves) and `tools/mugen_sprites.gd` (the art, then
## `--import`). The choices file names the moves to use and where to write; its fields are
## listed in `tools/mugen/mugen_starter.gd` and `tools/mugen/mugen_kit.gd`, and
## `tools/mugen/examples/arima_choices.json` is one to copy. It prints the files it wrote, the
## CSV keys still to add to `localization/strings.csv`, and every problem.
##
## OWNS: reading the command line and printing the result.
## MUST NOT: hold any rule of the building.


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <choices.json>")
		quit(2)
		return
	var result: Dictionary = MugenStarter.write(args[0])
	for path: String in result["written"]:
		print("wrote %s" % path)
	for key: String in result["strings"]:
		print("  add to strings.csv: %s" % key)
	for problem: String in result["problems"]:
		print("  PROBLEM: %s" % problem)
	quit(0 if not (result["written"] as PackedStringArray).is_empty() else 1)
