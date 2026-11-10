class_name BarrierMechanism
extends FormMechanism
## M3, a barrier (C6.6a): something that stops or softens what reaches the fighter. See
## `docs/POWERS.md` § M3.
##
## IN PLAIN WORDS: a barrier is a form that also guards. It is entered and left like any form
## (use its power; one per `exclusive_group`), it holds the form's `status` while it is up, and
## the form's drain is its upkeep (`drain_pool` with `drain_per_second` or `drain_per_turn`:
## when the pool is empty the barrier comes down). A barrier with NO status and no cycle is
## ALWAYS up while the kit is worn; put it on a passive power.
##
## WHAT IT DOES TO A HIT ABOUT TO LAND, in this order:
## 1. A hit carrying one of `bypass_tags` goes straight through (a `sure_hit`, a `domain`).
## 2. A hit whose element is in `absorb_elements` is drunk whole: it takes nothing, and what it
##    would have taken is ADDED to the guard's `store_pool` (the hp pool heals; a charge pool
##    stores it for a later finisher). This costs nothing.
## 3. `cost_per_block` points of `cost_pool` are paid. When they cannot be paid, the barrier
##    comes down and the hit lands whole.
## 4. `mode` NULLIFY brings the hit to nothing; REDUCE multiplies it by `factor` (0.4 leaves
##    40%). A barrier that only absorbs is REDUCE with factor 1.
## `scope` ALLIES guards every ally too, with the guard's own pools paying and storing.
## A heal is never touched, and a fallen guard guards nobody.
##
## THE TIMED BLOCK (C6.6b), `mode` TIMED_BLOCK: the press that raises the guard is the timing.
## A hit that arrives while `timing` is open, counted in seconds from the moment the guard went
## up, is a PERFECT block: it takes nothing, costs nothing, and what it would have taken is added
## to `store_pool` when one is named. Any later hit is a LATE block: it pays `cost_per_block` and
## leaves `factor` of the hit, as REDUCE does. Give the guard's `status` a short duration, so
## each press raises it anew. In a battle there are no seconds: a block is perfect until the
## start of the guard's own next turn.
## Example: `timing` 0 to 0.2 s, `factor` 0.3, `cost_per_block` 10 of `devil`, `store_pool`
## `royal`: a press within 0.2 s of the hit takes 0 and stores it; a slower one takes 30%.
##
## OWNS: the shape of a barrier.
## MUST NOT: hold running state. `BarrierRun` (gameplay) runs it.

enum Mode { NULLIFY, REDUCE, TIMED_BLOCK }
enum Scope { SELF, ALLIES }

@export var mode: Mode = Mode.NULLIFY
## REDUCE, and a late TIMED_BLOCK: what is left of the hit, from 0 to 1.
@export_range(0.0, 1.0) var factor: float = 0.5
@export var scope: Scope = Scope.SELF
## Paid each time the barrier stops or softens a hit.
@export var cost_pool: StringName = &""
@export var cost_per_block: int = 0
## A hit with any of these tags is not stopped.
@export var bypass_tags: Array[StringName] = []
## Elements drunk whole into `store_pool`.
@export var absorb_elements: Array[StringName] = []
## Also where a perfect timed block stores what it stopped.
@export var store_pool: StringName = &""
## TIMED_BLOCK only: when, in seconds after the guard goes up, a hit is blocked perfectly.
@export var timing: TimedWindow


func kind() -> StringName:
	return &"barrier"


func _needs_status() -> bool:
	return false


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if factor < 0.0 or factor > 1.0:
		found.append("%s leaves a share of the hit outside 0 to 1" % context)
	if cost_per_block < 0:
		found.append("%s has a negative cost per block" % context)
	if cost_per_block > 0 and cost_pool == &"":
		found.append("%s pays its blocks from no pool" % context)
	if not absorb_elements.is_empty() and store_pool == &"":
		found.append("%s absorbs into no pool" % context)
	if mode == Mode.TIMED_BLOCK:
		if timing == null:
			found.append("%s is a timed block with no timing" % context)
		else:
			found.append_array(timing.problems(context))
		if status == null and cycle.is_empty():
			found.append("%s is a timed block that is never raised: it has no status" % context)
	return found
