class_name FormMechanism
extends PowerMechanism
## M5, a form (C6.5a): a stance, a style or a transformation. See `docs/POWERS.md` § M5.
##
## IN PLAIN WORDS: a form is a status the fighter holds while in it. The status's modifiers are
## what the form changes (attack x1.5, a cheaper pool); give it duration 0 to last until the
## fighter leaves the form, or a duration for a form that runs out by itself.
## - Using the power enters the form; using it again leaves it.
## - `exclusive_group`: entering a form leaves every other form of the same group in the kit,
##   so a fighter holds one style, one weapon or one transformation of each group at a time.
## - `cycle`: a list of stages, each itself a form (its own status). The first use enters the
##   first stage, each further use moves to the next, and the last wraps round to the first. A
##   cycle never turns off by being used; it ends by its group, a drain, a cure or the kit coming
##   off. `advance_after` names powers whose use also moves the cycle on (a sword that changes
##   after each finisher). A stage gives its status and its moves; the group and the drain are
##   the cycle's own.
## - A drain: `drain_pool` loses `drain_per_second` in the field and `drain_per_turn` in a
##   battle while the form is held, and `drain_per_action` for each move the fighter starts in
##   the field (never its dodge). The form ends when the pool is empty.
## What a form needs before it can be entered is its power's own `requires_pool` and
## `requires_fraction` (a Devil Trigger needs a full enough gauge).
##
## `attack_chain` and `dodge` are what the form plays in the field instead of the fighter's own
## moves (C6.5b); empty or null keeps the fighter's own. A cycle stage with no moves of its own
## plays the cycle's (`moves_of`).
##
## OWNS: the shape of a form.
## MUST NOT: hold running state. `FormRun` (gameplay) runs it.

## Held while in the form. Not used by a cycle, whose stages hold their own.
@export var status: StatusEffect
@export var exclusive_group: StringName = &""
## The stages of a cycle, in order. Empty for a plain form.
@export var cycle: Array[FormMechanism] = []
## Power ids whose use moves a cycle on to its next stage.
@export var advance_after: Array[StringName] = []
@export var drain_pool: StringName = &""
@export var drain_per_second: float = 0.0
@export var drain_per_turn: float = 0.0
## Points of `drain_pool` lost for each move started in the field (C6.5b).
@export var drain_per_action: float = 0.0
## The form's own attack chain and dodge in the field. Empty or null: the fighter's own.
@export var attack_chain: Array[ActionMove] = []
@export var dodge: ActionMove


func kind() -> StringName:
	return &"form"


## The status of each stage, in order: one for a plain form, one per stage for a cycle.
func stage_statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if cycle.is_empty():
		out.append(status)
		return out
	for stage: FormMechanism in cycle:
		out.append(stage.status if stage != null else null)
	return out


## Every status this form can put on: its own, or each stage's, with no gaps.
func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	for held: StatusEffect in stage_statuses():
		if held != null:
			out.append(held)
	return out


## The moves played at `stage`: a stage's own chain and dodge, each falling back to the
## cycle's own when the stage has none. A plain form's are its own. The result is a form used
## only for its `attack_chain` and `dodge`.
func moves_of(stage: int) -> FormMechanism:
	if cycle.is_empty() or stage < 0 or stage >= cycle.size() or cycle[stage] == null:
		return self
	var picked := FormMechanism.new()
	var held: FormMechanism = cycle[stage]
	picked.attack_chain = held.attack_chain if not held.attack_chain.is_empty() else attack_chain
	picked.dodge = held.dodge if held.dodge != null else dodge
	return picked


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if status == null and cycle.is_empty():
		found.append("%s is a form with no status and no cycle" % context)
	if status != null:
		found.append_array(status.problems())
	if not advance_after.is_empty() and cycle.is_empty():
		found.append("%s advances after a power but is not a cycle" % context)
	if drain_pool == &"" and (drain_per_second != 0.0 or drain_per_turn != 0.0 \
			or drain_per_action != 0.0):
		found.append("%s drains no pool" % context)
	if drain_per_second < 0.0 or drain_per_turn < 0.0 or drain_per_action < 0.0:
		found.append("%s has a negative drain" % context)
	for i: int in cycle.size():
		var stage: FormMechanism = cycle[i]
		if stage == null:
			found.append("%s has an empty cycle stage %d" % [context, i])
		elif not stage.cycle.is_empty():
			found.append("%s cycle stage %d has a cycle of its own" % [context, i])
		else:
			found.append_array(stage.problems("%s cycle stage %d" % [context, i]))
	return found
