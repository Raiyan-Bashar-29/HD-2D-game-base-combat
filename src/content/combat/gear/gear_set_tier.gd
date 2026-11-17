class_name GearSetTier
extends Resource
## One step of a gear set's bonus (C7.4b): what wearing `pieces` pieces of the set gives. See
## `GearSetBonus` and `docs/GEAR.md` § Sets.
##
## IN PLAIN WORDS: "two pieces: +3 strength" is one tier, and "four pieces: a kit" is another.
## Every tier the wearer has reached counts at once, so four pieces give both. A status at a
## step is a kit whose `passives` list it, the way special gear gives one (C7.3).
##
## OWNS: the data of one step. `GearSetBonus` checks it.
## MUST NOT: know who wears the set. `GearSetBonuses` does.

## How many worn pieces of the set reach this step. At least 1.
@export var pieces: int = 2
## Stat changes while the step is reached. Leave `source` empty: the worn set fills it in.
@export var modifiers: Array[StatModifier] = []
## Hero powers, passives and gauges while the step is reached. Null means none.
@export var kit: PowerKit
## Passives (C9.3) the wearer holds while the step is reached.
@export var passives: Array[PassiveSkill] = []
