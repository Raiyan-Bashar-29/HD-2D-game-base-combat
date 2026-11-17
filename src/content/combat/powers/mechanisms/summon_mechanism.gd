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
## - `untouchable`: nothing can hit them and no foe picks them as a target.
## - `moves_each`: each leaves once it has finished this many moves, so a summon can appear, do
##   one thing and go. 0 means no limit.
## - `linked_hp` (C8.10f): of each hp point one of them loses, the user loses this share too
##   (0.5: half). 0 links nothing.
## - `saved` (C8.10f): how many are out is kept in `Flags` (`summon/<user>/<power>`), so after the
##   area is left or a save is loaded that many come back beside the user. A leave for any other
##   reason lowers the count.
## They all leave when the user falls, when the kit comes off, or when the area is left.
##
## IN A BATTLE: those already out in the field join the party as guests (C8.10d,
## `BattleSetup`). A use during a battle (C8.10e) brings one fighter per entry onto the user's
## side of it, played by its definition's `brain`, for `turns` of the user's own turns (0: to
## the end of the battle). `cap`, `untouchable` and `owner_status` hold there too; `lifetime`
## and `moves_each` do not.
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
## Nothing can hit them, and no foe picks them as a target.
@export var untouchable: bool = false
## Each leaves once it has finished this many moves. 0 means no limit.
@export var moves_each: int = 0
## In a battle, how many of the user's turns each stays. 0 means to the end of the battle.
@export var turns: int = 0
## Of each hp point one of them loses, the user loses this share too. 0 links nothing.
@export var linked_hp: float = 0.0
## How many are out is saved, and they come back after an area change or a load.
@export var saved: bool = false


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
	if lifetime < 0.0 or cap < 0 or spread < 0.0 or moves_each < 0 or turns < 0 or linked_hp < 0.0:
		found.append("%s has a negative lifetime, cap, spread, moves_each, turns or linked_hp" % context)
	if owner_status != null:
		found.append_array(owner_status.problems())
	return found
