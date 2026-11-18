class_name CombatNames
extends RefCounted
## The words the combat screens show for a pool, an element or a tag (C10.4).
##
## IN PLAIN WORDS:
##   - A pool reads from its `combat.pool.<id>` row ("MP", "Focus"), else its id in capitals,
##     as before, so a game's own pool still reads with no row.
##   - An element or tag, as `weak_to` and hits name them, reads from its `combat.element.<id>`
##     row, else its `combat.tag.<id>` row, else a row keyed by the bare id (older games), else
##     the id itself.
##
## OWNS: which row names a pool, an element or a tag, and the fallbacks.
## MUST NOT: hold state, or name a game's pools, elements or tags.

const POOL_PREFIX: String = "combat.pool."
const ELEMENT_PREFIX: String = "combat.element."
const TAG_PREFIX: String = "combat.tag."


## The name of the pool `id`.
static func pool(id: StringName) -> String:
	var key: String = POOL_PREFIX + String(id)
	var shown: String = TranslationServer.translate(key)
	return String(id).to_upper() if shown == key else shown


## The name of the element or tag `id`.
static func mark(id: StringName) -> String:
	for prefix: String in [ELEMENT_PREFIX, TAG_PREFIX]:
		var key: String = prefix + String(id)
		var shown: String = TranslationServer.translate(key)
		if shown != key:
			return shown
	return TranslationServer.translate(String(id))
