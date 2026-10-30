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
## `poise` is how much of the target's shield the hit takes (the Break path, C2.17), and
## `knockback` is how far the target is pushed, in metres.
##
## A move with i-frames (`iframes_to` above `iframes_from`) makes its user untouchable from
## `iframes_from` to `iframes_to` seconds after the move starts. That is what a dodge is.
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
@export_group("Hit")
@export var power: float = 0.0
@export var element: StringName = &""
@export var hits: int = 1
@export var poise: float = 0.0
@export var knockback: float = 0.0
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
	if chain_after < 0.0 or chain_after > recovery:
		found.append("%s has a chain_after outside its recovery" % context)
	if iframes_to < iframes_from:
		found.append("%s has i-frames that end before they start" % context)
	if strikes() and (active <= 0.0 or hits < 1 or hitbox_size.length() <= 0.0):
		found.append("%s strikes but has no active time, hits or hitbox" % context)
	return found
