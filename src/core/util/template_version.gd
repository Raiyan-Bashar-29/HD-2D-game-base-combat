class_name TemplateVersion
extends RefCounted
## What the BASE says about itself — the one fact a fork needs in order to receive a later fix.
##
## WHY THIS IS NOT `GameConfig`
## `GameConfig` reads the handful of values a CONSUMING GAME sets: its name, its description, its
## first area. This reads the one value a consuming game must NOT set. `docs/NEW_GAME.md` tells a
## forker to reset `application/config/version` to `0.0.1` on day one, which is correct and is
## exactly why the template cannot state its own version there — after one fork that field means
## the GAME's version and nothing remembers which base it came from. Two facts, two settings, and
## the header of `GameConfig` says "the values a game author writes once", so putting the opposite
## kind of value in it would have made that sentence false rather than made this file unnecessary.
##
## WHY A PROJECT SETTING RATHER THAN A CONSTANT IN THIS FILE
## A `const` here would be invisible to a fork that has diverged: reading it means opening a file
## under `src/`, and the whole point of `docs/UPGRADING.md` is that a game does not read `src/`.
## `[template] base/version` sits in `project.godot` beside `[game]`, which is already the file a
## fork opens, and it survives a merge as a text line a human can see conflict.
##
## THE COMPATIBILITY PROMISE THIS ENCODES, stated in full in `docs/UPGRADING.md`: the MAJOR
## number changes when a game's own files must change, the MINOR when the base gains something a
## game may ignore, the PATCH when nothing a game wrote is affected. `same_major_as()` is that
## promise as a function, so a consuming game can refuse a merge it is not ready for.
##
## OWNS: reading the template's own version out of project.godot, and comparing two of them.
## MUST NOT: know the game's version, gate anything at runtime, or grow a compatibility TABLE.
## A table would be a list of exceptions to the promise, and the promise is the product.

## Written by the template, never by a game. `docs/UPGRADING.md` is the contract it names.
const SETTING: String = "template/base/version"
## An honest answer for a tree that predates this setting, and it sorts BELOW every real
## version, so a fork that merged before T4 compares as older rather than as newer.
const UNKNOWN: String = "0.0.0"
const PART_COUNT: int = 3


## The version this tree of the template IS. Always three integers; see `_parts()`.
static func current() -> String:
	var raw: Variant = ProjectSettings.get_setting(SETTING, "")
	var value: String = str(raw)
	return value if is_semver(value) else UNKNOWN


static func major() -> int:
	return _parts(current())[0]


static func minor() -> int:
	return _parts(current())[1]


static func patch() -> int:
	return _parts(current())[2]


## Three dot-separated integers, nothing else. Deliberately stricter than semver proper: this
## project has no pre-release channel and a suffix nobody produces is a branch nobody tests.
static func is_semver(value: String) -> bool:
	var pieces: PackedStringArray = value.split(".")
	if pieces.size() != PART_COUNT:
		return false
	for piece: String in pieces:
		if not piece.is_valid_int() or piece.begins_with("-"):
			return false
	return true


## The promise, as a question a fork can ask before it merges: may I take this without editing
## my own files? A DIFFERENT major says no, and says it before the merge rather than after.
static func same_major_as(other: String) -> bool:
	return _parts(current())[0] == _parts(other)[0]


## Negative if `current()` is older than `other`, positive if newer, zero if equal. An
## unparseable version reads as UNKNOWN, so it is older than everything and never newer.
static func compare_to(other: String) -> int:
	var mine: PackedInt32Array = _parts(current())
	var theirs: PackedInt32Array = _parts(other)
	for index: int in PART_COUNT:
		if mine[index] != theirs[index]:
			return mine[index] - theirs[index]
	return 0


## Always returns three numbers, so every caller above can index without a guard.
static func _parts(value: String) -> PackedInt32Array:
	var text: String = value if is_semver(value) else UNKNOWN
	var found: PackedInt32Array = PackedInt32Array()
	for piece: String in text.split("."):
		found.append(piece.to_int())
	return found
