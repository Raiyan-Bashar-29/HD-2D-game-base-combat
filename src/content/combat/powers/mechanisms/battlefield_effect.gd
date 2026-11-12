class_name BattlefieldEffect
extends Resource
## One rule of a battlefield (M4, C6.9a and C6.9b) for one group of fighters. See `docs/GEAR.md`
## § Part 3.
##
## IN PLAIN WORDS: while the battlefield stands, every fighter in `who` who is inside it gets
## `modifiers` on its sheet and holds `statuses`. When it leaves (walks out of reach, or the
## battlefield ends) both come off again. A battlefield is a list of these, so "the caster's side
## hits harder and the other side is slowed" is two effects.
##
## THE GROUPS:
## - CASTER: the one who raised it.
## - CASTER_SIDE: the caster and its allies.
## - OTHER_SIDE: everyone hostile to the caster.
## - EVERYONE: all fighters inside, the caster too.
## - EVERYONE_BUT_CASTER: all fighters inside except the caster.
##
## DAMAGE AND HEALING (C6.9b) are skills the caster uses on the fighters of the group, free:
## - `on_enter` once on each fighter as it comes inside (so on everyone when it rises): damage
##   "at once".
## - `on_exit` once on each fighter as it leaves, or when the battlefield ends.
## - `tick` on a clock: every `tick_seconds` in the field, every `tick_turns` of the caster's own
##   turns in a battle. That is damage over time, per turn, or per N seconds. With `tick_grows`
##   each tick is that much stronger than the one before (0.5: 1, 1.5, 2, ...), a domain that
##   closes in.
## A skill is a whole hit: its power, element, `effects` (heal, drain, restore, cure, dispel),
## statuses and `sure_hit` all count, through the caster's damage formula.
##
## MOVEMENT (C6.9b, field only): `pull` draws each fighter of the group toward the caster this
## many metres a second, never past it; `push` drives it away. A battle has no distances.
##
## IMMUNITY (C6.9b): a fighter holding a status tagged with one of `immune_tags` is untouched by
## this effect. A fighter whose stat `resist_field_<name>` (the battlefield power's id after its
## last "/") is 1 or more is untouched by the whole battlefield.
##
## OWNS: the shape of one battlefield rule.
## MUST NOT: hold running state. `BattlefieldRun` (gameplay) applies it.

enum Who { CASTER, CASTER_SIDE, OTHER_SIDE, EVERYONE, EVERYONE_BUT_CASTER }

@export var who: Who = Who.OTHER_SIDE
## Put on the sheet of each fighter in `who` while it is inside: `attack`, `defence`,
## `damage_dealt`, `damage_taken`, `speed`, `regen_<pool>`, `cost_mult_<pool>`, `resist_<tag>`.
@export var modifiers: Array[StatModifier] = []
## Held by each fighter in `who` while it is inside, and taken off when it leaves: a buff, a
## debuff, or a SKIP_TURN status that holds the other side still.
@export var statuses: Array[StatusEffect] = []
## Used by the caster on each fighter in `who` as it comes inside. Null: nothing.
@export var on_enter: Skill
## Used by the caster on each fighter in `who` as it leaves or the battlefield ends. Null: nothing.
@export var on_exit: Skill
## Used by the caster on every fighter in `who` inside, on the clock below. Null: no tick.
@export var tick: Skill
## The field clock: a tick every this many seconds. 0: no tick in the field.
@export var tick_seconds: float = 0.0
## The battle clock: a tick every this many of the caster's turns (1 is every turn). 0: none.
@export var tick_turns: int = 0
## How much stronger each tick is than the last: tick n is (1 + tick_grows * n) times as strong.
@export var tick_grows: float = 0.0
## Field: metres a second each fighter in `who` is drawn toward the caster.
@export var pull: float = 0.0
## Field: metres a second each fighter in `who` is driven away from the caster.
@export var push: float = 0.0
## A fighter holding a status with one of these tags is untouched by this effect.
@export var immune_tags: Array[StringName] = []


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if modifiers.is_empty() and statuses.is_empty() and on_enter == null and on_exit == null \
			and tick == null and pull == 0.0 and push == 0.0:
		found.append("%s changes nothing" % context)
	for i: int in modifiers.size():
		if modifiers[i] == null:
			found.append("%s has an empty modifier %d" % [context, i])
		elif modifiers[i].stat == &"":
			found.append("%s modifier %d names no stat" % [context, i])
	for i: int in statuses.size():
		if statuses[i] == null:
			found.append("%s has an empty status %d" % [context, i])
		else:
			found.append_array(statuses[i].problems())
	for skill: Skill in [on_enter, on_exit, tick]:
		if skill != null:
			found.append_array(skill.problems())
	if tick != null and tick_seconds <= 0.0 and tick_turns <= 0:
		found.append("%s has a tick with no clock" % context)
	if tick == null and (tick_seconds > 0.0 or tick_turns > 0):
		found.append("%s has a clock with no tick" % context)
	if tick_seconds < 0.0 or tick_turns < 0 or tick_grows < 0.0 or pull < 0.0 or push < 0.0:
		found.append("%s has a negative clock, growth, pull or push" % context)
	for tag: StringName in immune_tags:
		if tag == &"":
			found.append("%s has an empty immune tag" % context)
	return found
