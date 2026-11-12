class_name FinisherMechanism
extends PowerMechanism
## M2, a finisher (C6.8): one big, gated hit, often after a charge. See `docs/POWERS.md` § M2.
##
## IN PLAIN WORDS: using the power starts a charge (`charge_time` seconds in the field,
## `charge_turns` of the user's own turns in a battle). While it charges, the user holds the
## `charging` status, when one is given: it may slow the user, lower its defence, or keep it
## still. When the charge is full the `strike` lands. With no charge it lands at once.
##
## A CHARGE CAN BE BROKEN. It is lost, and nothing lands, when the `charging` status ends early
## (a status with `breaks_on_hit` ends on any hit that hurts, as a sleep does), when one hit of at
## least `break_damage` lands on the user, or when the user falls. So give `charging` a duration
## of 0: it is held until the charge ends, one way or the other.
##
## THE STRIKE IS AN `ActionMove`, used as a barrage's shot is: its `power`, `element`, `hits`,
## `poise`, `knockback` and `skill` are the hit. In the field it lands through the foe's hurtbox,
## so a dodge, a block and a counter still answer it; in a battle as a battle ATTACK does.
## `all_foes` strikes every foe (in the field, every foe within `reach` metres of the user);
## otherwise it strikes one: the aimed foe in the field, the first standing foe in a battle.
##
## THE FLOURISH: in the field, `flourish` seconds of real time during which the fight stands
## still (`CombatClock` at 0) before the strike lands, the way a time-stop finale does.
##
## POWER FROM A POOL: the power's own POWER and HITS scaling are read as it lands, so a
## POOL_FRACTION rule makes a fuller gauge hit harder. `drain_pool`, when set, is then emptied.
##
## OWNS: the shape of a finisher.
## MUST NOT: hold running state. `FinisherRun` (gameplay) runs it, and `Flourish` stops the fight.

## The hit that lands when the charge is full.
@export var strike: ActionMove
## Seconds of fight time the charge takes in the field. 0 lands at once.
@export var charge_time: float = 0.0
## The user's own turns the charge takes in a battle. 0 lands at once.
@export var charge_turns: int = 0
## Held while charging, when given. Give it duration 0.
@export var charging: StatusEffect
## One hit on the user of at least this much damage breaks the charge. 0: only `charging`'s own
## `breaks_on_hit` breaks it.
@export var break_damage: int = 0
## Real seconds the fight stands still before the strike lands, in the field. 0 for none.
@export var flourish: float = 0.0
## True: the strike lands on every foe; false: on one.
@export var all_foes: bool = false
## With `all_foes`, how far from the user a foe may stand in the field, in metres.
@export var reach: float = 10.0
## A pool emptied when the strike lands, after the scaling has read it. Empty for none.
@export var drain_pool: StringName = &""


func kind() -> StringName:
	return &"finisher"


## A finisher aims at the foes, so a battle offers them as its targets.
func aims_at_foes() -> bool:
	return true


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = super.problems(context)
	if strike == null:
		found.append("%s has no strike" % context)
	else:
		found.append_array(strike.problems("%s strike" % context))
	if charge_time < 0.0 or charge_turns < 0 or break_damage < 0 or flourish < 0.0 or reach < 0.0:
		found.append("%s has a negative charge, break damage, flourish or reach" % context)
	if all_foes and reach <= 0.0:
		found.append("%s strikes every foe within no reach at all" % context)
	var charges: bool = charge_time > 0.0 or charge_turns > 0
	if not charges and (charging != null or break_damage > 0):
		found.append("%s has a charging status or a break damage but never charges" % context)
	if charging != null:
		found.append_array(charging.problems())
	return found
