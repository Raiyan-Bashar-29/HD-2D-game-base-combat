class_name AttackTokens
extends RefCounted
## Foes that take turns (C10.27): at most `max_attackers` field foes swing at one target at once.
##
## IN PLAIN WORDS: before a foe whose brain sets `max_attackers` starts a swing, it asks for a
## token on its target. With one, it swings; it gives the token back when its swing ends, or when
## it falls or leaves. Without one, it holds on a ring around the target (`ring_spot`), spread by
## angle so the waiting foes surround it, until a token is free.
##
## OWNS: who holds a token on whom.
## MUST NOT: move a foe or start its swing (`ActionEnemy` does).

## Target instance id -> the holders' instance ids.
static var _held: Dictionary[int, Array] = {}


## True when `holder` may swing at `target`: it holds a token, or one of the `most` is free.
static func take(holder: Node, target: Node, most: int) -> bool:
	if most <= 0 or target == null:
		return true
	var key: int = target.get_instance_id()
	var before: Array = _held[key] if _held.has(key) else []
	var holders: Array = before.filter(func(id: int) -> bool:
		var node: Node = instance_from_id(id) as Node
		return node != null and is_instance_valid(node) and node.is_inside_tree())
	_held[key] = holders
	if holders.has(holder.get_instance_id()):
		return true
	if holders.size() >= most:
		return false
	holders.append(holder.get_instance_id())
	return true


## `holder` gives back any token it holds.
static func release(holder: Node) -> void:
	for key: int in _held:
		_held[key].erase(holder.get_instance_id())


## Where a foe without a token waits: on a ring `radius` from `target`, at an angle set by `who`.
static func ring_spot(target: Node3D, who: Node, radius: float) -> Vector3:
	var angle: float = float(who.get_instance_id() % 360) * TAU / 360.0
	return target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
