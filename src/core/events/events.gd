extends Node
## The global signal registry. Autoload `Events`.
##
## THIS FILE IS THE CONNECTION MAP. Every cross-system conversation in the game is declared
## here, in one place, with typed parameters. Reading this file tells you how the game is
## wired without opening anything else.
##
## WHEN TO USE THE BUS, AND WHEN NOT TO. Apply in five seconds:
##   Direct call   - you own the thing and it is right there. Always prefer this.
##   Node signal   - a parent needs to hear from its own child. Local and traceable.
##   THIS BUS      - a system needs to announce that a fact about the world changed, to
##                   unknown and unrelated listeners, and must not know who cares.
##   Never the bus - for asking a question, getting a value back, or anything where you need
##                   to know the receiver acted. Signals are announcements, not calls.
##
## THE BUS'S OWN FAILURE MODE, stated honestly: flow gets hard to trace, because the emit
## site and the listen site are far apart. Three rules keep that survivable.
##   1. Every signal is declared HERE, with typed parameters. Never emitted ad hoc.
##   2. Past tense for facts that already happened. The _requested suffix for asks.
##   3. Exactly ONE system emits any given signal, and the comment says which. If two
##      systems emit the same signal, the signal is modelled wrong.
##
## OWNS: nothing at all. No state, no logic, deliberately. That is what stops it becoming
## the god object that a singleton called "GameManager" always eventually becomes.

# ---------------------------------------------------------------------------------------
# Application flow. Emitted by Director, SaveSystem and GameRoot.
# ---------------------------------------------------------------------------------------

## A brand-new game began. Fired after flags are cleared, before the first area loads.
signal game_started()
## A save was restored. Listeners should re-read any state they cache.
signal game_loaded(slot: int)
## A save finished writing successfully. No listener in the template; a game that wants a
## "saved" toast connects here.
signal game_saved(slot: int)
## THE APPLICATION IS SHUTTING DOWN. Emitted by `GameRoot` one statement before
## `get_tree().quit()`, so a handler MUST be synchronous - anything that awaits a frame or
## waits on a file write is killed mid-flight. It used to say "returning to the main menu",
## which it has never done: menu return goes through `main_menu_requested`.
signal game_ending()

# ---------------------------------------------------------------------------------------
# Areas and world. Emitted by Director.
# ---------------------------------------------------------------------------------------

## Someone asked to travel. Director is the only listener; it validates, then performs it.
signal area_change_requested(area_id: StringName, spawn_id: StringName)
## Transition began. UI should cover the screen. The old area is still alive at this point.
signal area_unloading(area_id: StringName)
## How far the threaded load of an area has got, 0.0 to 1.0. Emitted every frame while a load
## is in flight, so a loading indicator can show progress without polling ResourceLoader
## itself - which would mean a second place that knows the path template.
signal area_load_progress(area_id: StringName, ratio: float)
## The new area is in the tree and the player is placed. Safe to query world contents.
signal area_entered(area_id: StringName)

## A place went onto the world map. Emitted by `WorldMap` and nothing else.
##
## NOTHING NEEDS THIS TO GATE ANYTHING, and that is the same note `equipment_changed` carries.
## Discovery lives in `Flags` under `map/<area id>`, so a gate, a quest step or a dialogue
## condition reacts through `flag_changed` with no code at all. This exists for a UI that wants
## to redraw a dot, which is presentation and not a rule.
signal area_discovered(area_id: StringName)

# ---------------------------------------------------------------------------------------
# The player character. Emitted by the player's own components.
# ---------------------------------------------------------------------------------------

## The player entered the scene tree. Systems needing a reference should grab it here.
signal player_spawned(player: Node3D)
## The player is leaving the tree. Drop any cached reference; it is about to be invalid.
signal player_despawned()
## Movement state changed. ANNOUNCED FOR A CONSUMING GAME, and listened to by nothing in the
## template - which is deliberate and worth stating, because this line used to claim animation,
## audio and the HUD all read it and none of them did. The sprite is TOLD its state by whoever
## drives it (`CharacterVisual.update_from_velocity`) rather than subscribing here, because
## every NPC uses that class and none of them is the player. A game wiring footstep volume or a
## stamina bar to the player's gait connects here and gets a correct value.
signal player_state_changed(state: GameEnums.MoveState)

# ---------------------------------------------------------------------------------------
# Interaction. Emitted by the interaction sensor on the player.
# ---------------------------------------------------------------------------------------

