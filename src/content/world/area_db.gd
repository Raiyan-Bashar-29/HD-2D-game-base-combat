class_name AreaDb
extends RefCounted
## Every AreaDef in the project, found by scanning data/areas and cached by id.
##
## THE SCAN LIVES IN `ContentScan`, NOT HERE — T3.1, which this file's header was the evidence
## for. It said five copies of the same thirty lines is five places to fix a scan bug, and
## that the arithmetic had changed even though WP-08's reasoning had not. Both held: WP-08 was
## right that a base holding the CACHE would cost every accessor its type, and wrong only in
## assuming the cache was the duplicated part. It was the SCAN. What remains here is the typed
## façade — the content root, the cache, and `area()` returning an `AreaDef` with no cast at
## any call site.
##
## THE ID HAS NO PREFIX, unlike `item/` and `quest/`. See `area_def.gd`'s header: an area id is
## already a public identifier, because it is a folder name, and prefixing it here would put a
## translation table between this registry and `Director`. `ContentScan.into()` takes the
## prefix as an argument for exactly this reason; an empty one is a legitimate catalogue.
##
## Everything else is ADR-0006 verbatim: a scan is the only option where dropping a .tres in a
## folder is the entire act, a hand-maintained list rots, and a generated manifest fails
## SILENTLY when someone forgets to regenerate it.
##
## OWNS: the area content root, caching area definitions by id, and reporting what is wrong.
## MUST NOT: know whether an area is discovered, load an area scene, or touch an autoload.
## Problems are RETURNED, never logged, so tools/check_content.gd can use this class under
## `--script`.

const AREA_DIR: String = "res://data/areas"

## The directory actually scanned. A CONTENT ROOT rather than a constant, for the reason every
## other registry has one: a game may keep its areas somewhere else, and the test fixtures point
## this at a temp directory so the map can be proved with no authored content on disk at all.
static var content_dir: String = AREA_DIR

static var _by_id: Dictionary[StringName, AreaDef] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The definition for an area id, or null. Null is the ordinary answer for an area a game has
## not put on its map, not an error: an area with no def is simply not somewhere you can see or
## travel to, which is a legitimate thing for a side room to be.
static func area(area_id: StringName) -> AreaDef:
	_ensure_loaded()
	if not _by_id.has(area_id):
		return null
	return _by_id[area_id]


static func has(area_id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(area_id)


static func all() -> Dictionary[StringName, AreaDef]:
	_ensure_loaded()
	return _by_id


## Every mapped area id, sorted. THROUGH `String`, never `Array[StringName].sort()`, which
## orders by the StringName's internal handle and not alphabetically — gotcha 33, measured in
## WP-09 where two ids came back reversed with one failing assertion as the only trace. A map
## and an assertion both need a stable order out of a Dictionary that has none.
static func ids() -> Array[StringName]:
	_ensure_loaded()
	var out: Array[StringName] = []
	for area_id: StringName in _by_id:
		out.append(area_id)
	out.sort_custom(_before)
	return out


static func _before(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


static func count() -> int:
	_ensure_loaded()
	return _by_id.size()


static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


## rescan() AND NOT reload(). `Script` declares `reload()`, and a GDScript identifier IS the
## script object, so `AreaDb.reload()` would dispatch to the native method and silently reset
## every static variable in this file, `content_dir` included. See gotcha 17.
static func rescan() -> void:
	_by_id.clear()
	_problems = PackedStringArray()
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_problems = ContentScan.into(content_dir, "", AreaDef, "an AreaDef", "area", _by_id)
