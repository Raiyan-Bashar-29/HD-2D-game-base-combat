class_name Meters
extends RefCounted
## Pools that move on their own (C2.16): one rule, read from stats, gives MP regeneration,
## Octopath-style Boost points and a Final-Fantasy-style limit gauge.
##
## IN PLAIN WORDS: give a fighter the stat `regen_mp` 3 and it gets 3 mp back at the start of
## each of its turns. Give it `fill_on_hit_limit` 0.5 and every 10 hp it loses puts 5 into its
## `limit` pool. The pool's size is `max_<pool>` as always. A negative regen drains, so a stance
## that costs mp every turn is a status with a `regen_mp` -2 modifier and no new code.
##
## THE STATS ARE FOUND BY NAME. `StatSheet.mentioned` lists every `regen_*` and `fill_on_hit_*`
## stat the sheet has a base or a modifier for, so a game adds a new meter in data alone.
##
## IN THE FIELD (C10.9) the same stat is per second: `regen_seconds`, called by each field
## fighter on its own clock, carries the fractions on the fighter, and leaves a kit's gauge
## pools alone (`KitGauges` regenerates those itself).
##
## OWNS: what `regen_<pool>` and `fill_on_hit_<pool>` mean.
## MUST NOT: decide WHEN a turn starts or a hit lands. `Battle`, `Combatant` and the field
## fighters call in.

const REGEN_PREFIX: String = "regen_"
const FILL_PREFIX: String = "fill_on_hit_"


## One turn's regeneration for `fighter`: each `regen_<pool>` stat, rounded, added to its pool.
## A defeated fighter regenerates nothing.
static func regen_turn(fighter: Combatant) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	if vitals == null or vitals.is_defeated():
		return
	for stat: StringName in fighter.sheet.mentioned(REGEN_PREFIX):
		var amount: int = roundi(fighter.sheet.value(stat))
		if amount != 0:
			vitals.change(StringName(String(stat).trim_prefix(REGEN_PREFIX)), amount)


## `seconds` of fight time for `fighter` in the field (C10.9): each `regen_<pool>` stat per
## second, whole points added and the fractions carried. A kit's gauge pools are skipped.
static func regen_seconds(fighter: Combatant, seconds: float) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	if vitals == null or vitals.is_defeated() or seconds <= 0.0:
		return
	var powers: PowerSet = PowerSet.of(fighter.get_parent())
	var skip: Array[StringName] = []
	if powers != null:
		skip = powers.gauges.pools()
	for stat: StringName in fighter.sheet.mentioned(REGEN_PREFIX):
		var pool := StringName(String(stat).trim_prefix(REGEN_PREFIX))
		if skip.has(pool):
			continue
		var due: float = fighter.regen_carry.get(pool, 0.0) + fighter.sheet.value(stat) * seconds
		# Truncated toward zero, so a drain carries its fraction as a fill does.
		var whole: int = int(due)
		fighter.regen_carry[pool] = due - whole
		if whole != 0:
			vitals.change(pool, whole)


## `fighter` just lost `taken` from its damage pool: each `fill_on_hit_<pool>` stat puts that
## fraction of it into its pool, rounded.
static func fill_on_hit(fighter: Combatant, taken: int) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	if vitals == null or taken <= 0:
		return
	for stat: StringName in fighter.sheet.mentioned(FILL_PREFIX):
		var amount: int = roundi(taken * fighter.sheet.value(stat))
		if amount != 0:
			vitals.change(StringName(String(stat).trim_prefix(FILL_PREFIX)), amount)