## The best interaction target changed, or became null. The prompt UI listens to this.
signal interact_target_changed(target: Node3D, verb: GameEnums.InteractVerb, label_key: String)
## An interaction actually began. It may be instant, or held over several seconds.
signal interaction_started(target: Node3D)
## An interaction completed normally.
signal interaction_finished(target: Node3D)
## An interaction was rejected, with a reason the UI can explain to the player. `args` fills
## placeholders the same way notify_requested does - MISSING_ITEM is useless to a player
## without naming the item. `message_key` is an AUTHORED override, empty for almost everything:
## the UI computes `refusal.<reason>` from the enum, which is right for a generic lock and wrong
## for one whose author wrote a specific line. It travels here rather than being asked of the
## target for the same reason `args` does - a refusal is announced once, with everything needed
## to render it, and the prompt never has to hold a reference to a gameplay node.
signal interaction_refused(target: Node3D, reason: GameEnums.RefusalReason, args: Dictionary,
	message_key: String)

# ---------------------------------------------------------------------------------------
# Items and inventory. Emitted by the inventory component.
# ---------------------------------------------------------------------------------------

## An item entered the inventory. `count` is how many were added, not the new total.
signal item_gained(item_id: StringName, count: int)
## An item left the inventory, for any reason.
signal item_lost(item_id: StringName, count: int)
## An item was consumed or activated by the player. A RESERVED NAME WITH NO EMITTER IN THE
## TEMPLATE: `Inventory` can add and remove, and nothing in it "uses" anything, because what
## using an item does is a game's decision. A game that wants consumables emits this from its
## own `Interactable` subclass or item script - that is Tier 2 in docs/ARCHITECTURE.md and needs
## no change under src/. Stated plainly because a listener alone would be silent forever.
signal item_used(item_id: StringName)
## Something about the inventory changed. The UI redraws on this and ignores the specifics.
signal inventory_changed()

## What one carrier has equipped changed. Emitted by an `Equipment` component and nothing else.
## `wearer_id` is carried because equipment is per carrier — an NPC or a stash may have one — and
## a listener that assumed "the player" would be wrong the first time a second one appeared.
##
## NOTHING NEEDS THIS TO GATE ANYTHING. Equipment lives in `Flags` under `equip/<wearer>/<item>`,
## so a gate, a quest step or a dialogue condition reacts through `flag_changed` with no code at
## all — the same reasoning that keeps a `TriggerVolume` from naming its consequence. This signal
## exists for a UI that wants to redraw a row, which is a presentation concern and not a rule.
signal equipment_changed(wearer_id: StringName, slot: GameEnums.EquipSlot, item_id: StringName)

# ---------------------------------------------------------------------------------------
# World state. Emitted by Flags, and by trigger volumes in the world.
# ---------------------------------------------------------------------------------------

## A plot or world flag changed value. Quests, doors and dialogue conditions listen.
signal flag_changed(flag: StringName, value: Variant)

## A trigger volume fired. Emitted by TriggerVolume and nothing else. `who` is the body that
## entered. Carried on the bus rather than left as a local node signal because the whole point
## of a trigger is that the thing it affects is somewhere else and does not know it exists.
signal trigger_fired(trigger_id: StringName, who: Node3D)

# ---------------------------------------------------------------------------------------
# Time and weather. Emitted by Clock and Weather.
# ---------------------------------------------------------------------------------------

## Fired once per in-game minute. Cheap listeners only. This is frequent.
signal minute_passed(day: int, hour: int, minute: int)
## Fired on the hour. NPC schedules key off this.
signal hour_passed(day: int, hour: int)
## A new in-game day began.
signal day_passed(day: int)
## The time-of-day band changed. FOR GAMEPLAY REACTIONS - a shop that shuts at dusk - and NOT
## for lighting: `EnvironmentDriver` interpolates continuously from `Clock.day_fraction()` every
## frame, so a listener here that tinted the environment would be overwritten on the next one.
## This line used to say lighting and ambience cross-fade on it, which is the documentation
## residue of the day/night system that ran correctly and lit nothing.
signal day_phase_changed(phase: GameEnums.DayPhase)
## Weather has begun changing. `seconds` is how long the blend will take.
signal weather_changing(to: GameEnums.WeatherKind, seconds: float)
## Weather finished blending and is now stable.
signal weather_changed(kind: GameEnums.WeatherKind)

# ---------------------------------------------------------------------------------------
# The camera. Asked for by anyone, performed by the area's own rig.
# ---------------------------------------------------------------------------------------

## Shake the camera. `strength` is 0..1 of whatever amplitude the AREA AUTHOR gave their rig,
## and `seconds` is how long it decays over. A `_requested` ask with many askers by design, on
## `notify_requested`'s shape: the thing that just happened knows how hard it hit and knows
## nothing about a camera, and the rig knows how far it may move and nothing about gates.
##
## IT IS NOT ON THE UI BLOCK BELOW, and the distinction is worth stating: this is a request to a
## GAMEPLAY node living in the area scene, so an area with no rig simply has no listener - which
## is the correct behaviour and not a missing one.
signal camera_shake_requested(strength: float, seconds: float)

# ---------------------------------------------------------------------------------------
# Characters. Asked for by anyone, performed by the character's own visual.
# ---------------------------------------------------------------------------------------

