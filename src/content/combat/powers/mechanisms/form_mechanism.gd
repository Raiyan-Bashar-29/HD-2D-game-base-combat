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
## `look` and `name_key` (C6.5d) are what the player sees while the form is held: a `LookDef`
## (a tint, a size and a tag over the head) and a name shown beside the fighter's own on the
## battle screen and the HUD. A cycle stage with no look or name of its own shows the cycle's
## (`look_at`, `name_at`).
##
## `commands`, `replaces_attack` and `aftermath` (C6.5e) are what the form lets the fighter DO:
## - `commands`: while the form is held, the battle menu and the field menu offer these in place
##   of the fighter's own (its hero powers still follow). Empty keeps the fighter's own.
## - `replaces_attack`: a skill the plain Attack becomes in a battle while the form is held, paid
##   and aimed as that skill. In the field the attack is a button, so `attack_chain` does this.
## - A cycle stage with no commands or attack of its own uses the cycle's (`commands_at`,
##   `attack_at`), as its look does.
## - `aftermath`: a status put on when the form ENDS by its own rules: used again to leave it, its
##   drain running dry, or its own timed status running out. A rival form of its group replacing
##   it is a switch, not an end, and a cure, a new game, a load or the kit coming off is no end
##   either, so none of those gives it. The cycle's own counts, never a stage's.
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
## How the fighter looks while in the form (C6.5d). Null: unchanged.
@export var look: LookDef
## The form's name, shown beside the fighter's (C6.5d). Empty: no name shown.
@export var name_key: String = ""
## The menu offered while in the form, in place of the fighter's own (C6.5e). Empty: its own.
@export var commands: Array[BattleCommand] = []
## The skill a battle's plain Attack becomes while in the form (C6.5e). Null: a plain attack.
@export var replaces_attack: Skill
## Put on when the form ends by its own rules (C6.5e), the price of a form. Null: none.
@export var aftermath: StatusEffect


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


## Every status this form can put on: its own, or each stage's, and its aftermath, with no gaps.
## A save finds a held one through this (`PowerKit.status`).
func statuses() -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	for held: StatusEffect in stage_statuses():
		if held != null:
			out.append(held)
	if aftermath != null:
		out.append(aftermath)
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


## The look shown at `stage`: the stage's own, else the cycle's. A plain form's is its own.
func look_at(stage: int) -> LookDef:
	var held: FormMechanism = _stage(stage)
	return held.look if held != null and held.look != null else look


## The name shown at `stage`: the stage's own, else the cycle's. A plain form's is its own.
func name_at(stage: int) -> String:
	var held: FormMechanism = _stage(stage)
	return held.name_key if held != null and held.name_key != "" else name_key


## The commands offered at `stage`: the stage's own, else the cycle's. A plain form's are its own.
func commands_at(stage: int) -> Array[BattleCommand]:
	var held: FormMechanism = _stage(stage)
	return held.commands if held != null and not held.commands.is_empty() else commands


## The skill Attack becomes at `stage`: the stage's own, else the cycle's. Null: a plain attack.
func attack_at(stage: int) -> Skill:
	var held: FormMechanism = _stage(stage)
	return held.replaces_attack if held != null and held.replaces_attack != null else replaces_attack


# The cycle stage at `index`, or null for a plain form or an index out of range.
func _stage(index: int) -> FormMechanism:
	return cycle[index] if index >= 0 and index < cycle.size() else null


# True when a form with no status and no cycle is a mistake. A barrier that is always up says no.
func _needs_status() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if status == null and cycle.is_empty() and _needs_status():
		found.append("%s is a form with no status and no cycle" % context)
	if status != null:
		found.append_array(status.problems())
	if look != null:
		found.append_array(look.problems(context))
	if aftermath != null:
		found.append_array(aftermath.problems())
	if replaces_attack != null:
		found.append_array(replaces_attack.problems())
	for i: int in commands.size():
		if commands[i] == null:
			found.append("%s has an empty command %d" % [context, i])
		else:
			found.append_array(commands[i].problems("%s command %d" % [context, i]))
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
