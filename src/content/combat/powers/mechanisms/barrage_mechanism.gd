class_name BarrageMechanism
extends PowerMechanism
## M1, a barrage (C6.7): many shots from a pattern. See `docs/POWERS.md` § M1.
##
## IN PLAIN WORDS: using the power fires `count` shots, one every `interval` seconds, each
## starting where its `pattern` puts it and flying at `speed` metres a second. Many kits share
## this one mechanism: a treasury of weapons from portals, a rain of arrows, swords that circle
## the target, spikes from the ground, a gun's stream of bullets.
##
## A SHOT IS AN `ActionMove`, used as it is: its `startup` is the wait before it flies (a cut
## that appears, then strikes), its `active` is how long it flies, its `power`, `element`,
## `hits`, `poise`, `knockback` and `skill` are its hit, and its `hitbox_size` and
## `hitbox_offset` are its size. So a shot is dodged, blocked, countered and finds a weakness
## exactly as a swing does. `shots` are played in turn: small fast shards, then a big slow bolt.
## `elements`, when given, gives each shot one of them at random (a treasury that finds a
## weakness by chance); otherwise each shot keeps its own.
##
## THE PATTERNS, where shot i starts and which way it flies:
## - RING_BEHIND_USER: on an arc of `radius` behind and above the user, toward the target.
## - RING_AROUND_TARGET: on a circle of `radius` round the target, inward.
## - RAIN: at a random point within `radius` of the target, `height` above it, straight down.
## - LINE: at the user, toward the target.
## - FROM_GROUND: spaced along the line from the user through the target (`radius` long, centred
##   on the target), on the ground, pointing up.
## `turn_rate` (radians a second) makes a shot home in on its target; 0 flies straight. A
## `pierce` shot flies on through what it strikes; otherwise its first strike ends it.
##
## A BEAM is a LINE barrage of one shot with `speed` 0, `pierce`, a long `hitbox_size` with
## `hitbox_offset` half its length forward, and a short `active`: a line that hits everything
## along it for a moment.
##
## IN A BATTLE there are no shots in flight: the barrage lands `count` hits at once, each on a
## foe picked at random from those standing, with the shot's numbers (its skill, if it has one).
##
## OWNS: the shape of a barrage.
## MUST NOT: hold running state. `BarrageRun` (gameplay) runs it, and `Projectile` flies a shot.

enum Pattern { RING_BEHIND_USER, RING_AROUND_TARGET, RAIN, LINE, FROM_GROUND }

@export var pattern: Pattern = Pattern.RING_BEHIND_USER
## How many shots, before the power's COUNT scaling.
@export var count: int = 6
## Seconds between two shots in the field. 0 fires them all at once.
@export var interval: float = 0.1
## Metres a second. 0 leaves a shot where it appeared (a spike, a cut, a beam).
@export var speed: float = 14.0
## How fast a shot turns toward its target, in radians a second. 0 does not home.
@export var turn_rate: float = 0.0
## How wide the pattern is, in metres.
@export var radius: float = 1.5
## RAIN only: how high above the target the shots start.
@export var height: float = 6.0
## True: a shot flies on through what it strikes, striking each fighter once.
@export var pierce: bool = false
## The shots, played in turn.
@export var shots: Array[ActionMove] = []
## When not empty, each shot draws one of these elements at random.
@export var elements: Array[StringName] = []


func kind() -> StringName:
	return &"barrage"


## A barrage aims at the foes, so a battle offers them as its targets.
func aims_at_foes() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if count < 1:
		found.append("%s fires fewer than one shot" % context)
	if interval < 0.0 or speed < 0.0 or turn_rate < 0.0 or radius < 0.0 or height < 0.0:
		found.append("%s has a negative interval, speed, turn rate, radius or height" % context)
	if shots.is_empty():
		found.append("%s has no shots" % context)
	for i: int in shots.size():
		if shots[i] == null:
			found.append("%s has an empty shot %d" % [context, i])
		else:
			found.append_array(shots[i].problems("%s shot %d" % [context, i]))
	return found
