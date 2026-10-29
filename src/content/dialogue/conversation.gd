class_name Conversation
extends ContentEntry
## One conversation, as authored data. The narrative counterpart of `ItemDefinition`.
##
## THE ID IS THE FILE NAME, exactly as for items: `data/dialogue/gardener.tres` must declare
## `id = &"talk/gardener"`. `DialogueDb` refuses any mismatch and names both values, so a
## copy-paste slip is a loud startup problem rather than a conversation that silently never
## happens. The `talk/` prefix keeps a save file self-describing.
##
## NODES ARE AN ORDERED ARRAY, not a dictionary, and that is load-bearing. A conversation is
## authored and read top to bottom: the runner starts at the first node whose condition passes
## and, when a node is skipped, falls through to the next in order. That makes the common shape
## - "if we have met, say this, otherwise say that" - two nodes in sequence with no explicit
## wiring at all. Lookup by id still happens, for `next_node` and `target_node`, but order is
## what a writer actually edits, and an array is what diffs cleanly.
##
## OWNS: the immutable data of one conversation, and validating its own shape.
## MUST NOT: run itself, read a flag, or know that a UI exists. It must also not touch an
## autoload - tools/check_content.gd loads this class under `--headless --script`, where
## autoload identifiers do not resolve.

## `id` is inherited from `ContentEntry`; for this catalogue it is `talk/` plus this file name.
## In authored order. The runner enters at the first node whose condition passes.
@export var nodes: Array[DialogueNode] = []


## The node with this id, or null. A dangling `next_node` yields null rather than a crash; the
## runner logs it and ends the conversation, which is recoverable, unlike a hang.
func node(node_id: StringName) -> DialogueNode:
	for entry: DialogueNode in nodes:
		if entry != null and entry.node_id == node_id:
			return entry
	return null


func has_node(node_id: StringName) -> bool:
	return node(node_id) != null


## Every content error in this conversation, INCLUDING dangling links. A `next_node` naming a
## node that does not exist is the single most likely authoring mistake in a format like this,
## and it is invisible until a player happens to walk that branch. Checking it at validation
## time is the whole reason this method resolves ids rather than only inspecting fields.
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if nodes.is_empty():
		found.append("%s (%s) has no nodes" % [resource_path, id])
	var seen: Dictionary[StringName, bool] = {}
	for entry: DialogueNode in nodes:
		if entry == null:
			found.append("%s has an empty node slot" % id)
			continue
		if seen.has(entry.node_id):
			found.append("%s has two nodes called '%s'" % [id, entry.node_id])
		seen[entry.node_id] = true
		found.append_array(entry.problems(id))
	found.append_array(_dangling_links())
	return found


func _dangling_links() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: DialogueNode in nodes:
		if entry == null:
			continue
		if entry.next_node != &"" and not has_node(entry.next_node):
			found.append("%s/%s leads to '%s', which does not exist" % [
				id, entry.node_id, entry.next_node,
			])
		for choice: DialogueChoice in entry.choices:
			if choice != null and choice.target_node != &"" and not has_node(choice.target_node):
				found.append("%s/%s has a choice leading to '%s', which does not exist" % [
					id, entry.node_id, choice.target_node,
				])
	return found
