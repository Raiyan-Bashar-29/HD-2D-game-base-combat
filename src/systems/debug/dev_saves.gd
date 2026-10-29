class_name DevSaves
extends Node
## Where a DEBUG LAUNCH keeps its saves: never where the developer keeps theirs.
##
## THE DEFECT THIS CLOSES, found by T6.9 while proving the suite no longer ate real saves. The
## ladder's last rung is a windowed capture with `--new-game`, and `--new-game` starts a REAL run.
## T5.10's autosave policy then does exactly what it does for a player: it writes
## `SaveSystem.AUTOSAVE_SLOT` a frame after the area arrives, and again on quit. So every capture,
## in every worktree on the machine, since all of them share one `user://`, wrote over the
## developer's own autosave, and the photograph showed an `Autosaved.` toast as it did so. The
## probes were worse: `--save-state`/`--load-state` and `--cross-area-save` DELETE the slot they
## used, and the slot a probe picks is a slot a developer may have filled by playing.
##
## REDIRECT, NOT SUPPRESS, and that was the decision. Turning autosave off for a capture would fix
## one writer of three and photograph a game that behaves differently from the one a player gets:
## the toast would vanish from the picture, and the `--autosave-write`/`--autosave-continue` pair
## in `dev_scenario_shots.gd`, which exists to prove the autosave works, would prove nothing. Every
## writer goes through `SaveSystem.save_dir`, which T5.22 made a public seam for exactly this kind
## of caller, so ONE assignment here covers the autosave, every probe and every console `save`,
## and the game underneath runs unchanged.
##
## ANY USER ARGUMENT IS A DEBUG LAUNCH. Not only `--shot`: `--save-state` shoots nothing and
## deletes a slot. A plain run from the editor passes none and keeps the real store, so playing
## the game and saving still means what it says. `--real-saves` is the way back, on purpose, for a
## developer who wants a staged launch to write the store they play from.
##
## NEVER EMPTIED HERE, which is the difference from `SaveFixture.root()`. The probes come in pairs
## across two PROCESSES (dev_probes.gd says why), and the second must find what the first wrote.
## It is a separate directory from the suite's for the same reason: `SaveFixture.activate()`
## empties that one, so a suite running in another session would eat a capture pair's autosave.
## Deleting `user://dev_saves` by hand is always safe.
##
## FIRST OF THE DEBUG NODES in `game_root.tscn`, before `Autosave`. Nothing writes during `_ready`
## today, and the main menu reads the slots only when `GameRoot._ready` asks for it, after every
## child; first in the tree keeps that true when somebody adds a node that does.
##
## AND SETTINGS, T6.11, which T6.10 left out and said so. `--locale=` goes through
## `Settings.set_value`, which saves, so a capture wrote the developer's real
## `user://settings.cfg` — a sentinel `locale="en"` came back `"en_XA"`. The same rule, the same
## opt-out, the same one-assignment shape: `Settings.file_path` is that file's `save_dir`. WRITES
## ONLY. `Settings` already READ the real file in its own `_ready`, before this node existed, and
## that is the behaviour wanted: a capture looks like the developer's game, and whatever it
## changes lands in scratch and is never read back, so no launch inherits the last one's locale.
##
## OWNS: where a debug launch's saves and settings are written.
## MUST NOT: write, read or delete a save or settings file itself, change when an autosave
## happens, or be depended upon by gameplay. Deleting this file must not break the game.

## The scratch store. Under `user://` for `SaveFixture.root()`'s reason: outside the repository.
const SCRATCH_DIR: String = "user://dev_saves"
## The scratch settings file. Beside the store rather than in it, so a slot scan never meets it.
const SCRATCH_SETTINGS: String = "user://dev_settings.cfg"
## The opt-out, for a staged launch that SHOULD write the real store and the real settings.
const REAL_SAVES_FLAG: String = "--real-saves"


func _ready() -> void:
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard as every file here: a release
	# build passed a stray argument keeps the player's store.
	if not OS.is_debug_build():
		return
	apply(OS.get_cmdline_user_args())


## Point every store a launch with these arguments would write at scratch, or leave both alone,
## and say which. Static and public so the suite drives the REAL assignments with arguments of
## its own, since its process has none; the caller puts the two paths back.
static func apply(arguments: PackedStringArray) -> bool:
	var directory: String = save_dir_for(arguments)
	if directory == "":
		return false
	SaveSystem.save_dir = directory
	Settings.file_path = SCRATCH_SETTINGS
	Log.info("save", "Debug launch: saves go to %s and settings to %s (%s keeps the real ones)" % [
		directory, SCRATCH_SETTINGS, REAL_SAVES_FLAG,
	])
	return true


## The directory a launch with these arguments must save to, or "" to leave the store alone. PURE
## and static so the suite asserts the rule itself: the suite's own process has no user arguments,
## so the one thing it cannot do is launch the game with some.
static func save_dir_for(arguments: PackedStringArray) -> String:
	if arguments.is_empty() or arguments.has(REAL_SAVES_FLAG):
		return ""
	return SCRATCH_DIR
