class_name SummonMechanism
extends PowerMechanism
## M-summon, owned fighters (C8.10a): using the power brings fighters onto the user's side.
##
## IN PLAIN WORDS, IN THE FIELD: each use puts one fighter per entry of `fighters` beside the
## user, `spread` metres apart, never past a wall. Each fights with its own brain (the
## `brains` entry at the same place), on the user's side: the user's foes are its foes, and
## the user's allies are its allies. With no foe near it follows the user. It knows who made
## it and with which power. It gives no reward when it falls.
## - `lifetime`: seconds it stays; 0 keeps it until something below sends it away.
## - `cap`: the most out at once from this power; a use over the cap sends the oldest away.
##   0 means no cap.
## - `owner_status`: put on the user while any is out and taken off when the last is gone, so
##   another power can say "only while none is out" (`Power.forbids_statuses`) or "only while
##   one is out" (`requires_statuses`). Give it a long SECONDS duration; the run takes it off.
## They all leave when the user falls, when the kit comes off, or when the area is left.
##
## IN A BATTLE: nothing yet (C8.10c). Its skill, if any, still lands.
##
## OWNS: the shape of a summon.
## MUST NOT: hold running state. `SummonRun` (gameplay) runs it.

## Who comes: one fighter per entry, each with the brain at the same place in `brains`.
@export var fighters: Array[CombatantDef] = []
@export var brains: Array[ActionBrain] = []
## Seconds each stays. 0 means until the user falls, the kit comes off or the area is left.
@export var lifetime: float = 0.0
## The most out at once from this power. 0 means no cap.
@export var cap: int = 0
## Metres between the user and each one as it appears.
@export var spread: float = 1.5
## Held by the user while any is out. Null for none.
@export var owner_status: StatusEffect


func kind() -> StringName:
	return &"summon"


func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if owner_status != null:
		out.append(owner_status)
	return out


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if fighters.is_empty():
		found.append("%s summons nobody" % context)
	if brains.size() != fighters.size():
		found.append("%s has %d fighters but %d brains" % [context, fighters.size(), brains.size()])
	if fighters.has(null) or brains.has(null):
		found.append("%s has an empty fighter or brain" % context)
	if lifetime < 0.0 or cap < 0 or spread < 0.0:
		found.append("%s has a negative lifetime, cap or spread" % context)
	if owner_status != null:
		found.append_array(owner_status.problems())
	return found
