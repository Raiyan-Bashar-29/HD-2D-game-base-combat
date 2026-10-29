class_name DialogueChoice
extends Resource
## One option the player may pick at a branch. Data only.
##
## A choice that fails its condition is NOT SHOWN, which is the opposite of how a locked gate
## behaves and deliberately so: a gate you cannot open teaches you there is something to come
## back for, whereas a reply you cannot give teaches you only that the writer thought of it.
## Refusal is for the world; omission is for conversation.
##
## OWNS: its label, its condition, and which node it leads to.
## MUST NOT: know how it is drawn, or perform its own effect. Effects belong to the node the
## choice leads to, so that arriving at a node has the same consequence however you got there.
## It must also not touch an autoload - tools/check_content.gd loads this class under
## `--headless --script`, where autoload identifiers do not resolve, so one Log call here
## would break the build gate.

## Localization key for the option text. Never raw text.
@export var text_key: String = ""
## The node this choice leads to. Empty ends the conversation, which is how a "goodbye" is
## authored without a terminal node per conversation.
@export var target_node: StringName = &""

@export_group("Condition")
## Which flag decides whether this option is offered at all.
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
## The number compared against, for EQUALS, AT_LEAST and AT_MOST. Ignored otherwise.
@export var condition_value: int = 0


## Everything wrong with this choice, as data rather than a log line, so the same check serves
## the game, the test suite and the headless validator.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if text_key == "":
		found.append("%s has a choice with no text_key" % context)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s has a choice testing a flag but names none" % context)
	return found
