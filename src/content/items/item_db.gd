class_name ItemDb
extends RefCounted
## Every ItemDefinition in the project, found by scanning data/items and cached by id.
##
## THE SCAN LIVES IN `ContentScan`, NOT HERE — T3.1. This file is the typed façade over it:
## it owns the content root, the cache, and accessors that return `ItemDefinition` with no
## cast at any call site. `ContentScan.into()` fills `_by_id` in place, so the dictionary
## stays `Dictionary[StringName, ItemDefinition]` and non-negotiable #2 is untouched. Its
## header carries the measurement and the reason WP-08's verdict is not overturned by this.
##
## WHY A SCAN AND NOT A LIST
## docs/ARCHITECTURE.md's test is "adding the fiftieth item must not touch a single line of
## code". A hand-maintained registry fails that outright. A generated manifest fails it
## quietly, which is worse: a forgotten regeneration is indistinguishable from an item that
## was never added, and silent-wrong is the failure mode this project exists to prevent.
## A scan is the only option where dropping a .tres in a folder is the entire act.
##
## WHY STATIC AND NOT AN AUTOLOAD
## It holds no mutable game state, has no lifecycle, is never saved and needs no init order,
## so an autoload would need an ADR and buy nothing. Decisively: an autoload CANNOT be used
## by tools/check_content.gd, because autoload identifiers do not resolve under
## `--headless --script` - the validator would have to duplicate the very loading code it is
## meant to test. A static class is shared verbatim by the game, the tests and the tool.
##
## WHY A STATIC BASE CLASS IS NOT THE SHAPE, measured under 4.7.2 and now gotcha 37: a
## `static var` declared on a base class is ONE storage shared by every subclass. Two probe
## subclasses bumping a base counter reported `A.shared=3 B.shared=3`. So five registries
## inheriting a base would have shared one `_by_id` and one `content_dir`, and the fixtures'
## redirection would have pointed all five at the same folder. The shared part had to be a
## FUNCTION, and it is.
##
## OWNS: the item content root, caching definitions by id, and reporting what is wrong.
## MUST NOT: hold inventory state, know who carries anything, or touch an autoload. Problems
## are RETURNED, never logged, for the reason above.

const ITEM_DIR: String = "res://data/items"

## The directory actually scanned. A CONTENT ROOT rather than a constant: a game may keep its
## items somewhere else, and the test fixtures point it at a temp directory so this registry
## can be proved with no authored content on disk at all. Restore it to ITEM_DIR and rescan().
static var content_dir: String = ITEM_DIR
const ID_PREFIX: String = "item/"

static var _by_id: Dictionary[StringName, ItemDefinition] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The definition for an id, or null. A typo yields null rather than a crash; the caller
## decides whether that is a refusal or an error.
static func definition(item_id: StringName) -> ItemDefinition:
	_ensure_loaded()
	if not _by_id.has(item_id):
		return null
	return _by_id[item_id]


static func has(item_id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(item_id)


static func all() -> Dictionary[StringName, ItemDefinition]:
	_ensure_loaded()
	return _by_id


static func count() -> int:
	_ensure_loaded()
	return _by_id.size()


## Every content error found while scanning. Empty means the catalogue is sound.
static func problems() -> PackedStringArray:
	_ensure_loaded()
	return _problems


## Static state survives a scene reload and a new game, which is right for immutable content
## and wrong while authoring or testing. Tests and the validator call this.
##
## rescan() AND NOT reload(). `Script` declares `reload()`, and a GDScript identifier IS the
## script object, so `ItemDb.reload()` dispatches to the native method and silently resets
## every static variable in this file, `content_dir` included. That is not hypothetical: it is
## exactly what this registry's method did for four packages. See gotcha 17.
static func rescan() -> void:
	_by_id.clear()
	_problems = PackedStringArray()
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_problems = ContentScan.into(
		content_dir, ID_PREFIX, ItemDefinition, "an ItemDefinition", "item", _by_id)
