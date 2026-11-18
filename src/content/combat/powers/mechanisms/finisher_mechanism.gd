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
## HOLD, LINE AND STILL (C10.32, field only). With `hold` the charge runs while the power's key
## is held: let go before `min_charge` seconds and it is cancelled, nothing landing; later, and it
## strikes grown by the charge reached (`hold_scale` at `min_charge`, full at `charge_time`);
## held to the end it strikes on its own. A LINE `shape` reaches the foes ahead of the user within
## `reach` and `width`, not a circle. `holds_still` keeps the user standing while it charges.
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

## Where an all-foes strike reaches in the field (C10.32): a circle, or a line ahead.
enum Shape { CIRCLE, LINE }
@export var shape: Shape = Shape.CIRCLE
## A LINE's width, in metres.
@export var width: float = 2.0
## True: the charge runs while the key is held, and letting go strikes or cancels (C10.32).
@export var hold: bool = false
## With `hold`: seconds of charge before a let-go strikes; earlier, it is cancelled.
@export var min_charge: float = 0.0
## With `hold`: how strong a strike let go at `min_charge` is, against a full one (1).
@export_range(0.0, 1.0, 0.01) var hold_scale: float = 0.5
## True keeps the user standing still while it charges, in the field (C10.32).
@export var holds_still: bool = false


func kind() -> StringName:
	return &"finisher"


## A finisher aims at the foes, so a battle offers them as its targets.
## One foe unless it strikes them all (C10.1).
func aims_at_one() -> bool:
	return not all_foes


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
