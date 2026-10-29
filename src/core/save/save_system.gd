extends Node
## Save and load orchestration. Autoload `SaveSystem`.
##
## WHY IT WORKS THIS WAY
## The obvious design is one big save function that reaches into every system and reads its
## variables. That function becomes the god object: it has to know every system, so every new
## feature edits it, and it is the first file to hit a thousand lines. Instead this file knows
## NOTHING about game content. Systems register a pair of callables and own their own format.
##
## A system registers itself, usually in its _ready():
##     SaveSystem.register(&"clock", _collect_save, _apply_save)
##     func _collect_save() -> Dictionary: return {"day": day, "minute": minute}
##     func _apply_save(data: Dictionary, _from: int) -> void: day = DictRead.get_int(data, "day", 1)
##
## OWNS: slot files on disk, the file format, the schema version, atomic writes, migration, and
## which slot NUMBERS exist — including the autosave's, because a number's legality and its path
## are facts about the store.
## MUST NOT: know what any section contains, or decide WHEN a save happens. Adding a saveable
## system never edits this file, and neither does adding an occasion to save on: the autosave
## POLICY lives in `Autosave`, which calls `save_to_slot` like every other caller does.

## Where slot files live when nobody has said otherwise. Separate from `save_dir` below so that
## restoring the default is naming this rather than repeating the literal at every call site.
const DEFAULT_SAVE_DIR: String = "user://saves"
## How many slots the PLAYER may write. Every manual list iterates this, so the autosave slot
## below is outside all of them by construction rather than by a filter somebody has to
## remember to write in each screen.
const MAX_SLOTS: int = 6
## The autosave's slot, ONE PAST the manual six, and one past rather than one OF them so that
## slots 0..5 keep the numbers a player already knows and no save written before this existed
## changes meaning. An autosave that can overwrite a save the player made on purpose is the one
## thing an autosave must never be. This file owns only the fact that the number is legal and
## where it lands on disk; `Autosave` owns when it is written. See src/systems/autosave/.
const AUTOSAVE_SLOT: int = MAX_SLOTS
## Named rather than numbered: `slot_07.json` sitting beside six `slot_NN.json` files would read
## as a seventh manual slot to anyone who opened the folder, which is exactly what it is not.
const AUTOSAVE_FILE: String = "autosave.json"
## Bump when the envelope changes shape. Section contents are each system's own business.
const SCHEMA_VERSION: int = 1

## The directory `slot_path` builds on, and the ONE thing about the store that is not fixed.
##
## WHY THIS IS A `var` AND NOT THE `const` IT WAS. The suite has to write real files to assert
## what the loader does with them, and with a const it wrote them into the developer's REAL save
## directory — the last content root a test run could still reach, every other one being
## repointed by `tests/framework/fixtures.gd`. It cleaned up after itself, which is not the same
## as never having been there: a crashed run left slots behind, and a slot number the suite
## happens to use is a slot number a player may have filled.
##
## PUBLIC RATHER THAN TEST-ONLY, because the same seam is one a GAME may legitimately want — a
## portable build writing beside its executable rather than into `user://` — and a backdoor that
## exists for the suite and for nothing else is what `fixtures.gd`'s own header refuses to add.
## Assigning creates the directory, so no caller has to remember to.
var save_dir: String = DEFAULT_SAVE_DIR:
	set(value):
		save_dir = value
		_ensure_dir()

## What a slot's HEADER says beyond the stamp and the playtime: where it was saved, say. Called
## once per write, stored under `"header"`, and handed back by `slot_info`. A hook rather than a
## call because the answer lives above this layer, and `core` asking `Director` would point a
## dependency upward, which `tools/check_layers.gd` fails. Unset means no extras. ONE hook, not a
## list: `WorldMap` sets it, and a game wanting more returns a bigger Dictionary from its own.
var header_provider: Callable = Callable()

## Section version per participant, so a system can change its own format without forcing an
## envelope bump and without _migrate having to understand every other section. See ADR-0004.
## A stored section NEWER than this is refused in `load_from_slot`; an older one is the applier's
## to migrate — `tests/unit/save_recovery_test.gd` has the worked example.
var _versions: Dictionary[StringName, int] = {}
var _collectors: Dictionary[StringName, Callable] = {}
var _appliers: Dictionary[StringName, Callable] = {}
var _playtime: float = 0.0
var _busy: bool = false


