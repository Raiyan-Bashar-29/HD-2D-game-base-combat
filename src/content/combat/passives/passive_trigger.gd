class_name PassiveTrigger
extends Resource
## The waits-then-does part of a passive (C9.1): an event, a chance, and the effects to run. See
## `docs/PASSIVES.md` § The passive.
##
## IN PLAIN WORDS: when `event` happens to the holder, roll `chance`; if it passes, run every
## effect in order. `cooldown` then makes it wait (turns in a battle, seconds in the field), and
## `limit` caps how often it wakes in one battle (in the field: until the next area).
##
## EACH EVENT MEANS THE SAME IN BOTH FORMULAS:
## - FIGHT_START: a battle begins; in the field, an area is entered.
## - FIGHT_WON: the last standing foe of the holder falls.
## - TURN_START: the holder's battle turn begins; in the field, every `interval` seconds.
## - HIT_DEALT, HIT_TAKEN: a hit by, or on, the holder landed.
## - KILL: a foe fell to the holder's hit.
## - ALLY_DEFEATED: an ally of the holder fell.
##
## OWNS: the data of one trigger, and checking it.
## MUST NOT: listen to anything or count anything. `PassiveSet` (gameplay) does.

enum Event { FIGHT_START, FIGHT_WON, TURN_START, HIT_DEALT, HIT_TAKEN, KILL, ALLY_DEFEATED }

@export var event: Event = Event.FIGHT_START
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var effects: Array[PassiveEffect] = []
## Turns in a battle, seconds in the field, before it can wake again. 0 means no wait.
@export var cooldown: float = 0.0
## How many times it may wake in one battle, or in one area in the field. 0 means no limit.
@export var limit: int = 0
## In the field, how many seconds stand for one turn of TURN_START.
@export var interval: float = 1.0


func problems(where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if effects.is_empty():
		found.append("%s has a trigger with no effects" % where)
	if chance <= 0.0:
		found.append("%s has a trigger that can never wake (chance 0)" % where)
	if cooldown < 0.0 or limit < 0:
		found.append("%s has a trigger with a cooldown or limit below zero" % where)
	if event == Event.TURN_START and interval <= 0.0:
		found.append("%s has a turn trigger with no interval" % where)
	for effect: PassiveEffect in effects:
		if effect == null:
			found.append("%s has a trigger with an empty effect" % where)
			continue
		found.append_array(effect.problems(where))
		var from_damage: bool = effect.kind == PassiveEffect.Kind.POOL_FROM_DAMAGE
		if from_damage and not [Event.HIT_DEALT, Event.HIT_TAKEN, Event.KILL].has(event):
			found.append("%s takes a share of damage in an event that has none" % where)
		var paired: bool = [Event.HIT_DEALT, Event.HIT_TAKEN, Event.KILL, Event.ALLY_DEFEATED].has(event)
		if effect.target == PassiveEffect.Target.OTHER and not paired:
			found.append("%s aims at the other fighter in an event that has none" % where)
	return found
