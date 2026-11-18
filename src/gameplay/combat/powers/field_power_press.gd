class_name FieldPowerPress
extends RefCounted
## A field fighter that is not the player uses a hero power (C10.22): a follower's or a field
## foe's brain names one in an `ActionBrainEntry`, and this uses it the way a quick slot does.
##
## IN PLAIN WORDS: `use` asks `PowerUse` whether the power may be used now, aims it as a field
## command is aimed (`PowerUse.targets`), and uses it: the cost is paid, the cooldown starts, the
## skill lands and the mechanism runs. The caller then plays the power's own `move`, if it has
## one, on the fighter's clock.
##
## OWNS: using one power for a fighter nobody presses keys for.
## MUST NOT: choose the power (the brain does) or play its move (the fighter does).


## `body`'s fighter uses `power` now. False, changing nothing, when it is refused or has nobody
## to land on.
static func use(body: Node, power: Power, rng: RandomNumberGenerator) -> bool:
	var me: Combatant = Combatant.of(body)
	if me == null or power == null or PowerUse.refusal(me, power) != PowerUse.Reason.NONE:
		return false
	return PowerUse.use(me, power, PowerUse.targets(me, power), rng)