## Turn a character to face a world point, without moving it. `character` is the body the turn
## is meant for and `towards` is the point to look at. Every `CharacterVisual` hears this and
## only the one belonging to `character` answers, so a courtyard full of people does not turn
## as one man.
##
## MANY ASKERS BY DESIGN, on `camera_shake_requested`'s shape, and that is the whole reason it
## is a signal rather than a method call. Two askers ship: `InteractionSensor` turns the PLAYER
## towards whatever the prompt is offering, and `Speaker` turns the person being SPOKEN TO
## towards whoever spoke. A third - an NPC that notices the player, walks over and stops them -
## needs no new seam, which is why the seam was drawn here rather than at either call site.
##
## IT IS A REQUEST AND IT DOES NOT HOLD. `CharacterVisual.update_from_velocity` re-aims only
## while the character is actually MOVING, so a turn given to a standing character persists
## until it walks, and one given to a walking character is overwritten on the next physics
## frame. No hold flag exists anywhere and none is needed - the ASKER decides the moment is
## right, and `InteractionSensor`'s stillness gate is exactly that decision written down.
signal turn_requested(character: Node3D, towards: Vector3)

# ---------------------------------------------------------------------------------------
# Dialogue and narrative. Emitted by the dialogue system.
# ---------------------------------------------------------------------------------------

## Someone asked to talk. The UI layer listens and opens the box; the asker does not know a
## box exists. Same shape as area_change_requested: gameplay names an id, ui does the work.
signal dialogue_requested(talk_id: StringName)
## A conversation started. Gameplay input should yield to the dialogue UI.
signal dialogue_started(speaker_id: StringName)
## A conversation ended and control returns to the player.
signal dialogue_finished(speaker_id: StringName)

# ---------------------------------------------------------------------------------------
# Quests. Emitted by the quest system.
# ---------------------------------------------------------------------------------------

signal quest_started(quest_id: StringName)
signal quest_advanced(quest_id: StringName, step: StringName)
signal quest_completed(quest_id: StringName)

# ---------------------------------------------------------------------------------------
# UI requests. Anyone may emit these; the UI layer is the only listener.
# ---------------------------------------------------------------------------------------

## Show a transient toast. `key` is a localization key, never raw player-facing text.
## `args` fills placeholders in the translated string: {"count": 3, "item": "Apple"} against
## "Picked up {count} {item}". Pass an empty Dictionary when there is nothing to substitute.
## Without this a toast could not name a thing or a count, which is what almost every real
## notification in an exploration game does.
signal notify_requested(key: String, seconds: float, args: Dictionary)
## Fade the screen. Director uses this for transitions, and cutscenes may too.
signal screen_fade_requested(to_black: bool, seconds: float)
## Show the main menu. Emitted by GameRoot on boot - which is why the game no longer starts in
## an area - and by the pause menu's "main menu" row. A `_requested` ask has many askers by
## design; it is the FACTS on this bus that have exactly one emitter each.
signal main_menu_requested()
## Close the game. The menus ask; `GameRoot` is the only thing that performs it, so there is
## still one shutdown path and an autosave policy will only ever need adding in one place.
signal quit_requested()
## A screen opened or closed and the world's relationship to input changed. Emitted by UiRoot
## and by nothing else - it is the single announcement that replaces one input-lock boolean
## per screen. Input readers take or release their own `ui` token on it; the prompt hides on
## it. Carried on the bus because UiRoot must not know the player's components exist.
signal ui_mode_changed(mode: GameEnums.UiMode)
## The application lost focus: an alt-tab, a click on another window, the OS taking it. Emitted
## by UiRoot and by nothing else. The ENGINE already releases every held key and action when
## this happens - measured windowed at T6.5, see DEVLOG - but it cannot release state the base
## latched for itself: a toggled run, a hold part-way to firing, a rebind waiting for a key. Each
## owner drops its own on hearing this, and `ScreenKeys` opens the pause menu if the player asked.
signal focus_lost()

# ---------------------------------------------------------------------------------------
# Settings and debug.
# ---------------------------------------------------------------------------------------

## The player picked up a different kind of device, so every prompt naming a button should
## redraw. Emitted by Actions, and ONLY on a change: a stream of stick events from the same pad
## is one fact, not sixty a second. Read the current answer with `Actions.device()`.
signal input_device_changed(device: GameEnums.DeviceKind)
## A user setting changed at runtime, so systems can re-read it. Emitted by Settings.
signal setting_changed(section: String, key: String, value: Variant)
## A developer console command was entered. NO EMITTER in the template, deliberately, and this
## is not the path the template's own console takes: `debug_console_screen.gd` calls
## `DevCommands.run()` directly, because the verbs live in the one directory allowed to name
## demo content and routing them over the bus would carry those names out of it. Kept as the
## hook a game's own tooling emits on and listens to. `tools/check_signals.gd` reads that phrase.
signal debug_command(command: String, args: PackedStringArray)
