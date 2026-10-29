class_name DialogueNode
extends Resource
## One line of a conversation: who says it, what they say, what it changes, and where it goes.
##
## ONE CONDITION AND ONE EFFECT, deliberately. A node that fails its condition is SKIPPED and
## the runner falls through to the next in the array, which is what makes an authored
## conversation read top to bottom like a script rather than like a graph. Lists of conditions
## would need an AND/OR and therefore a parser, which is the line this format does not cross.
## When a real conversation genuinely needs two effects, the seam is `apply_effect` in the
## runner and one field here becoming an array - no authored .tres is invalidated by that.
##
## THE EFFECT FIRES ON ARRIVAL, not on departure, so a node has the same consequence however
## the player reached it. A choice therefore carries no effect of its own.
##
## OWNS: its text, its speaker, its condition, its effect, and where it leads.
## MUST NOT: read a flag, write a flag, or know how it is displayed. It is data; the runner
## in src/systems/dialogue does all four. It must also not touch an autoload, for the reason
## in dialogue_choice.gd.

## Unique within its conversation. Referenced by `next_node` and by a choice's `target_node`.
@export var node_id: StringName = &""
## Localization key for the speaker's name. Never raw text.
@export var speaker_key: String = ""
## Localization key for the line itself.
@export var text_key: String = ""
## Where to go when this line is finished and there are no choices. Empty ends the
## conversation; the runner does NOT fall through to the next node in the array, because
## "ends here" and "continues to whatever happens to be next" must not look identical.
@export var next_node: StringName = &""
## Offered instead of `next_node` when non-empty. A node with choices waits for the player.
@export var choices: Array[DialogueChoice] = []

@export_group("Condition")
## Tested before the node is shown. A node that fails is skipped and the runner tries the next
## one in the array.
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
@export var condition_value: int = 0

@export_group("Effect")
## Written when this node is REACHED.
@export var effect_flag: StringName = &""
@export var effect_write: GameEnums.FlagWrite = GameEnums.FlagWrite.NONE
@export var effect_value: int = 0


func problems(conversation_id: StringName) -> PackedStringArray:
	var context: String = "%s/%s" % [conversation_id, node_id if node_id != &"" else &"(unnamed)"]
	var found: PackedStringArray = PackedStringArray()
	if node_id == &"":
		found.append("%s has a node with no node_id" % conversation_id)
	if text_key == "":
		found.append("%s has no text_key" % context)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s tests a flag but names none" % context)
	if effect_write != GameEnums.FlagWrite.NONE and effect_flag == &"":
		found.append("%s writes a flag but names none" % context)
	if not choices.is_empty() and next_node != &"":
		found.append("%s has BOTH choices and a next_node; the next_node would never be used" % context)
	for choice: DialogueChoice in choices:
		found.append_array(choice.problems(context))
	return found
