class_name PlantMechanism
extends PowerMechanism
## M15, a planted strike (C6.26): something left in the ground now that goes off later. See
## `docs/GEAR.md` § The planted strike.
##
## IN PLAIN WORDS: using the power leaves `count` plants where `where` says, `spread` metres
## apart along the line from the user. Each waits, unseen by the rules, until its `trigger`:
## - REMOTE: the same power is used again while plants stand (or any power named in
##   `set_off_by` is used): every standing plant goes off, one after another `chain_delay`
##   seconds apart, so a line of them ripples.
## - PROXIMITY: a foe comes within `radius` metres (a mine).
## - TIMER: `seconds` pass (a time bomb), or `turns` in a battle.
## - ON_HIT: a foe within `radius` of it is hit by anyone (a rune that bursts on a struck foe).
## Going off, a plant plays its `eruption`, an `ActionMove`, as a still hitbox where it lies (a
## tall box with its offset raised is a spike from the ground). A plant not set off within
## `lifetime` seconds is lost (0 keeps it until set off). No more than `max_standing` stand at
## once: planting another loses the oldest.
##
## WHERE_PROJECTILES_LAND plants nothing when used. Instead, every shot of a barrage of the same
## fighter that ends its flight without striking leaves a plant where it ended (the shards that
## missed stay in the ground). With a REMOTE trigger, using this power then sets them all off.
##
## IN A BATTLE nothing stands in the ground: a plant is a MARK on a foe, the status `mark` (give
## it STACK stacking, so several plants on one foe count). Using the power puts `count` marks on
## foes picked at random; a barrage's missed shot marks the foe it was aimed at. A mark goes off
## on its trigger: REMOTE on the next use, TIMER after `turns` of the user's turns, PROXIMITY when
## the marked foe next deals damage, ON_HIT when the marked foe is next hit. Going off, a foe
## takes the eruption once for each mark it held, and the marks are gone.
##
## OWNS: the shape of a plant.
## MUST NOT: hold running state. `PlantRun` (gameplay) runs it, and `Planted` is one plant.

enum Where { AT_TARGET, AT_USER, AHEAD, WHERE_PROJECTILES_LAND }
enum Trigger { REMOTE, PROXIMITY, TIMER, ON_HIT }

@export var where: Where = Where.AT_TARGET
## AHEAD only: how far in front of the user, in metres.
@export var distance: float = 3.0
## How many one use plants, before the power's COUNT scaling.
@export var count: int = 1
## Metres between two plants of one use.
@export var spread: float = 1.5
## The most that may stand at once; planting another loses the oldest.
@export var max_standing: int = 8
@export var trigger: Trigger = Trigger.REMOTE
## REMOTE only: other powers whose use sets the plants off.
@export var set_off_by: Array[StringName] = []
## PROXIMITY and ON_HIT: how near a foe must be, in metres.
@export var radius: float = 1.5
## TIMER: seconds in the field, and turns in a battle.
@export var seconds: float = 2.0
@export var turns: int = 2
## What each plant does when it goes off.
@export var eruption: ActionMove
## Seconds between one plant going off and the next.
@export var chain_delay: float = 0.0
## Seconds a plant waits to be set off before it is lost. 0 waits for ever.
@export var lifetime: float = 30.0
## The mark a plant is in a battle.
@export var mark: StatusEffect


func kind() -> StringName:
	return &"plant"


## A plant is put on foes, so a battle offers them as its targets.
func aims_at_foes() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if eruption == null:
		found.append("%s has no eruption" % context)
	else:
		found.append_array(eruption.problems("%s eruption" % context))
	if mark == null:
		found.append("%s has no mark for a battle" % context)
	else:
		found.append_array(mark.problems())
	if count < 1 or max_standing < 1:
		found.append("%s plants fewer than one, or lets fewer than one stand" % context)
	if distance < 0.0 or spread < 0.0 or radius < 0.0 or chain_delay < 0.0 or lifetime < 0.0:
		found.append("%s has a negative distance, spread, radius, delay or lifetime" % context)
	if trigger == Trigger.TIMER and (seconds <= 0.0 or turns < 1):
		found.append("%s is a timer with no time" % context)
	if trigger != Trigger.REMOTE and not set_off_by.is_empty():
		found.append("%s names powers to set it off but is not REMOTE" % context)
	return found
