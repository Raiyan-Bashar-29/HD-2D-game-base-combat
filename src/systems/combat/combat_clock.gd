class_name CombatClock
extends RefCounted
## How fast the fight runs (C4.1): one number every real-time combat part multiplies its frame
## time by. 1 is normal speed, 0.5 is half speed, and 0 stops the fight dead.
##
## IN PLAIN WORDS: the hybrid's command menu (C4.4) slows or stops the fight while the player
## chooses, the way FF7 Remake does. The game's own pause cannot do that, because it stops
## everything, menus included, and `Engine.time_scale` would also slow the day clock, the weather
## and the UI. So the fight keeps its own scale here, and only the fight reads it:
## `ActionFighter`, `ActionEnemy`, and the statuses they tick.
##
## WHO MAY CHANGE IT: whatever slows the fight puts it back when it is done. As a safety net,
## `ActionHost` resets it to 1 whenever an area is entered, so a menu freed half-way through
## never leaves the next room frozen.
##
## WHAT IGNORES IT, ON PURPOSE: the player's ordinary walking (upstream's, and a menu that
## slows the fight holds the player still anyway), gravity, and `FieldDefeat`'s wait on the
## ground, which would otherwise never end at 0.
##
## IT IS A STATIC VARIABLE, NOT AN AUTOLOAD. Adding an autoload needs an ADR (CLAUDE.md), and
## a number needs no node.
##
## OWNS: the combat time scale.
## MUST NOT: touch `Engine.time_scale` or the scene tree's pause, which belong to the game.

## The current scale. Read it freely; change it through `set_scale`, which refuses negatives.
static var scale: float = 1.0


## Sets the scale, never below 0: a fight cannot run backwards.
static func set_scale(value: float) -> void:
	scale = maxf(0.0, value)


## `delta` seconds of real time, as fight time.
static func scaled(delta: float) -> float:
	return delta * scale


## Back to normal speed.
static func reset() -> void:
	scale = 1.0
