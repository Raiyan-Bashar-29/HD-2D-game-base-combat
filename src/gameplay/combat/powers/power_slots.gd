class_name PowerSlots
extends RefCounted
## The four quick slots (C6.3a): one key each uses one of the fighter's powers in the field,
## without opening a menu.
##
## IN PLAIN WORDS: slot 1 is the kit's first power that is not a passive, slot 2 the second, and
## so on, in the order the kit lists them. That is the same order the Powers menu shows, so the
## player sees one order everywhere, and nothing new is saved. A kit with more than four powers
## reaches the rest through the menu (F). The keys are `CombatActions.SLOTS` (1 to 4 by
## default, rebindable on the controls screen); `ActionFighter` reads them and calls `press`.
## A press goes through `FieldCommands`, so it follows the field's rules: no ATB cost, the
## power's own cooldown, cost and refusals.
##
## OWNS: which power sits in which slot, and using it.
## MUST NOT: read input (the fighter does) or draw anything (the HUD's slot line, C6.3b).

## How many quick slots there are; `CombatActions.SLOTS` has one key for each.
const COUNT: int = 4


## The powers in `user`'s slots, in slot order: the equipped kit's first `COUNT` powers that are
## not passives. Empty when the fighter has no kit.
static func powers(user: Combatant) -> Array[Power]:
	var out: Array[Power] = []
	var held: PowerSet = PowerSet.of(user.get_parent()) if user != null else null
	if held == null or held.kit == null:
		return out
	for power: Power in held.kit.powers:
		if power != null and not power.passive and out.size() < COUNT:
			out.append(power)
	return out


## Uses the power in `slot` (0 is the first). False, changing nothing, when the slot is empty or
## the power is refused right now (cooling, too costly, nobody to aim at).
static func press(user: Combatant, slot: int, rng: RandomNumberGenerator) -> bool:
	var slotted: Array[Power] = powers(user)
	if slot < 0 or slot >= slotted.size():
		return false
	return FieldCommands.use(user, BattleCommand.for_power(slotted[slot]), rng)
