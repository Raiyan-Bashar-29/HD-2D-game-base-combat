class_name Weakness
extends RefCounted
## Weakness and Break (C2.17), Octopath-style, as one code path for every formula.
##
## IN PLAIN WORDS: a fighter lists what it is weak to in `Combatant.weak_to`: elements such as
## `fire`, or skill tags such as `sword`. Each hit that lands and matches one of them takes one
## point from its `shield` pool (its size is the `max_shield` stat) and reveals that weakness.
## The hit that takes the last point BREAKS it: it gets `broken_status()`, which by default
## skips its next turn and makes it take half as much damage again. When the break wears off,
## the shield refills.
##
## REVEALED WEAKNESSES ARE FLAGS, `weakness/<kind>/<key>`, so they are saved and persist like a
## bestiary. `kind` is the fighter's kind (`Combatant.kind`, the definition's id), so beating
## one wisp reveals the weakness on every wisp.
##
## C3's poise and C4's pressure reuse `strike` and `recover`; only who calls them changes.
##
## OWNS: shield points, revealing weaknesses, and when a break starts and ends.
## MUST NOT: decide what a hit is (the caller passes its keys), or skip a turn itself. The
## BROKEN status's SKIP_TURN block does that, through `Battle`'s ordinary rule.

const SHIELD_POOL: StringName = &"shield"
const FLAG_PREFIX: String = "weakness/"

## The status a break applies. Null means the template default from `broken_status()`; a game
## sets its own (a longer stun, a bigger damage bonus) once at boot.
static var broken: StatusEffect
static var _default: StatusEffect


## The status a break applies: the game's `broken`, or one turn lost and +50% damage taken.
static func broken_status() -> StatusEffect:
	if broken != null:
		return broken
	if _default == null:
		_default = StatusEffect.new()
		_default.id = &"status/broken"
		_default.duration = 1.0
		_default.blocks = [StatusEffect.Block.SKIP_TURN]
		_default.tags = [&"broken"]
		_default.modifiers = [StatModifier.of(&"damage_taken", StatModifier.Op.ADD, 0.5, &"")]
	return _default


## A hit that LANDED on `target` carried `keys` (its element and tags). Reveals each weakness it
## matched and takes one shield point; true when that point broke the target.
static func strike(target: Combatant, keys: Array[StringName]) -> bool:
	var matched: bool = false
	for key: StringName in keys:
		if key != &"" and target.weak_to.has(key):
			matched = true
			_reveal(target, key)
	return matched and _chip(target, 1)


## POISE (C3.3): a real-time hit that LANDED takes `points` from `target`'s shield whatever it
## is weak to, so heavy swings stagger anything with a shield. True when that broke it.
static func wear(target: Combatant, points: int) -> bool:
	return points > 0 and _chip(target, points)


## Takes `points` of shield; when that empties it, applies the break. True when it broke.
static func _chip(target: Combatant, points: int) -> bool:
	var vitals: Vitals = Vitals.of(target.get_parent())
	if vitals == null or vitals.is_defeated():
		return false
	# A fighter with no shield, or one already at zero (already broken), loses nothing more.
	if vitals.maximum(SHIELD_POOL) <= 0 or vitals.current(SHIELD_POOL) <= 0:
		return false
	if vitals.change(SHIELD_POOL, -points) > 0:
		return false
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	if statuses != null:
		statuses.apply(broken_status())
	Events.combatant_broken.emit(target.combatant_id)
	return true


## Refills the shield of a fighter whose break is over: shield at zero, no longer broken.
## `Battle` calls it as each turn begins, after the statuses tick.
static func recover(fighter: Combatant) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	if vitals == null or vitals.maximum(SHIELD_POOL) <= 0 or vitals.current(SHIELD_POOL) > 0:
		return
	if statuses != null and statuses.stacks(broken_status().id) > 0:
		return
	vitals.set_to(SHIELD_POOL, vitals.maximum(SHIELD_POOL))


## True once `key` has been revealed as a weakness of `fighter`'s kind. The menu shows it (C2.18).
static func revealed(fighter: Combatant, key: StringName) -> bool:
	return Flags.get_bool(_flag(fighter, key))


## The keys a skill's hit carries: its element and its tags.
static func keys_of(skill: Skill) -> Array[StringName]:
	var keys: Array[StringName] = [skill.element]
	keys.append_array(skill.tags)
	return keys


static func _reveal(fighter: Combatant, key: StringName) -> void:
	if revealed(fighter, key):
		return
	Flags.set_flag(_flag(fighter, key), true)
	Events.weakness_revealed.emit(fighter.combatant_id, key)


static func _flag(fighter: Combatant, key: StringName) -> StringName:
	var kind: StringName = fighter.kind if fighter.kind != &"" else fighter.combatant_id
	return StringName(FLAG_PREFIX + String(kind) + "/" + String(key))
