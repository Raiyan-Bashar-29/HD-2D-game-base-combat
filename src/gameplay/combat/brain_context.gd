class_name BrainContext
extends RefCounted
## What a thinking fighter may do, wherever it is fighting (C4.8). `BattleAi.decide` reads a
## `BattleBrain` against one of these, so the same brain data plays a turn-based battle and a
## real-time field fight.
##
## IN PLAIN WORDS: a brain asks the same four questions in any formula. May I use this command
## now? Whom could it land on? Do it. And if nothing on my list is allowed, what do I do
## instead? A battle answers them through `Battle` (`BattleBrainContext`), the field through
## `FieldCommands` (`FieldBrainContext`). This base class answers "no" to everything, so a
## brain read against it does nothing.
##
## A game with a third formula subclasses this and overrides the four methods; `BattleAi` needs
## no change.
##
## OWNS: the shape of those four questions, and who is asking.
## MUST NOT: choose among commands. `BattleAi` does that, from the brain's weights.

## The fighter thinking.
var actor: Combatant
## Every draw the brain makes comes from here, so a seeded fight replays exactly.
var rng: RandomNumberGenerator


func _init(thinker: Combatant = null, draws: RandomNumberGenerator = null) -> void:
	actor = thinker
	rng = draws if draws != null else RandomNumberGenerator.new()


## True when `actor` may use `command` now: no status forbids it, the cost and any ATB can be
## paid, and the formula allows that kind of command at all. Who it lands on is `targets_for`.
func allows(_command: BattleCommand) -> bool:
	return false


## Everyone `command` could land on now. A one-target command picks among these by the brain
## entry's rule; an all-targets command takes every one.
func targets_for(_command: BattleCommand) -> Array[Combatant]:
	return []


## `actor` uses `command` on `targets`. False, changing nothing, when it cannot.
func act(_command: BattleCommand, _targets: Array[Combatant]) -> bool:
	return false


## What `actor` does when no entry on its brain is allowed. False when the formula has nothing
## to fall back on: in the field, a follower simply keeps walking.
func fallback() -> bool:
	return false
