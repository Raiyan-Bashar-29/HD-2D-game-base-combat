class_name MoveEvent
extends Resource
## One thing that happens at a set time inside a move (C8.16): a sound, an effect picture, a
## shot sent out, a change of travel speed, a screen shake or a short hit pause.
##
## IN PLAIN WORDS: an `ActionMove` holds a list of these, in time order. `at` is seconds after
## the move starts. Which other fields matter depends on `kind`:
## - SOUND: `sound` plays at the body.
## - EFFECT: `picture` shows at `offset` from the body for `seconds`.
## - SHOT: `shot` (a move of its own) flies from `offset` the way the body faces, at `amount`
##   metres a second.
## - SPEED: from now on the move's travel speed is `amount` metres a second.
## - SHAKE: the screen shakes with strength `amount` (0 to 1) for `seconds`.
## - PAUSE: the whole fight stops for `seconds` (a hit pause).
## `offset` is in the body's own space: forward is -z.
##
## OWNS: the shape of one timed event and what is wrong with it.
## MUST NOT: time itself or touch a node. `MoveTimeline` reads SPEED; the `MoveEvents` node
## (gameplay) does the rest.

enum Kind { SOUND, EFFECT, SHOT, SPEED, SHAKE, PAUSE }

@export var at: float = 0.0
@export var kind: Kind = Kind.SOUND
@export var sound: AudioStream
@export var picture: Texture2D
@export var shot: ActionMove
@export var amount: float = 0.0
@export var seconds: float = 0.0
@export var offset: Vector3 = Vector3.ZERO


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if at < 0.0:
		found.append("%s happens before its move starts" % context)
	if kind == Kind.SOUND and sound == null:
		found.append("%s is a sound with no sound" % context)
	if kind == Kind.EFFECT and (picture == null or seconds <= 0.0):
		found.append("%s is an effect with no picture or no seconds" % context)
	if kind == Kind.SHOT and (shot == null or not shot.strikes()):
		found.append("%s is a shot with no striking move" % context)
	if kind == Kind.SPEED and amount < 0.0:
		found.append("%s is a negative speed" % context)
	if (kind == Kind.SHAKE or kind == Kind.PAUSE) and seconds <= 0.0:
		found.append("%s lasts no time" % context)
	return found
