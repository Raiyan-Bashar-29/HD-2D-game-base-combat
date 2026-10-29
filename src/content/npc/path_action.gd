class_name PathAction
extends Resource
## One non-combat verb you can perform on a person: scrutinise them, barter with them, ask them
## to guide you. The signature mechanic, as authored data.
##
## REFUSAL AND FAILURE ARE DIFFERENT THINGS, and keeping them apart is the whole design.
##   A REFUSAL happens BEFORE anything: the player is told why and nothing changes. A locked
##   gate refuses. So does bartering with someone who does not know you well enough to sell.
##   A FAILURE happens AFTER committing: the action ran, it did not work, and it COST something.
## An action that could only refuse would be a lock with extra steps. An action that could only
## fail would give the player no way to read the situation before spending their standing. The
## interesting middle is the one Octopath's Inquire lives in, and it needs both.
##
## NO DICE. `success_standing` is a threshold, not a probability. A random path action makes the
## player save-scum, and a save-scummed mechanic is one the player experiences as a slot machine
## rather than as a relationship. If randomness is ever wanted it belongs behind this one field,
## and every authored .tres stays valid.
##
## REFERENCED BY PATH, NOT FOUND BY SCAN. Unlike items, conversations and schedules, nothing
## ever needs to look an action up by id: it is only ever reached through the NPC that offers
## it, exactly as a chest reaches its `ItemDefinition`s. So there is no fourth registry here,
## and the note in `schedule_db.gd` about three being a pattern and four being a problem does
## not fire.
##
## OWNS: the data of one action, and validating its own fields.
## MUST NOT: perform itself, read or write a flag, read standing, or know who offers it. It must
## also not touch an autoload — this is the content layer, which `tools/check_content.gd` loads
## under `--headless --script` where autoload identifiers do not resolve.

## Shown on the prompt. Presentational; this file decides nothing about what happens.
@export var verb: GameEnums.InteractVerb = GameEnums.InteractVerb.SCRUTINISE
## Localization key for the object's name on the prompt, e.g. "action.keeper.scrutinise".
@export var label_key: String = ""

@export_group("Refused before it runs")
## Minimum standing required to ATTEMPT at all. Below this the action refuses with
## LOW_STANDING and nothing changes — the player is told, and has lost nothing.
@export_range(-3, 5, 1) var required_standing: int = -3
## The interactor must be carrying this. Empty means no item is needed.
@export var requires_item: StringName = &""
## Once performed successfully, stop offering it. For a thing you can only learn once.
@export var once: bool = true

@export_group("Succeeds or fails")
## Standing at or above this SUCCEEDS; below it the action runs and FAILS. Set it equal to
## `required_standing` for an action that cannot fail once it is offered at all.
@export_range(-3, 5, 1) var success_standing: int = -3
## Set true on success. Empty writes nothing.
@export var success_flag: StringName = &""
@export_range(-3, 5, 1) var standing_on_success: int = 1
@export_range(-3, 5, 1) var standing_on_failure: int = -1

@export_group("What the player is told")
@export var success_key: String = ""
@export var failure_key: String = ""
## Shown for the LOW_STANDING refusal. Empty falls back to the generic refusal line, which is
## correct for an action whose unavailability needs no explanation.
@export var refusal_key: String = ""


## Would this succeed at that standing? A pure question, so the same rule serves the action, the
## test suite and any future UI that wants to grey a choice out rather than hide it.
func succeeds_at(standing: int) -> bool:
	return standing >= success_standing


func verb_name() -> String:
	var names: Array = GameEnums.InteractVerb.keys()
	var raw: String = names[verb]
	return raw


## Everything wrong with this action, as data rather than a log line, so the same check serves
## the game, the test suite and the headless validator.
func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if label_key == "":
		found.append("%s has an action with no label_key" % context)
	if success_standing < required_standing:
		# Not fatal, but it means the failure branch is unreachable: anything allowed to run is
		# already above the success line. Almost always a typo for the reverse.
		found.append("%s (%s) can never fail: success_standing %d is below required_standing %d" % [
			context, label_key, success_standing, required_standing,
		])
	if success_key == "":
		found.append("%s (%s) says nothing on success" % [context, label_key])
	if success_standing > required_standing and failure_key == "":
		found.append("%s (%s) can fail but says nothing when it does" % [context, label_key])
	return found
