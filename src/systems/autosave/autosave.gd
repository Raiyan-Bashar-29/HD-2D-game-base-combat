class_name Autosave
extends Node
## The autosave POLICY: when a save is written without the player asking for one, whether it is
## allowed to happen at all, and what the player is shown when it does.
##
## WHY THIS FILE EXISTS. `gameplay/autosave` was declared in `settings.gd` from WP-01, drawn to
## the player by `settings_screen.gd`, translated in both languages, and read by nothing. T5.5
## REMOVED it rather than fake it, and gave the reason plainly: `SaveSystem` had no notion of the
## slot a run belongs to, so there was nothing for `true` to mean. This file is what `true`
## means, and the key comes back to `DEFAULTS` in the same row — the second of the three settings
## version 2.0.0 removed to return with the feature it was waiting for.
##
## THE SLOT WAS THE DESIGN QUESTION, NOT THE TRIGGER, and the answer is a DEDICATED slot that no
## manual save can reach. `SaveSystem.AUTOSAVE_SLOT` sits one past the six the save screen
## iterates, so it is outside every manual list by construction rather than by a filter each
## screen has to remember. The two alternatives were both worse: rotating through the manual
## slots, or reserving the last of them, each let an autosave destroy a save the player made on
## purpose — the one thing an autosave must never do — and reserving slot 5 would also have
## changed the meaning of a slot in every save file already on disk, which is a MAJOR bump for
## no gain. Reading is not restricted the way writing is: `latest_slot()` sees it, so Continue
## resumes it, and the load list offers it as a row of its own.
##
## THE POLICY IS HERE AND NOT IN `SaveSystem` BECAUSE THAT FILE OWNS THE FORMAT AND NOT THE
## OCCASION. Its header has said since WP-01 that it knows nothing about game content; a rule
## like "not while the world is mid-transition" is a fact about the running game, and putting it
## there would be the second job it explicitly refuses. It is not an autoload either: an autoload
## needs an ADR, and this is a node with two connections and one decision, which is exactly what
## `UiAccessibility` is and where T5.5 put that.
##
## THREE REFUSALS, AND EACH IS A REAL FAILURE MODE RATHER THAN DEFENSIVE PADDING:
##   the player said no       — `gameplay/autosave` is a veto and nothing else. It cannot make
##                              an autosave happen anywhere this file does not already ask.
##   a transition is running  — `SYSTEMS_INVENTORY.md` item 6 has asked for this since WP-00. A
##                              save written while an area is being freed and another loaded
##                              records a world that exists in neither of them.
##   there is no run yet      — quitting from the main menu on a cold boot would otherwise write
##                              an autosave of nothing over the autosave of a real run, which is
##                              the same destruction the slot policy above exists to prevent.
##
## OWNS: when an autosave happens, whether it may, and the toast that says it did.
## MUST NOT: know what a save contains, write a file itself, or name an area. It asks
## `SaveSystem` for a slot and `Director` whether the world is standing still, and stops.

## The player's veto, named as a `const` on the consumer. That convention is what makes
## `settings_consumers_test._is_consumed` decidable rather than a heuristic: a setting nobody
## reads then has nowhere to be written down.
const AUTOSAVE_SETTING: String = "gameplay/autosave"
## The indicator `SYSTEMS_INVENTORY.md` item 6 asks for, on the toast that already exists.
const NOTIFY_KEY: String = "notify.autosaved"
## Short. An autosave is a courtesy, not news, and it lands on arrival in a new area where the
## player has something else to look at.
const TOAST_SECONDS: float = 2.0


func _ready() -> void:
	Events.game_ending.connect(_on_game_ending)
	Events.area_entered.connect(_on_area_entered)


## Write one, unless the policy refuses. Returns whatever `SaveSystem` returned, or `ERR_SKIP`
## when nothing was attempted — a refusal is not a failure and must not be logged as one.
##
## PUBLIC ON PURPOSE, twice over: an assertion drives the real decision rather than a copy of it,
## and a consuming game's own occasion to autosave — a chapter break, a bed slept in, a boss
## door — is one call on the node in `game_root.tscn` rather than an edit to this file.
func request() -> Error:
	if not Settings.get_bool(AUTOSAVE_SETTING):
		return ERR_SKIP
	if Director.is_transitioning():
		Log.debug("save", "Autosave skipped: a transition is in flight")
		return ERR_SKIP
	if Director.current_area_id == &"":
		return ERR_SKIP
	var err: Error = SaveSystem.save_to_slot(SaveSystem.AUTOSAVE_SLOT)
	if err == OK:
		Events.notify_requested.emit(NOTIFY_KEY, TOAST_SECONDS, {})
	return err


## `game_ending` is emitted one statement before `get_tree().quit()`, so this handler MUST stay
## synchronous — that signal's own comment says so, and `save_to_slot` writes the file inline.
## An `await` here would be killed mid-flight and the save would be a truncated temporary file.
##
## THE TOAST IS EMITTED AND NEVER SEEN on this path, and that is recorded rather than special-
## cased: the window is gone the same frame. One code path with one honest note beats a branch
## that exists only to suppress a label nobody can read.
func _on_game_ending() -> void:
	request()


## A FRAME LATE, DELIBERATELY, AND THIS IS THE ONE THING HERE THAT WILL COST SOMEBODY AN HOUR.
## `Director` emits `area_entered` TWO STATEMENTS BEFORE it clears `_transitioning`, because the
## signal's contract is "the area is in the tree and the player is placed" and the transition is
## not formally over until the curtain has been asked to lift. So a handler that called
## `request()` on the spot would hit the transition refusal EVERY TIME, and the feature would
## never fire once — silently, because each refusal is correct behaviour taken on its own and
## nothing anywhere would be red. One frame later the flag is down and the world is standing
## still, which is the state the guard is actually asking about.
func _on_area_entered(_area_id: StringName) -> void:
	await get_tree().process_frame
	request()
