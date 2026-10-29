class_name DialogueDb
extends RefCounted
## Every Conversation in the project, found by scanning data/dialogue and cached by id.
##
## THE SCAN LIVES IN `ContentScan`, NOT HERE — T3.1. This file is the typed façade over it:
## the content root, the cache, and `conversation()` returning a `Conversation` with no cast
## at any call site. Before T3.1 this file carried its own copy of the scan and called
## `ItemDb.resource_paths()` for the .remap handling, which needed a paragraph of header to
## explain; both are now one function with the name of the job it does.
##
## THE SAME REGISTRY AS ItemDb, AND DELIBERATELY SO. ADR-0006 settled the argument for items:
## a scan is the only option where dropping a .tres in a folder is the entire act, a
## hand-maintained list rots, and a generated manifest fails SILENTLY when someone forgets to
## regenerate it. None of that reasoning is about items. Conversations are the second content
## type and they get the identical treatment, including the id-equals-filename rule.
##
## OWNS: the dialogue content root, caching conversations by id, and reporting what is wrong.
## MUST NOT: run a conversation, hold conversational state, or touch an autoload. Problems are
## RETURNED, never logged, so tools/check_content.gd can use this class under `--script`.

const DIALOGUE_DIR: String = "res://data/dialogue"

## The directory actually scanned. A CONTENT ROOT rather than a constant: a game may keep its
## conversations somewhere else, and the test fixtures point it at a temp directory so this
## registry can be proved with no authored content on disk at all. Restore it and rescan().
static var content_dir: String = DIALOGUE_DIR
const ID_PREFIX: String = "talk/"

static var _by_id: Dictionary[StringName, Conversation] = {}
static var _problems: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## The conversation for an id, or null. A typo yields null rather than a crash; the caller
## decides whether that is a refusal or an error.
static func conversation(talk_id: StringName) -> Conversation:
	_ensure_loaded()
	if not _by_id.has(talk_id):
		return null
	return _by_id[talk_id]


static func has(talk_id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(talk_id)


static func all() -> Dictionary[StringName, Conversation]:
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
## rescan() AND NOT reload() — gotcha 17, and item_db.gd's header has the full story.
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
		content_dir, ID_PREFIX, Conversation, "a Conversation", "conversation", _by_id)
