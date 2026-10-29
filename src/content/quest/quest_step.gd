class_name QuestStep
extends Resource
## One objective in a quest: what to tell the player, and the flag condition that finishes it.
##
## A STEP NAMES A FLAG CONDITION, NEVER A CALLBACK, and that is the whole design. The
## alternative - a step that names a function, a signal or a script to run - makes every quest
## a code change, which is the rule ADR-0006 exists to prevent, and it makes a .tres
## unreviewable in a diff. The condition is the same CLOSED SET of six comparisons a dialogue
## node uses (`GameEnums.FlagTest`), evaluated by the same `FlagQuery.passes` both call, so
## "when is this done" has one meaning in this project and not two.
##
## WHAT THAT COSTS, STATED PLAINLY: a step can only observe something that ends up in `Flags`.
## A lever, a trigger volume, a gate, a path action and a dialogue effect all write one, so
## most objectives are already expressible. AN ITEM COUNT IS ONE TOO, as of T3.3, and this file
## did not change to make it so: an `Inventory` publishes each count as `bag/<carrier>/<item id>`,
## so "bring me three petals" is `AT_LEAST 3` on that key. The dependency points DOWN from
## `gameplay` to `core`, which is why there is no `required_item` field here and never will be -
## one would put an `Inventory` and a carrier inside the content layer. See BagKeys.
##
## What a step still cannot do is TAKE anything, and that is the same layer rule: a completed
## quest emits `Events.quest_completed` and stops - see quest.gd's header.
##
## THE STEP IS NOT LATCHED. `QuestTracker` asks this condition live, every time a flag moves,
## so a game that resets the flag behind a step sees the objective reopen. Quest COMPLETION is
## latched and cannot un-happen; an intermediate step is a question about the world right now.
## The two differ on purpose and the reasoning is in quest_tracker.gd.
##
## OWNS: the localization key for one objective, and the condition that completes it.
## MUST NOT: read a flag, write a flag, know its position in the quest, or grant anything. It
## is data. It must also not touch an autoload - tools/check_content.gd loads this class under
## `--headless --script`, where autoload identifiers do not resolve, so a single `Log` call
## here would break a build gate. That is a real enforcement of the content-layer rule.

## Unique within its quest. It is what gets SAVED and what `Events.quest_advanced` carries, so
## renaming one is a public change: an old save reloads onto a step id that no longer exists.
@export var step_id: StringName = &""
## Localization key for the objective line the journal draws. Never raw text.
@export var summary_key: String = ""

@export_group("Completion")
## The step is finished when this test passes. ALWAYS means "finished the moment the quest
## starts", which is legitimate for a step that only exists to say something.
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
@export var condition_value: int = 0


## Everything wrong with this step, as data rather than a log line, so the same check serves
## the game, the test suite and the headless validator.
func problems(quest_id: StringName) -> PackedStringArray:
	var context: String = "%s/%s" % [quest_id, step_id if step_id != &"" else &"(unnamed)"]
	var found: PackedStringArray = PackedStringArray()
	if step_id == &"":
		found.append("%s has a step with no step_id" % quest_id)
	if summary_key == "":
		found.append("%s has no summary_key" % context)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s tests a flag but names none" % context)
	return found
