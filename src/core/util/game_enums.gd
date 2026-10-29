class_name GameEnums
extends RefCounted
## Shared vocabulary. Enums that more than one system needs to name the same way.
##
## WHY: if Clock says night as the string "night" and the lighting system checks for
## "Night", nothing errors. It just silently never matches. Enums make that a parse error.
##
## RULE: an enum belongs here only if two or more systems use it. Anything used by exactly
## one system stays private inside that system's own script.

## Time-of-day bands. Lighting, NPC schedules and ambience all key off these.
enum DayPhase { DAWN, MORNING, MIDDAY, AFTERNOON, DUSK, NIGHT, DEEP_NIGHT }

## Weather states. Drives environment, particles, ambience and some interactions.
enum WeatherKind { CLEAR, CLOUDY, OVERCAST, RAIN, STORM, FOG, SNOW, WIND }

## What the player character is currently doing. The controller owns transitions;
## every other system only reads it.
enum MoveState { IDLE, WALK, RUN, SNEAK, JUMP, FALL, CLIMB, SWIM, BUSY, LOCKED }

## Eight-way facing for billboarded sprites. SOUTH is first because a sprite facing the
## camera is the default resting pose, and the one that placeholder art always has.
enum Facing { SOUTH, SOUTH_EAST, EAST, NORTH_EAST, NORTH, NORTH_WEST, WEST, SOUTH_WEST }

## Item taxonomy. Note the absence of weapons and armour: this game has no combat.
enum ItemCategory { TOOL, CONSUMABLE, KEY_ITEM, QUEST, MATERIAL, CLOTHING, DOCUMENT, TREASURE }

## Where an equippable item is worn or held. NONE is first and is the default, so every existing
## ItemDefinition .tres stays valid with no edit — and, exactly like InteractVerb, this is
## APPENDED TO AND NEVER REORDERED, because a definition stores it as an ordinal.
##
## Note the absence of a weapon slot and an armour slot, and it is the same absence ItemCategory
## has: there is no combat in this template and there will not be one. A slot answers "what does
## holding this let you do" — a light for the dark, a tool for a task — never "how hard do you hit".
enum EquipSlot { NONE, LIGHT, TOOL, GARMENT, TRINKET }

## The verb shown on the interaction prompt. Purely presentational. The interactable
## itself decides what actually happens.
## APPENDED TO, NEVER REORDERED. Scene files store an exported enum as its ORDINAL, so moving
## LOOK from 0 would silently repoint every authored .tscn in the project at a different verb.
## The last five are the path actions, in the spirit of Octopath's Scrutinise and Inquire.
enum InteractVerb {
	LOOK, TAKE, OPEN, CLOSE, USE, TALK, READ, SIT, CLIMB, ENTER, HARVEST, LIGHT,
	SCRUTINISE, INQUIRE, BARTER, GUIDE, SOOTHE,
}

## Why an interaction was refused, so the UI can say something useful instead of nothing.
## Also append-only, and for the same reason.
enum RefusalReason {
	NONE, LOCKED, MISSING_ITEM, MISSING_SKILL, WRONG_TIME, ALREADY_DONE, HANDS_FULL,
	STORY_GATED, NOT_GROUNDED, LOW_STANDING,
}

## What an NPC is doing while it is at a scheduled place. Deliberately tiny: the schedule says
## WHERE and roughly what posture, and anything richer belongs to a future behaviour tree
## rather than to a data enum that every schedule .tres would then have to be migrated for.
enum NpcActivity { STAND, WANDER, SLEEP }

## How a dialogue condition tests a flag. Deliberately a CLOSED set of comparisons rather than
## an expression language: a conversation is data authored in the editor, and the moment it can
## contain an expression, it needs a parser, error reporting and a sandbox. ALWAYS is the
## default so an unconditional line needs no fields filled in at all.
enum FlagTest { ALWAYS, IS_TRUE, IS_FALSE, EQUALS, AT_LEAST, AT_MOST }

## How a dialogue effect writes a flag. Same closed-set reasoning as FlagTest. NONE is the
## default, so a line with no consequence declares nothing.
enum FlagWrite { NONE, SET_TRUE, SET_FALSE, SET_INT, ADD }

## Where a quest stands. Three values, and there is deliberately no FAILED: a failable quest
## needs a failure policy, a way to retry and a UI for both, and this template ships one shallow
## proof of the mechanism instead. NEVER PERSISTED AS AN ORDINAL — `QuestTracker` saves two
## lists of quest ids, because appending a value here must not repoint every existing save.
enum QuestState { UNSTARTED, ACTIVE, COMPLETE }

## What the UI is doing to the world right now. UiRoot owns the transitions; the player's
## input readers and the prompt only listen. OVERLAY and MODAL differ in exactly one way and
## it is not cosmetic: an OVERLAY suspends the player's input while the world keeps ticking
## (a conversation happens in real time), a MODAL stops the world as well.
enum UiMode { GAMEPLAY, OVERLAY, MODAL }

## Which kind of device the player last touched, so a prompt can name the button they will
## actually press. Two values and no TOUCH: nothing in this template reads a touch event, and a
## value nothing produces is a state a consumer has to handle for no reason. Appended, never
## inserted — the same discipline as every enum above, although this one is never persisted.
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }
