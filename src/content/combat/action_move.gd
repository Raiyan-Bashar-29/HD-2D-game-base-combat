class_name ActionMove
extends Resource
## One move in real-time combat: a sword swing, a lunge, a dodge roll, a spell cast in the field.
##
## IN PLAIN WORDS, a move has three phases, each a number of seconds:
## - STARTUP: the wind-up. Nothing has happened yet, and the move can be read by the other side.
## - ACTIVE: the move does its thing. A swing's hitbox is live; a dodge's roll travels.
## - RECOVERY: the follow-through. The fighter is still busy, but a dodge may cut it short, and
##   from `chain_after` seconds into it the next swing of an attack chain may start.
##
## A move that STRIKES (power above 0, or a `skill`) hurts what its hitbox touches. With a `skill`
## the hit goes through `SkillUse`, so a spell costs, cures and drains the way it does in a
## turn-based battle; without one it is a plain `Combatant.hit` for `power` of `element`.
## `poise` is how many points of the target's shield the hit takes (the Break path, C2.17), and
## `knockback` is how far the target is pushed, in metres.
##
## A move with i-frames (`iframes_to` above `iframes_from`) makes its user untouchable from
## `iframes_from` to `iframes_to` seconds after the move starts. That is what a dodge is.
## A PERFECT DODGE (C6.6c) is a hit dodged in the first `perfect_window` seconds of those
## i-frames: the dodge was started just before the hit. 0 means this move has no perfect dodge.
##
## A SECOND untouchable stretch (`iframes2_from/to`, C8.16) works the same way, for a move that
## is untouchable twice; it has no perfect dodge. An ARMOUR stretch (`armour_from/to`) is
## different: hits still land and hurt, but they do not push, so the move is not interrupted.
## `events` are things that happen at set times inside the move (see `MoveEvent`).
##
## It is authored inline inside a `MoveSet`'s `.tres`, or as a file of its own when several
## move sets share it.
##
## OWNS: the shape of one move and what is wrong with it.
## MUST NOT: time itself or touch a node. `MoveTimeline` (systems) runs the clock and C3.3's
## hitbox does the hitting.

@export var id: StringName = &""
@export var name_key: String = ""
@export_group("Timing")
@export var startup: float = 0.1
@export var active: float = 0.1
@export var recovery: float = 0.3
## Seconds into RECOVERY when the next move of a chain may start. 0 means as soon as recovery
## begins; equal to `recovery` means only once the move is fully over.
@export var chain_after: float = 0.0
## Seconds after the move starts when its user becomes untouchable, and when that ends.
@export var iframes_from: float = 0.0
@export var iframes_to: float = 0.0
## Seconds from the start of the i-frames in which a dodged hit counts as a perfect dodge.
@export var perfect_window: float = 0.0
## A second untouchable stretch, and a stretch in which hits land but do not push (C8.16).
@export var iframes2_from: float = 0.0
@export var iframes2_to: float = 0.0
@export var armour_from: float = 0.0
@export var armour_to: float = 0.0
## Timed events, in time order.
@export var events: Array[MoveEvent] = []
@export_group("Hit")
@export var power: float = 0.0
@export var element: StringName = &""
@export var hits: int = 1
@export var poise: int = 0
@export var knockback: float = 0.0
## Seconds a landed hit holds its victim in the air, unable to act (a launcher, C8.8a). Hits on
## a victim already in the air keep it there a little longer each time (`Juggle`).
@export var launch: float = 0.0
## Once this move has landed a hit, the next move of the chain may start at once (C8.8a).
@export var cancel_on_hit: bool = false
## A GRAB (C8.8b): when this move lands and its victim flinches, the victim is held in place
## and the user plays this follow-up at once, the throw. The throw always lands on the victim.
@export var throw_move: ActionMove
## A PROMPT (C8.8c): a timed press. The first attack press while this move plays is measured
## against this window, in seconds since the move started, and multiplies the move's `power`.
## Only the first press counts, so mashing misses it. Null means the move has no prompt.
@export var prompt: TimedWindow
## An INTERRUPT (C8.8c): a landed hit of this move stops its victim's move while that move is
## still winding up, or inside its armour stretch, and stuns the victim as a push does.
@export var interrupts: bool = false
## A skill to resolve the hit through instead of `power` and `element`.
@export var skill: Skill
@export_group("Shape")
## The hitbox, as a box this big, centred this far from the user (forward is -z).
@export var hitbox_size: Vector3 = Vector3.ONE
@export var hitbox_offset: Vector3 = Vector3(0.0, 0.0, -1.0)
## How fast the user travels during ACTIVE, in metres per second: a lunge, or a dodge's roll.
@export var travel_speed: float = 0.0


## True when the move hurts what it touches, rather than only moving its user.
func strikes() -> bool:
	return power > 0.0 or skill != null


## The whole move, wind-up to follow-through, in seconds.
func length() -> float:
	return startup + active + recovery


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if startup < 0.0 or active < 0.0 or recovery < 0.0:
		found.append("%s has a negative phase time" % context)
	elif length() <= 0.0:
		found.append("%s takes no time at all" % context)
	if throw_move != null and (not throw_move.strikes() or throw_move.throw_move != null):
		found.append("%s has a throw that does not strike, or that grabs again" % context)
	if prompt != null:
		found.append_array(prompt.problems("%s prompt" % context))
		if prompt.opens > length():
			found.append("%s has a prompt that opens after the move ends" % context)
	if launch < 0.0:
		found.append("%s has a negative launch time" % context)
	if chain_after < 0.0 or chain_after > recovery:
		found.append("%s has a chain_after outside its recovery" % context)
	if iframes_to < iframes_from:
		found.append("%s has i-frames that end before they start" % context)
	if iframes2_to < iframes2_from or armour_to < armour_from:
		found.append("%s has a second i-frame or armour stretch that ends before it starts" % context)
	var last: float = 0.0
	for index: int in events.size():
		var event: MoveEvent = events[index]
		if event == null:
			found.append("%s has an empty event" % context)
			continue
		found.append_array(event.problems("%s event %d" % [context, index]))
		if event.at < last or event.at > length():
			found.append("%s event %d is out of order or after the move ends" % [context, index])
		last = maxf(last, event.at)
	if perfect_window < 0.0 or perfect_window > iframes_to - iframes_from:
		found.append("%s has a perfect window outside its i-frames" % context)
	if strikes() and (active <= 0.0 or hits < 1 or hitbox_size.length() <= 0.0):
		found.append("%s strikes but has no active time, hits or hitbox" % context)
	return found
