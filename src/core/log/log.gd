extends Node
## Central logging. Autoload `Log`. Nothing in this project calls print() directly.
##
## WHY THIS EXISTS
## When something breaks after twenty minutes of play, the log is the only forensic trail.
## print() gives no severity, no category and no file on disk, so a bug report becomes
## "it stopped working". This gives all three for one function call.
##
## OWNS: severity threshold, category tagging, the on-disk log file, log rotation.
## MUST NOT: know any game rule. It never reads Flags, never touches gameplay, and imports
## nothing from src/gameplay or src/systems. Everything may depend on Log; Log depends only on
## `GameConfig` and `TemplateVersion`, both pure readers of project.godot that depend on nothing
## themselves. Those two edges are what let the banner and the log file name say which GAME this
## is and which BASE it was built on, without this file containing either answer — see T1.2 and
## T4.1 in docs/DEVLOG.md.
##
## USAGE
##     Log.info("world", "Area transition %s -> %s" % [from, to])
##     Log.error("save", "Slot %d refused to write: %s" % [slot, error_string(err)])
##
## CANONICAL CATEGORIES — keep this list short and reuse it, so filtering stays useful:
##     boot, input, world, area, camera, character, npc, interact, inventory, item,
##     dialogue, quest, clock, weather, audio, save, ui, settings, test, perf
##
## COST NOTE: a suppressed call still evaluates its own message argument, because GDScript
## has no lazy arguments. For a message that is expensive to build, guard it:
##     if Log.enabled(Log.Level.DEBUG): Log.debug("perf", _build_expensive_report())

enum Level { TRACE, DEBUG, INFO, WARN, ERROR, NONE }

const LOG_DIR: String = "user://logs"
const MAX_FILES: int = 12
const _NAMES: Array[String] = ["TRACE", "DEBUG", "INFO ", "WARN ", "ERROR", "NONE "]

## Messages below this level are dropped. Raised to INFO automatically in release builds.
var min_level: Level = Level.DEBUG
## Mirror everything to stdout. Kept on in headless runs so test output is visible.
var echo_console: bool = true
## Write to user://logs. Disabled during tests to keep the runs hermetic.
var write_file: bool = true

var _file: FileAccess = null
var _path: String = ""
var _warns: int = 0
var _errors: int = 0
var _start_ms: int = 0


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	if not OS.is_debug_build():
		min_level = Level.INFO
	if write_file:
		_open_file()
	# THE GAME'S NAME IS NOT THIS FILE'S TO KNOW. It read the literal `Gulistan` until T1.2,
	# which is exactly the leak docs/TEMPLATE.md describes: the layer that depends on nothing
	# had a game baked into it. Both the banner and the log file name now come from
	# project.godot through GameConfig.
	# AND WHICH BASE IT IS BUILT ON. A bug report from a forked game is unanswerable without it:
	# the game's own version says nothing about which template fix it already has. TemplateVersion
	# is the same kind of dependency GameConfig is — a pure reader of project.godot that depends on
	# nothing — so the one edge this file allows itself is not widened by a second one.
	info("boot", "%s %s | base %s | Godot %s | %s | debug=%s" % [
		GameConfig.game_name(),
		ProjectSettings.get_setting("application/config/version", "?"),
		TemplateVersion.current(),
		Engine.get_version_info().get("string", "?"),
		DisplayServer.get_name(),
		str(OS.is_debug_build()),
	])


func _exit_tree() -> void:
	info("boot", "Session ended after %.1fs — %d warnings, %d errors" % [
		(Time.get_ticks_msec() - _start_ms) / 1000.0, _warns, _errors,
	])
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


## True if a message at this level would actually be recorded.
func enabled(level: Level) -> bool:
	return level >= min_level


## NO CALLER, and deliberately: TRACE is one rung of a five-rung ladder, and `min_level` can be
## set to it. Nothing in this template logs that finely — the finest thing it has to say is a
## DEBUG line — but a game that wants per-frame detail needs the rung to exist to select it.
## Deleting the bottom of a level ladder because the demo does not reach it is the wrong cut.
func trace(category: String, message: String) -> void:
	_write(Level.TRACE, category, message)


func debug(category: String, message: String) -> void:
	_write(Level.DEBUG, category, message)


func info(category: String, message: String) -> void:
	_write(Level.INFO, category, message)


## A recoverable problem. The game continues but something is not as intended.
func warn(category: String, message: String) -> void:
	_warns += 1
	_write(Level.WARN, category, message)
	push_warning("[%s] %s" % [category, message])


## A real failure. Also raised to the engine so it appears in the editor's error list.
func error(category: String, message: String) -> void:
	_errors += 1
	_write(Level.ERROR, category, message)
	push_error("[%s] %s" % [category, message])


## Number of warnings and errors so far this session. The smoke test asserts this is zero.
func tally() -> Vector2i:
	return Vector2i(_warns, _errors)


func _write(level: Level, category: String, message: String) -> void:
	if level < min_level:
		return
	var line: String = "%s [%s] [%-9s] %s" % [
		Time.get_time_string_from_system(), _NAMES[level], category, message,
	]
	if echo_console:
		print(line)
	if _file != null:
		_file.store_line(line)
		if level >= Level.WARN:
			_file.flush()


func _open_file() -> void:
	if DirAccess.make_dir_recursive_absolute(LOG_DIR) != OK:
		return
	_rotate()
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "-")
	_path = "%s/%s_%s.log" % [LOG_DIR, GameConfig.game_slug(), stamp]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		push_warning("Log could not open %s (%s)" % [_path, error_string(FileAccess.get_open_error())])


## Keep only the newest MAX_FILES logs so the folder cannot grow without bound.
func _rotate() -> void:
	var dir: DirAccess = DirAccess.open(LOG_DIR)
	if dir == null:
		return
	var logs: Array[String] = []
	for name: String in dir.get_files():
		if name.ends_with(".log"):
			logs.append(name)
	logs.sort()
	while logs.size() >= MAX_FILES:
		var oldest: String = logs.pop_front()
		dir.remove(oldest)
