class_name PowerUse
extends RefCounted
## Using a hero power (C6.1b): the powers' twin of `FieldCommands` and `SkillUse`, the same in
## the field and in a battle. See `docs/POWERS.md` § The framework.
##
## IN PLAIN WORDS: this file answers three questions about one `Power`:
## - `refusal`: why it cannot be used now, as a `Reason`. NONE means it can. The menus (C6.2,
##   C6.3) turn a reason into words; this file is gameplay and names no text.
## - `targets`: who it would land on in the field (the same aiming as a field command). In a
##   battle the battle picks its targets, as it does for any skill.
## - `use`: does it. It pays the skill's cost (made cheaper by `cost_mult_<pool>`, C6.1a), makes
##   the skill stronger or weaker by the power's `scaling`, lands it through `SkillUse.apply`,
##   runs the mechanism, starts the cooldown, and takes off the statuses the power uses up. A
##   once-per-battle power is written down as spent (C6.5f), and refused with ONCE after that.
##
## SCALING NEVER CHANGES THE DATA. `scaled_skill` works on a copy, so the next use reads the
## kit's own numbers again.
##
## THE HOUR is the `Clock`'s, unless the caller passes one (tests, and a preview at another time).
##
## OWNS: the rules for refusing, aiming, scaling and using a power.
## MUST NOT: draw anything, hold a cooldown (`PowerSet` does), or name a character.

## Why a power cannot be used now. NONE means it can.
enum Reason {
	NONE,
	PASSIVE,  ## A passive power is held, never used.
	NOT_EQUIPPED,  ## The user has no `PowerSet`, or its kit does not hold this power.
	COOLDOWN,  ## Used too recently.
	HOURS,  ## Outside its `active_hours`.
	STATUS,  ## A status it needs is not held.
	POOL,  ## Its `requires_pool` is not full enough.
	BLOCKED,  ## A status forbids skills (a silence).
	COST,  ## The user cannot pay its skill's cost.
	GEAR,  ## The piece or kind of gear it needs is not worn (C7.3).
	ONCE,  ## A once-per-battle power already used in this battle, or in this area (C6.5f).
	UPGRADE,  ## The piece that carries it is not upgraded far enough (C7.5).
}


## Why `user` cannot use `power` now; `Reason.NONE` when it can. `hour` below 0 reads the Clock.
static func refusal(user: Combatant, power: Power, hour: float = -1.0) -> Reason:
	if user == null or power == null:
		return Reason.NOT_EQUIPPED
	if power.passive:
		return Reason.PASSIVE
	var body: Node = user.get_parent()
	var powers: PowerSet = PowerSet.of(body)
	if powers == null or not powers.has(power):
		return Reason.NOT_EQUIPPED
	if power.once_per_battle and powers.once.spent(power.power_id):
		return Reason.ONCE
	if powers.cooldown_left(power.power_id) > 0.0:
		return Reason.COOLDOWN
	if not power.active_at(_hour(hour)):
		return Reason.HOURS
	if power.requires_gear != &"" and not GearSet.wearing(body, power.requires_gear):
		return Reason.GEAR
	if not GearUpgrades.unlocks(body, power):
		return Reason.UPGRADE
	var statuses: StatusSet = StatusSet.of(body)
	for status_id: StringName in power.requires_statuses:
		if statuses == null or statuses.stacks(status_id) == 0:
			return Reason.STATUS
	if power.requires_fraction > 0.0 and _fraction(user, power.requires_pool) < power.requires_fraction:
		return Reason.POOL
	if statuses != null and statuses.blocker(StatusEffect.Block.NO_SKILLS) != &"":
		return Reason.BLOCKED
	if power.skill != null and not SkillUse.affordable(user, power.skill):
		return Reason.COST
	return Reason.NONE


## Who `power` would land on if `user` used it now in the field: the same aiming as a field
## command with its skill (`FieldCommands.targets`). Empty for a power with no skill.
static func targets(user: Combatant, power: Power) -> Array[Combatant]:
	if power == null or power.skill == null:
		return []
	var command := BattleCommand.new()
	command.kind = BattleCommand.Kind.SKILL
	command.skill = power.skill
	return FieldCommands.targets(user, command)


