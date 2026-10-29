class_name InputLock
extends RefCounted
## A set of named holds on one input consumer. A system asks for a hold with `lock()`, gives
## it back with `release()`, and input stays suspended while anybody still holds one.
##
## WHY A BOOLEAN DOES NOT WORK, WHICH THIS PROJECT LEARNED THE EXPENSIVE WAY
## `PlayerController` carried `_input_locked: bool` behind `set_input_locked(bool)`. That is
## fine with exactly one caller and wrong with two. WP-01 added the second: dialogue locks the
## player, a climb starts and finishes inside the conversation, the climb's own
## `set_input_locked(false)` clears the dialogue's lock, and the player strolls away
## mid-sentence. Nothing errors. Nothing logs. It just looks like a physics bug.
##
## TOKENS, NOT A COUNT. A counter fails the other way round: a system that locks twice and
## releases once strands the lock forever with nothing to point at. A NAMED token is
## idempotent, so a doubled `dialogue_started` costs nothing, and `holders()` can name whoever
## is still holding when something does go wrong. A count cannot tell you that.
##
## OWNS: the set of held tokens, and nothing else.
## MUST NOT: read input, know what input is, or know which system any token belongs to. It is
## a set of names with an opinion about how they are surrendered.

var _tokens: Array[StringName] = []


## Take a hold. Harmless to call again with a token already held - that is the point.
func lock(token: StringName) -> void:
	if token == &"" or _tokens.has(token):
		return
	_tokens.append(token)


## Give back one hold. Releasing a token nobody holds is a no-op, not an error: teardown
## paths legitimately release defensively without knowing whether they ever locked.
func release(token: StringName) -> void:
	_tokens.erase(token)


func is_locked() -> bool:
	return not _tokens.is_empty()


func holds(token: StringName) -> bool:
	return _tokens.has(token)


## Who is still holding, for logs and for tests. A copy, so a caller cannot pick the lock by
## mutating the list it was handed.
func holders() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_tokens)
	return out


func count() -> int:
	return _tokens.size()


## Drop every hold at once. For teardown only - a scene change or a despawn. Never call this
## to "fix" a stuck lock: a stuck lock is a system that failed to release, and `holders()`
## names it.
func clear() -> void:
	_tokens.clear()