func _ready() -> void:
	_ensure_dir()


## Create `save_dir` if it is not there. Called on boot AND from the setter, because a directory
## that only boot creates would leave a redirect pointing at nothing until the first write failed.
func _ensure_dir() -> void:
	if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
		Log.error("save", "Could not create %s" % save_dir)


func _process(delta: float) -> void:
	_playtime += delta


## Register a save participant. `collect` returns a Dictionary; `apply` takes one.
## Re-registering the same id replaces the previous pair, which makes hot-reload safe.
func register(id: StringName, collect: Callable, apply: Callable, version: int = 1) -> void:
	if not collect.is_valid() or not apply.is_valid():
		Log.error("save", "Participant '%s' passed an invalid callable" % id)
		return
	_collectors[id] = collect
	_appliers[id] = apply
	_versions[id] = maxi(1, version)
	Log.debug("save", "Participant registered: %s" % id)


## Drop a participant. Call this if the owning node is freed before the game ends.
func unregister(id: StringName) -> void:
	_collectors.erase(id)
	_appliers.erase(id)
	_versions.erase(id)


func slot_path(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return "%s/%s" % [save_dir, AUTOSAVE_FILE]
	return "%s/slot_%02d.json" % [save_dir, slot]


## Whether a slot number is the autosave's. Public so a screen can label a row and a policy can
## name its own slot without either of them re-deriving the arithmetic.
func is_autosave(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Read only the header of a slot, for the load menu. Never applies anything.
##
## EMPTY FOR ANY FILE `load_from_slot` WOULD REFUSE, not only one that does not parse: a version
## `_migrate` cannot rescue is as unloadable as broken JSON, and a header drawn for it offers a
## load that fails. So `has_slot` with an empty answer means DAMAGED — `SaveScreen` draws it so —
## and `latest_slot`, which is Continue, can never point at one.
func slot_info(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed: Dictionary = _read_json(slot_path(slot))
	if parsed.is_empty() or DictRead.get_int(parsed, "version", 0) not in range(1, SCHEMA_VERSION + 1):
		return {}
	parsed.erase("sections")
	return parsed


## The most recently written slot, or -1 if none has ever been written. This is what Continue
## means, and it is why the main menu can omit the row entirely on a first run.
##
## Compared on the stored `saved_utc` string, which sorts correctly because it is ISO-8601 and
## zero-padded. The FILE's modification time would be wrong the moment a save is copied between
## machines or restored from a backup, and it is not in the file the player can read.
func latest_slot() -> int:
	var best: int = -1
	var newest: String = ""
	# AUTOSAVE_SLOT + 1, not MAX_SLOTS. Continue means "the most recent save", and an autosave
	# the player cannot come back to is not an autosave. This is the one place the two ranges
	# differ, and the asymmetry is the policy: writing is manual-only, reading is everything.
	for slot: int in AUTOSAVE_SLOT + 1:
		var info: Dictionary = slot_info(slot)
		if info.is_empty():
			continue
		var when: String = DictRead.get_string(info, "saved_utc", "")
		if best < 0 or when > newest:
			best = slot
			newest = when
	return best


func save_to_slot(slot: int) -> Error:
	if _busy:
		Log.warn("save", "Save to slot %d ignored: another save is in flight" % slot)
		return ERR_BUSY
	if slot < 0 or slot > AUTOSAVE_SLOT:
		Log.error("save", "Slot %d out of range" % slot)
		return ERR_INVALID_PARAMETER
	_busy = true

	var sections: Dictionary = {}
	for id: StringName in _collectors:
		var collect: Callable = _collectors[id]
		var section: Variant = collect.call()
		if section is Dictionary:
			# Wrapped, not flat: the version travels with the data it describes.
			sections[String(id)] = {"v": _versions[id], "data": section}
		else:
			Log.error("save", "Participant '%s' returned %s, not a Dictionary" % [id, type_string(typeof(section))])

	var envelope: Dictionary = {
		"version": SCHEMA_VERSION,
		"saved_utc": Time.get_datetime_string_from_system(true, true),
		"playtime_seconds": snappedf(_playtime, 0.1),
		"sections": sections,
	}
	if header_provider.is_valid():
		envelope["header"] = header_provider.call()

	var err: Error = _write_atomic(slot_path(slot), JSON.stringify(envelope, "  "))
	_busy = false
	if err != OK:
		Log.error("save", "Slot %d write failed: %s" % [slot, error_string(err)])
		return err
	Log.info("save", "Slot %d written (%d sections)" % [slot, sections.size()])
	Events.game_saved.emit(slot)
	return OK


func load_from_slot(slot: int) -> Error:
	if not has_slot(slot):
		Log.warn("save", "Slot %d is empty" % slot)
		return ERR_FILE_NOT_FOUND

	var envelope: Dictionary = _read_json(slot_path(slot))
	if envelope.is_empty():
		return ERR_FILE_CORRUPT

	var version: int = DictRead.get_int(envelope, "version", 0)
	if version != SCHEMA_VERSION:
		envelope = _migrate(envelope, version)
		if envelope.is_empty():
			return ERR_FILE_CORRUPT

	_playtime = DictRead.get_float(envelope, "playtime_seconds", 0.0)
	var sections: Dictionary = DictRead.get_dict(envelope, "sections")

	# Apply in registration order, so a system that depends on an earlier one sees it ready.
	for id: StringName in _appliers:
		var key: String = String(id)
		if not sections.has(key):
			Log.debug("save", "Slot %d has no section for '%s' — leaving it at defaults" % [slot, key])
			continue
		var section: Variant = sections[key]
		if not (section is Dictionary):
			Log.error("save", "Section '%s' in slot %d is not a Dictionary" % [key, slot])
			continue
		var wrapped: Dictionary = section
		if not wrapped.has("v"):
			# Written before per-section versioning existed. Loud, then defaults, rather than
			# handing a differently-shaped payload to an applier that cannot recognise it.
			Log.warn("save", "Section '%s' predates section versioning - loading defaults" % key)
			continue
		var stored: int = DictRead.get_int(wrapped, "v", 1)
		if stored > _versions[id]:
			# The section-level twin of `_migrate`'s newer-build refusal, and it had none until
			# T6.1: every applier trusts its `from_version`, so a shape this build has never seen
			# would be applied as if current. A migration cannot be written for the future.
			Log.error("save", "Section '%s' is from a newer build (v%d > v%d) - loading defaults" % [key, stored, _versions[id]])
			continue
		var apply: Callable = _appliers[id]
		apply.call(DictRead.get_dict(wrapped, "data"), stored)

	Log.info("save", "Slot %d loaded (v%d, %.0fs played)" % [slot, version, _playtime])
	Events.game_loaded.emit(slot)
	return OK


func delete_slot(slot: int) -> Error:
	if not has_slot(slot):
		return ERR_FILE_NOT_FOUND
	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null:
		return ERR_CANT_OPEN
	return dir.remove(slot_path(slot).get_file())


## Total seconds of play in the current run, for the save header and the pause screen.
func playtime() -> float:
	return _playtime


func reset_playtime() -> void:
	_playtime = 0.0


## Write to a temporary file, then swap it into place. A crash mid-write therefore destroys
## the temporary file and leaves the previous save intact, instead of truncating it to zero.
func _write_atomic(path: String, text: String) -> Error:
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()

	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null:
		return ERR_CANT_OPEN
	if dir.file_exists(path.get_file()):
		var removed: Error = dir.remove(path.get_file())
		if removed != OK:
			return removed
	return dir.rename(temp.get_file(), path.get_file())


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error("save", "Cannot open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	Log.error("save", "%s is not valid save JSON" % path)
	return {}


## Upgrade an older save to the current schema. Returns {} if it cannot be rescued.
## Each version gets its own explicit step so migrations stay readable and testable.
func _migrate(envelope: Dictionary, from_version: int) -> Dictionary:
	if from_version <= 0:
		Log.error("save", "Save has no usable version field")
		return {}
	if from_version > SCHEMA_VERSION:
		Log.error("save", "Save is from a newer build (v%d > v%d)" % [from_version, SCHEMA_VERSION])
		return {}
	# No migrations needed yet: v1 is the first shipped schema. When v2 arrives, add
	# `if from_version == 1: ...` here, transform in place, and fall through.
	Log.info("save", "Migrated save from v%d to v%d" % [from_version, SCHEMA_VERSION])
	return envelope
