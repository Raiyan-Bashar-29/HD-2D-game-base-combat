class_name DefeatRule
extends Resource
## What happens when the player falls in a real-time fight (C3.8). An `ActionLoadout` names one;
## none means `RESPAWN_AT_ENTRY`.
##
## IN PLAIN WORDS, after `delay` seconds on the ground:
## - REVIVE_IN_PLACE: get up where they fell, with `revive_fraction` of max hp. Forgiving.
## - RESPAWN_AT_ENTRY: get up with `revive_fraction` of max hp and re-enter the area, so every
##   enemy in it is back and the player starts again from its entrance.
## - RELOAD_SAVE: load the most recent save, the classic game over. With no save at all it falls
##   back to RESPAWN_AT_ENTRY, so a player never gets stuck on the ground.
##
## - SWITCH FIRST (C10.2): in the field, a fallen lead whose party still has a member standing
##   hands the body to that member, and the rule runs only once nobody is left.
## A LOST TURN-BASED BATTLE uses the encounter's own rule (`Encounter.defeat_rule`): its `kind`
## and `revive_fraction`, once the battle screen has closed.
##
## OWNS: the choice and its numbers.
## MUST NOT: carry it out. `FieldDefeat` does.

enum Kind { REVIVE_IN_PLACE, RESPAWN_AT_ENTRY, RELOAD_SAVE }

@export var kind: Kind = Kind.RESPAWN_AT_ENTRY
@export_range(0.05, 1.0, 0.05) var revive_fraction: float = 0.5
## Seconds on the ground before the rule is carried out, so the fall can be seen.
@export var delay: float = 2.0
## In the field, hand the body to a standing party member before the rule runs (C10.2).
@export var switch_first: bool = true
