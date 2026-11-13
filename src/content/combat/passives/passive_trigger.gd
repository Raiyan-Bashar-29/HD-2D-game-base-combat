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
## - CRIT_DEALT: a hit by the holder was critical (it wakes after HIT_DEALT).
## - DODGE: a hit passed through the holder's i-frames. GUARD: a barrier or a perfect block of
##   the holder stopped a hit whole.
## - HP_BELOW, HP_ABOVE: the holder's HP share crossed `threshold` downward, or upward. It wakes
##   once per crossing, not for as long as the HP stays there.
## - STATUS_GAINED: a status landed on the holder; `tag`, when set, must be one of its tags.
## - LETHAL_HIT (C9.2b): a hit is about to take the holder to 0 HP. It wakes before the HP
##   changes, so a SURVIVE effect can cut the hit.
##
## AN EARLY TRIGGER (C9.2b) wakes BEFORE the hit lands and not after: every LETHAL_HIT trigger,
## and any hit trigger holding a SCALE_HIT effect. All its effects run at that moment, and the
## damage they see is the hit's amount so far.
##
## `conditions` (C9.2a) must all hold at that moment, or the trigger stays asleep and spends
## neither its cooldown nor its limit.
##
## OWNS: the data of one trigger, and checking it.
## MUST NOT: listen to anything or count anything. `PassiveSet` (gameplay) does.

enum Event { FIGHT_START, FIGHT_WON, TURN_START, HIT_DEALT, HIT_TAKEN, KILL, ALLY_DEFEATED,
	CRIT_DEALT, DODGE, GUARD, HP_BELOW, HP_ABOVE, STATUS_GAINED, LETHAL_HIT }

## The events that carry another fighter, and those of them that carry a hit's damage.
const PAIRED: Array[Event] = [Event.HIT_DEALT, Event.HIT_TAKEN, Event.KILL, Event.ALLY_DEFEATED,
	Event.CRIT_DEALT, Event.DODGE, Event.GUARD, Event.LETHAL_HIT]
const DAMAGING: Array[Event] = [Event.HIT_DEALT, Event.HIT_TAKEN, Event.KILL, Event.CRIT_DEALT,
	Event.LETHAL_HIT]
## The events whose hit can still be changed before it lands.
const SCALABLE: Array[Event] = [Event.HIT_DEALT, Event.HIT_TAKEN, Event.CRIT_DEALT]

@export var event: Event = Event.FIGHT_START
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var conditions: Array[PassiveCondition] = []
@export var effects: Array[PassiveEffect] = []
## The HP share HP_BELOW and HP_ABOVE watch (0.5 is half).
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5
## The status tag STATUS_GAINED waits for. Empty means any status.
@export var tag: StringName = &""
## Turns in a battle, seconds in the field, before it can wake again. 0 means no wait.
@export var cooldown: float = 0.0
## How many times it may wake in one battle, or in one area in the field. 0 means no limit.
@export var limit: int = 0
## In the field, how many seconds stand for one turn of TURN_START.
@export var interval: float = 1.0


## True when the trigger wakes before the hit lands (see the header).
func early() -> bool:
	if event == Event.LETHAL_HIT:
		return true
	for effect: PassiveEffect in effects:
		if effect != null and effect.kind == PassiveEffect.Kind.SCALE_HIT:
			return true
	return false


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
		if from_damage and not DAMAGING.has(event):
			found.append("%s takes a share of damage in an event that has none" % where)
		if effect.target == PassiveEffect.Target.OTHER and not PAIRED.has(event):
			found.append("%s aims at the other fighter in an event that has none" % where)
		if effect.kind == PassiveEffect.Kind.SCALE_HIT and not SCALABLE.has(event):
			found.append("%s scales a hit in an event with no hit still to land" % where)
		if effect.kind == PassiveEffect.Kind.SURVIVE and event != Event.LETHAL_HIT:
			found.append("%s survives outside LETHAL_HIT" % where)
	for condition: PassiveCondition in conditions:
		if condition == null:
			found.append("%s has a trigger with an empty condition" % where)
			continue
		found.append_array(condition.problems(where))
		if condition.needs_other() and not PAIRED.has(event):
			found.append("%s checks the other fighter in an event that has none" % where)
		if condition.needs_hit() and not DAMAGING.has(event):
			found.append("%s checks the hit in an event that has none" % where)
	return found
