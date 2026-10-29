class_name Quest
extends ContentEntry
## One quest, as authored data: what it is called, when it starts, and its steps in order.
##
## THE ID IS THE FILE NAME. `data/quests/roses.tres` must declare `id = &"quest/roses"`.
## `QuestDb` refuses any quest where the two disagree and names both, so a copy-paste slip is a
## loud startup problem rather than a quest that silently never exists. The `quest/` prefix
## makes a save file self-describing, the same way `item/` does.
##
## IT STARTS ON A FLAG CONDITION, WHICH IS WHY NOTHING HAS TO OFFER IT. A conversation that
## writes `met/gardener` starts a quest that tests it, and the conversation has never heard of
## the quest system - exactly the shape a trigger volume already has, where the trigger never
## names its consequence. So "a quest given by an NPC", "a quest that begins when you enter a
## place" and "a quest unlocked by chapter three" are all one mechanism and no code.
##
## A COMPLETED QUEST GRANTS NOTHING, DELIBERATELY. It emits `Events.quest_completed` and stops.
## The alternative - a `reward_item` field - would put the `gameplay` layer (Inventory, and a
## player to give it to) inside a `systems`-layer tracker, and `src/` points downward only.
## Anything that wants to hand over an item, open a gate or start the next chapter listens to
## the signal, which is the same reasoning that keeps `Weather` from drawing rain.
##
## STEPS ARE ORDERED AND WALKED FRONT TO BACK. There is no branching and no failure state: this
## is the template's one shallow proof that a quest system exists, and a branching quest wants a
## graph, a failure policy and a UI for both. `docs/WORK_PACKAGES.md` carries the row.
##
## OWNS: the immutable data of one quest, and validating its own fields.
## MUST NOT: read a flag, track progress, grant a reward, or touch an autoload - for the reason
## in quest_step.gd's header, which is a build gate rather than a preference.

## `id` is inherited from `ContentEntry`; for this catalogue it is `quest/` plus this file name.
## Localization key for the player-facing title. Never raw text.
@export var name_key: String = ""
## Localization key for the one-line description the journal draws under the title.
@export var summary_key: String = ""
## In authored order. The tracker's current objective is the FIRST one whose condition fails.
@export var steps: Array[QuestStep] = []

@export_group("Start")
## The quest becomes active when this test passes. ALWAYS means it is active from the first
## frame of a new game, which is right for a tutorial objective and wrong for anything else.
@export var condition_flag: StringName = &""
@export var condition_test: GameEnums.FlagTest = GameEnums.FlagTest.ALWAYS
@export var condition_value: int = 0


## Everything wrong with this quest, as data rather than a log line, so the same check serves
## the game, the test suite and the headless validator.
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("%s has no id" % resource_path)
	if name_key == "":
		found.append("%s (%s) has no name_key" % [resource_path, id])
	if steps.is_empty():
		found.append("%s has no steps, so nothing could ever complete it" % id)
	if condition_test != GameEnums.FlagTest.ALWAYS and condition_flag == &"":
		found.append("%s tests a flag to start but names none" % id)
	var seen: Dictionary[StringName, bool] = {}
	for step: QuestStep in steps:
		if step == null:
			found.append("%s has an empty step slot" % id)
			continue
		if seen.has(step.step_id):
			found.append("%s has two steps called '%s'" % [id, step.step_id])
		seen[step.step_id] = true
		found.append_array(step.problems(id))
	return found


## The step with this id, or null. Used when a save names a step that authoring has since
## removed - the tracker recovers by re-deriving from flags rather than crashing.
func step(step_id: StringName) -> QuestStep:
	for entry: QuestStep in steps:
		if entry != null and entry.step_id == step_id:
			return entry
	return null
