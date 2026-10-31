class_name SaveBlockers
extends RefCounted
## The moments a game has marked unsafe to save in (T7.2). `SaveSystem.blockers` is the one list.
##
## IN PLAIN WORDS: a system that knows the world is mid-something (a cutscene, a boss door, a
## battle in a game that has one) adds a blocker once: a callable that returns a localization key
## saying why saving is refused right now, or "" when it is fine. While any blocker answers with a
## key, every save is refused, the player's own, the autosave and a debug one alike, and
## `refusal()` names the reason so a screen can tell the player. Loading is never refused.
##
## WHY A CALLABLE AND NOT A FLAG SET AND CLEARED. A flag set on the way in and cleared on the way
## out stays set for ever the first time the way out is missed: a node freed mid-cutscene, a
## battle ended by a load. A callable asks the question when a save is attempted, and one whose
## owner has been freed is dropped, so a blocker can never refuse for ever.
##
## OWNS: the list of blockers and the first reason among them.
## MUST NOT: decide when saving is unsafe (each blocker does), write or refuse a file
## (`SaveSystem` does), or show anything to the player (a screen does).

var _blockers: Dictionary[StringName, Callable] = {}


## Add or replace the blocker named `id`. Re-adding the same id replaces the callable, as
## `SaveSystem.register` does, so hot-reload and a re-entered node are safe.
func add(id: StringName, reason: Callable) -> void:
	if not reason.is_valid():
		Log.error("save", "Blocker '%s' passed an invalid callable" % id)
		return
	_blockers[id] = reason


## Drop a blocker. Call it when the owning node leaves the tree; a freed owner is dropped anyway.
func remove(id: StringName) -> void:
	_blockers.erase(id)


## Why saving is refused right now: the first blocker's non-empty key, in the order they were
## added, or "" when nothing refuses.
func refusal() -> String:
	for id: StringName in _blockers.keys():
		var reason: Callable = _blockers[id]
		if not reason.is_valid():
			_blockers.erase(id)
			continue
		var key: Variant = reason.call()
		if key is String and not (key as String).is_empty():
			return key as String
	return ""
