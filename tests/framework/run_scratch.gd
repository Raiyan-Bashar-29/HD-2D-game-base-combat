class_name RunScratch
extends RefCounted
## The one directory a suite run may write, named for the process that owns it.
##
## THE PROBLEM THIS CLOSES, T6.13. `user://` is keyed on the project's `config/name`, so every
## worktree on a machine shares it, and every scratch path the suite used was a fixed name
## under it. `SaveFixture` EMPTIES its directory on every `activate()` and `deactivate()`, and
## `Fixtures` rewrites its content on every case, so two suites running at once in two worktrees
## deleted each other's slots and fixtures mid-case. Measured with a private `APPDATA`, on the
## unchanged tree: two suites started 0.3s apart failed 15 and 8, in runs that each pass alone.
##
## NAMED BY THE PROCESS ID, because no two LIVE processes share one, so two concurrent runs can
## never share a directory. A new run handed a dead run's pid removes that directory in `begin()`.
##
## BUT THE PID DOES NOT SAY WHETHER A RUN IS ALIVE, AND THE FIRST VERSION ASSUMED IT DID. It asked
## `OS.is_process_running(pid)`, and on Windows that answers FALSE for every process this one did
## not create itself. Measured: explorer's pid answered false, a child from `OS.create_process`
## answered true. So each run's `begin()` pruned every other live run's directory, and a suite
## started 6s after another cost the first three failures in `options_test`, whose settings and
## bindings writes found their directory gone. Liveness is a HEARTBEAT instead: the runner calls
## `beat()` before every case, and a directory is pruned only when its heartbeat is older than
## `STALE_SECONDS`. That needs nothing from the OS, and a directory with no heartbeat yet is kept:
## a directory is only ever deleted on positive evidence that its run has stopped.
##
## REMOVED AT THE END, PRUNED AT THE START. `finish()` removes this run's directory. A run that
## crashed or was killed never gets there, so a later `begin()` removes it once its heartbeat is
## stale. Only a directory named by a number is ever pruned: anything else under `PARENT` is not
## this file's to delete.
##
## THE OLD FIXED PATHS ARE LEFT ALONE, deliberately. `user://test_saves` and its siblings may
## still be in use by a suite in a worktree on an older base, and deleting them from here would
## be exactly the defect this closes.
##
## OWNS: the per-run scratch directory, its name, its heartbeat, and removing it and dead ones.
## MUST NOT: know what a case puts in it. `SaveFixture` and `Fixtures` name their own corners.

const PARENT: String = "user://test_runs"
const HEARTBEAT: String = "heartbeat"
## How long a run may go between two cases before another run may take it for dead. Far above
## any one case, even on a machine running several suites at once.
const STALE_SECONDS: int = 900


## This run's directory. Everything a suite run writes is under it.
static func root() -> String:
	return root_for(OS.get_process_id())


static func root_for(pid: int) -> String:
	return "%s/%d" % [PARENT, pid]


## A path inside this run's directory.
static func path(relative: String) -> String:
	return root().path_join(relative)


## Before the first case: clear the dead runs' directories, then start this one empty.
static func begin() -> void:
	prune()
	remove_tree(root())
	DirAccess.make_dir_recursive_absolute(root())
	beat()


## Say this run is still alive. The runner calls it before every case.
static func beat() -> void:
	var file: FileAccess = FileAccess.open(path(HEARTBEAT), FileAccess.WRITE)
	if file != null:
		file.store_string(str(Time.get_unix_time_from_system()))
		file.close()


## After the last case.
static func finish() -> void:
	remove_tree(root())


## Remove every run directory in `parent` whose heartbeat is older than `stale_after` seconds,
## and answer which it removed. BOTH PARAMETERS EXIST FOR THE SUITE. A case cannot age a file, so
## it passes a negative `stale_after` to make a fresh heartbeat count as stale. And it passes a
## `parent` of its own, because a case that prunes the shared one with a doctored threshold
## deletes every concurrent run's directory, which an earlier version of that case did. Only
## `begin()` prunes the shared parent, and only with the real threshold.
static func prune(parent: String = PARENT, stale_after: int = STALE_SECONDS) -> PackedStringArray:
	var removed: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(parent):
		return removed
	var now: int = int(Time.get_unix_time_from_system())
	for folder: String in DirAccess.get_directories_at(parent):
		var run: String = parent.path_join(folder)
		var beat_file: String = run.path_join(HEARTBEAT)
		if not folder.is_valid_int() or folder.to_int() == OS.get_process_id():
			continue
		if not FileAccess.file_exists(beat_file):
			continue
		if now - FileAccess.get_modified_time(beat_file) <= stale_after:
			continue
		if remove_tree(run):
			removed.append(run)
	return removed


## Delete `path` and everything under it. Absent is already removed, and answers true.
static func remove_tree(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	for folder: String in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(folder))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	return DirAccess.remove_absolute(path) == OK