## `user` uses `power` on `targets` now. False, changing nothing, when `refusal` has a reason,
## or when its skill aims at others and nobody was given. `hour` below 0 reads the Clock.
static func use(user: Combatant, power: Power, aimed: Array[Combatant],
		rng: RandomNumberGenerator, hour: float = -1.0) -> bool:
	if refusal(user, power, hour) != Reason.NONE:
		return false
	var skill: Skill = power.skill
	if skill != null and aimed.is_empty() and skill.toggle_status == null:
		return false
	var body: Node = user.get_parent()
	if skill != null:
		SkillUse.pay(user, skill)
		SkillUse.apply(user, scaled_skill(user, power, aimed, hour), aimed, rng)
	else:
		PassiveMoments.skill(user, [])
	var powers: PowerSet = PowerSet.of(body)
	var running: PowerExecutor = powers.executor(power.power_id)
	if running != null:
		running.use(user, aimed, rng)
	powers.start_cooldown(power)
	if power.once_per_battle:
		powers.once.spend(power.power_id)
	powers.used(power)
	var statuses: StatusSet = StatusSet.of(body)
	if statuses != null:
		for status_id: StringName in power.consumes_statuses:
			statuses.cure(status_id)
	return true


## `power`'s skill as it would land now: a copy with its power, hits and status durations
## changed by the power's `scaling`. The skill itself when nothing scales it. A rule reading a
## target's tag reads the first of `aimed`.
static func scaled_skill(user: Combatant, power: Power, aimed: Array[Combatant],
		hour: float = -1.0) -> Skill:
	var skill: Skill = power.skill
	if skill == null or power.scaling.is_empty():
		return skill
	var target: Combatant = aimed[0] if not aimed.is_empty() else null
	var strength: float = multiplier(user, power, PowerScaling.Affects.POWER, target, hour)
	var hits: float = multiplier(user, power, PowerScaling.Affects.HITS, target, hour)
	var lasting: float = multiplier(user, power, PowerScaling.Affects.DURATION, target, hour)
	var copy: Skill = skill.duplicate() as Skill
	copy.power = skill.power * strength
	copy.hits = maxi(1, roundi(maxi(1, skill.hits) * hits))
	var effects: Array[SkillEffect] = []
	for effect: SkillEffect in skill.effects:
		effects.append(_scaled_effect(effect, strength))
	copy.effects = effects
	var statuses: Array[StatusEffect] = []
	for status: StatusEffect in skill.statuses:
		var longer: StatusEffect = status.duplicate() as StatusEffect if status != null else null
		if longer != null:
			longer.duration = status.duration * lasting
		statuses.append(longer)
	copy.statuses = statuses
	return copy


## The product of every one of `power`'s scaling rules that `affects` this, read now. 1 when
## none does. A mechanism reads its COUNT this way.
static func multiplier(user: Combatant, power: Power, affects: PowerScaling.Affects,
		target: Combatant = null, hour: float = -1.0) -> float:
	var total: float = 1.0
	for rule: PowerScaling in power.scaling:
		if rule != null and rule.affects == affects:
			total *= rule.multiplier(_reading(user, rule, target, hour))
	return total


## A rule's source, read as 0 to 1. See `PowerScaling.Source`.
static func _reading(user: Combatant, rule: PowerScaling, target: Combatant, hour: float) -> float:
	match rule.source:
		PowerScaling.Source.USER_HP_FRACTION:
			return _fraction(user, user.damage_pool)
		PowerScaling.Source.USER_MISSING_HP:
			return 1.0 - _fraction(user, user.damage_pool)
		PowerScaling.Source.POOL_FRACTION:
			return _fraction(user, rule.pool)
		PowerScaling.Source.CLOCK_CURVE:
			return _hour(hour) / 24.0
		PowerScaling.Source.TARGET_HAS_TAG:
			return 1.0 if _holds_tag(target, rule.tag) else 0.0
	return 0.0


## How full `pool` is, 0 to 1. 0 for a pool with no maximum.
static func _fraction(user: Combatant, pool: StringName) -> float:
	var vitals: Vitals = Vitals.of(user.get_parent())
	if vitals == null or pool == &"" or vitals.maximum(pool) <= 0:
		return 0.0
	return float(vitals.current(pool)) / float(vitals.maximum(pool))


static func _holds_tag(target: Combatant, tag: StringName) -> bool:
	if target == null:
		return false
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	if statuses == null:
		return false
	for status: StatusEffect in statuses.held():
		if status.tags.has(tag):
			return true
	return false


## An effect's amount scaled, on a copy. A revive's amount is a fraction of max hp and a cure
## or dispel has none, so those are left alone.
static func _scaled_effect(effect: SkillEffect, strength: float) -> SkillEffect:
	if effect == null:
		return null
	match effect.kind:
		SkillEffect.Kind.DAMAGE, SkillEffect.Kind.HEAL, SkillEffect.Kind.RESTORE, SkillEffect.Kind.DRAIN:
			var copy: SkillEffect = effect.duplicate() as SkillEffect
			copy.amount = effect.amount * strength
			return copy
	return effect


## `hour` when the caller gave one (0 or more), else the Clock's hour with its minutes.
static func _hour(hour: float) -> float:
	if hour >= 0.0:
		return hour
	return Clock.minutes_today() / 60.0
