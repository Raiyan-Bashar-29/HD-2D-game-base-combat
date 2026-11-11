class_name Power
extends Resource
## One hero power (C6.1a): a skill, plus the rules that make it a power. See `docs/POWERS.md`.
##
## IN PLAIN WORDS: most of a power is an ordinary `Skill` (its cost, damage, element, statuses
## and effects), so it lands the same way in every formula. On top of that a power can have:
## - a `move`: its real-time timing and hitbox in the field;
## - a `mechanism`: the one thing a skill cannot do (a barrage, a barrier, a domain...);
## - a `cooldown`: seconds in the field, turns in a battle;
## - conditions: statuses it needs (and may use up), a pool that must be full enough, gear that
##   must be worn (`requires_gear`), and the hours of the day it works (`active_hours`; `(0, 24)` is always, `(20, 4)` is night only);
## - `scaling`: rules that make it stronger or weaker by the situation.
## A `passive` power is never used; it is held while its kit is equipped.
##
## THE COST IS THE SKILL'S. A power that spends a kit gauge sets the skill's `cost_pool` to that
## gauge, so it pays through the path every skill already takes (`SkillUse.pay`).
##
## OWNS: the shape of a power and when, by the clock, it may be used.
## MUST NOT: name a character in code, or check a fighter. `PowerUse` (C6.1b) does the checks.

@export var power_id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
## What it does when used: cost, power, element, statuses and effects.
@export var skill: Skill
## Optional: how it plays out in real time in the field (startup, active, recovery, hitbox).
@export var move: ActionMove
## Optional: the one thing a skill cannot do.
@export var mechanism: PowerMechanism
## Seconds in the field, turns in a battle, before it can be used again.
@export var cooldown: float = 0.0
## Status ids the user must hold to use it.
@export var requires_statuses: Array[StringName] = []
## Status ids taken off the user when it is used (for combinations: two primers, one finisher).
@export var consumes_statuses: Array[StringName] = []
## A pool that must be at least `requires_fraction` full, such as a gauge for a finisher.
@export var requires_pool: StringName = &""
@export_range(0.0, 1.0, 0.01) var requires_fraction: float = 0.0
## The hours it works, from x up to (not including) y. When x is after y, the window wraps past
## midnight. `(0, 24)` means always.
@export var active_hours: Vector2 = Vector2(0.0, 24.0)
## Gear the user must be wearing (C7.3): an item id for one piece, or a gear type's id for any
## piece of that kind ("needs a katana in hand"). Empty means none.
@export var requires_gear: StringName = &""
@export var scaling: Array[PowerScaling] = []
## True for a power that is held, not used.
@export var passive: bool = false


## True when the clock's `hour` (0 to 24, fractions allowed) is inside `active_hours`.
func active_at(hour: float) -> bool:
	var from: float = active_hours.x
	var to: float = active_hours.y
	if is_equal_approx(to - from, 24.0) or is_equal_approx(from, to):
		return true
	if from < to:
		return hour >= from and hour < to
	return hour >= from or hour < to


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var where: String = "%s power %s" % [context, power_id]
	if power_id == &"":
		found.append("%s has no power_id" % where)
	if name_key == "":
		found.append("%s has no name_key" % where)
	if skill == null and mechanism == null and not passive:
		found.append("%s does nothing: no skill and no mechanism" % where)
	if cooldown < 0.0:
		found.append("%s has a negative cooldown" % where)
	if requires_fraction < 0.0 or requires_fraction > 1.0:
		found.append("%s needs a pool fraction outside 0 to 1" % where)
	if requires_fraction > 0.0 and requires_pool == &"":
		found.append("%s needs a fraction of no pool" % where)
	for hour: float in [active_hours.x, active_hours.y]:
		if hour < 0.0 or hour > 24.0:
			found.append("%s has active hours outside 0 to 24" % where)
			break
	if skill != null:
		found.append_array(skill.problems())
	if move != null:
		found.append_array(move.problems(where + " move"))
	if mechanism != null:
		found.append_array(mechanism.problems(where + " mechanism"))
	for i: int in scaling.size():
		if scaling[i] == null:
			found.append("%s lists an empty scaling" % where)
		else:
			found.append_array(scaling[i].problems("%s scaling %d" % [where, i]))
	return found
