class_name PowerKitDb
extends RefCounted
## Every `PowerKit` under `data/powers/`, by its `kit_id` (C9.6b). `PassiveDb`'s shape.
##
## IN PLAIN WORDS: a kit file that no fighter and no piece of gear points at was never loaded,
## so a mistake in it was never reported. This loads every kit file, checks each, and finds
## one by id. The file `data/powers/<name>.tres` must declare `kit_id` `kit/<name>`. A test
## points `content_dir` at a scratch directory and calls `rescan()`.
##
## OWNS: the catalogue of kits, and two checks a kit cannot make alone: its id matches its
## file name, and a form that drains a pool has that pool given by the kit (`max_<pool>`).
## MUST NOT: know who has a kit equipped, or load anything outside `content_dir`.

const KIT_DIR: String = "res://data/powers"
const ID_PREFIX: String = "kit/"
const MAX_PREFIX: String = "max_"

static var content_dir: String = KIT_DIR
static var _by_id: Dictionary[StringName, PowerKit] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func kit(kit_id: StringName) -> PowerKit:
	_ensure_loaded()
	if not _by_id.has(kit_id):
		return null
	return _by_id[kit_id]


## Every kit id, in file order.
static func ids() -> Array[StringName]:
	_ensure_loaded()
	return _by_id.keys()


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


static func rescan() -> void:
	_by_id.clear()
	_problems = PackedStringArray()
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# No directory is no content, not an error: the stripped template has none.
	if not DirAccess.dir_exists_absolute(content_dir):
		return
	for path: String in ContentScan.resource_paths(content_dir):
		var found: PowerKit = ResourceLoader.load(path) as PowerKit
		if found == null:
			_problems.append("%s is not a PowerKit" % path)
			continue
		var required: StringName = StringName(ID_PREFIX + path.get_file().get_basename())
		if found.kit_id != required:
			_problems.append("%s declares kit_id '%s' but its file name requires '%s'"
				% [path, found.kit_id, required])
			continue
		_problems.append_array(found.problems(path))
		_problems.append_array(_pool_problems(path, found))
		_by_id[found.kit_id] = found


# A form that drains a pool the kit never gives would end the moment it is entered.
static func _pool_problems(path: String, found: PowerKit) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var given: Array[StringName] = []
	for bonus: StatModifier in found.stat_bonuses:
		if bonus != null:
			given.append(bonus.stat)
	for entry: Power in found.powers:
		var form: FormMechanism = (entry.mechanism as FormMechanism) if entry != null else null
		if form == null or form.drain_pool == &"":
			continue
		if not given.has(StringName(MAX_PREFIX + form.drain_pool)):
			out.append("%s power %s drains the pool %s, which the kit does not give"
				% [path, entry.power_id, form.drain_pool])
	return out
