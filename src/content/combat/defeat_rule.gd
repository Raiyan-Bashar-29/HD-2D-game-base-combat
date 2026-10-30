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
## OWNS: the choice and its two numbers.
## MUST NOT: carry it out. `FieldDefeat` does.

enum Kind { REVIVE_IN_PLACE, RESPAWN_AT_ENTRY, RELOAD_SAVE }

@export var kind: Kind = Kind.RESPAWN_AT_ENTRY
@export_range(0.05, 1.0, 0.05) var revive_fraction: float = 0.5
## Seconds on the ground before the rule is carried out, so the fall can be seen.
@export var delay: float = 2.0
