class_name GroundSurface
extends RefCounted
## What a piece of geometry is MADE OF, as far as anything that walks on it is concerned.
## A pure query over node metadata, with no node, no physics and no state of its own.
##
##     metadata/surface = &"gravel"     on a StaticBody3D, or on any ancestor of one
##
## WHY METADATA AND NOT A COMPONENT, A GROUP OR AN ENUM
## A component per floor tile is a node per floor tile. A group is a flat namespace shared with
## `navmesh_source` and everything else, so a typo becomes a second surface silently. An enum
## would put the list of surfaces in ENGINE CODE — and `check_boundary` fails the build on a
## file under `src/` that names demo content, which a surface authored into an area is. One
## metadata key is the only one of the four where adding `sand` is content and nothing else.
##
## WHY IT WALKS UP THE TREE. A raycast hands back the collider it hit, which is the body, not
## the mesh, and an area's ground is usually one body under a Terrain root. Inheriting from the
## nearest tagged ancestor means an area tags `Terrain` once and overrides the two floors that
## differ — the shape a stylesheet has, for the reason a stylesheet has it.
##
## WHY AN UNTAGGED SURFACE IS "" AND NOT A DEFAULT NAME. A default would be a surface the game
## never authored, sounding exactly like one it did, which is gotcha 2 in miniature. "" is a
## legal answer meaning "this game did not say", and the one consumer says so out loud rather
## than falling back — the same treatment an area with no `AreaDef` gets.
##
## OWNS: the metadata key, and how a node resolves to a surface name.
## MUST NOT: know any surface name, or what a surface SOUNDS like, feels like or costs to cross.

## The one place this key is spelled. Documented in `AUTHORING.md` § Tag the ground you walk on.
const META: StringName = &"surface"
## What "this game did not say" is called. Never a name a game could author.
const NONE: StringName = &""


## The surface a node stands for: its own tag, or the nearest tagged ancestor's, or NONE.
## Takes an untyped `Node` because a raycast's collider is a `Node3D` and a test's fixture is
## whatever is cheapest to build; neither is a contract worth narrowing.
static func of_node(node: Node) -> StringName:
	var walker: Node = node
	while walker != null:
		var tagged: StringName = _tag_on(walker)
		if tagged != NONE:
			return tagged
		walker = walker.get_parent()
	return NONE


## True when anything in this node's line has been tagged. Distinct from comparing against NONE
## at the call site only in that it says what it means.
static func is_tagged(node: Node) -> bool:
	return of_node(node) != NONE


## One node's own tag, ignoring its ancestors. Authored as a StringName in a `.tscn`, but a
## String is accepted because that is what the inspector's metadata editor writes — read
## through an explicit branch rather than `str()`, which would turn a stray Vector3 into a
## surface named "(0, 0, 0)".
static func _tag_on(node: Node) -> StringName:
	if not node.has_meta(META):
		return NONE
	var raw: Variant = node.get_meta(META)
	# Assigned into a typed local rather than passed straight on: `is` does NOT narrow a
	# Variant in GDScript, so `StringName(raw)` inside the branch is a parse error under
	# warnings-as-errors. The local is where the cast is allowed to happen.
	if raw is StringName:
		var named: StringName = raw
		return named
	if raw is String:
		var text: String = raw
		return StringName(text)
	Log.warn("world", "metadata/%s on '%s' is not a name" % [META, node.name])
	return NONE
