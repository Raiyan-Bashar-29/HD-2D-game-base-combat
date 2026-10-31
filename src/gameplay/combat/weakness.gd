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
## PRESSURE AND STAGGER (C4.6): a fighter that lives in real time (`Combatant.real_time`) counts
## in seconds, as FF7 Remake does, so it never gets the turn-counted BROKEN status. Instead:
## - a hit on one of its weaknesses PRESSURES it (`pressured_status()`): for a few seconds it
##   takes double poise, so following up quickly empties the shield sooner;
## - the hit that empties its shield STAGGERS it (`staggered_status()`): it stands still for a
##   few seconds and takes more damage. When the stagger wears off, `recover` refills the shield.
## A game swaps any of the three statuses by setting `broken`, `pressured` or `staggered` once at
## boot.
##
## OWNS: shield points, revealing weaknesses, and when a break starts and ends.
## MUST NOT: decide what a hit is (the caller passes its keys), or skip a turn itself. The
## BROKEN status's SKIP_TURN block does that, through `Battle`'s ordinary rule.

const SHIELD_POOL: StringName = &"shield"
const FLAG_PREFIX: String = "weakness/"

## The status a break applies. Null means the template default from `broken_status()`; a game
## sets its own (a longer stun, a bigger damage bonus) once at boot.
static var broken: StatusEffect
## The status a weakness hit applies to a real-time fighter. Null means `pressured_status()`.
static var pressured: StatusEffect
## The status an emptied shield applies to a real-time fighter. Null means `staggered_status()`.
static var staggered: StatusEffect
static var _default: StatusEffect
static var _default_pressured: StatusEffect
static var _default_staggered: StatusEffect


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


## The status a weakness hit applies in real time: the game's `pressured`, or three seconds of
## taking double poise (the `poise_taken` stat, read by `wear`).
static func pressured_status() -> StatusEffect:
	if pressured != null:
		return pressured
	if _default_pressured == null:
		_default_pressured = StatusEffect.new()
		_default_pressured.id = &"status/pressured"
		_default_pressured.name_key = "ui.combat_status.pressured"
		_default_pressured.unit = StatusEffect.Unit.SECONDS
		_default_pressured.duration = 3.0
		_default_pressured.tags = [&"pressured"]
		_default_pressured.modifiers = [StatModifier.of(&"poise_taken", StatModifier.Op.ADD, 1.0, &"")]
	return _default_pressured


## The status an emptied shield applies in real time: the game's `staggered`, or four seconds
## standing still and taking 60% more damage.
static func staggered_status() -> StatusEffect:
	if staggered != null:
		return staggered
	if _default_staggered == null:
		_default_staggered = StatusEffect.new()
		_default_staggered.id = &"status/staggered"
		_default_staggered.name_key = "ui.combat_status.staggered"
		_default_staggered.unit = StatusEffect.Unit.SECONDS
		_default_staggered.duration = 4.0
		_default_staggered.blocks = [StatusEffect.Block.SKIP_TURN]
		_default_staggered.tags = [&"broken", &"staggered"]
		_default_staggered.modifiers = [StatModifier.of(&"damage_taken", StatModifier.Op.ADD, 0.6, &"")]
	return _default_staggered


## A hit that LANDED on `target` carried `keys` (its element and tags). Reveals each weakness it
## matched and takes one shield point; true when that point broke the target.
static func strike(target: Combatant, keys: Array[StringName]) -> bool:
	var matched: bool = false
	for key: StringName in keys:
		if key != &"" and target.weak_to.has(key):
			matched = true
			_reveal(target, key)
	if not matched:
		return false
	if _chip(target, 1):
		return true
	# Not broken yet: a real-time fighter is pressured, so poise bites harder for a while.
	var statuses: StatusSet = StatusSet.of(target.get_parent())
	var vitals: Vitals = Vitals.of(target.get_parent())
	if target.real_time and statuses != null and vitals != null and vitals.current(SHIELD_POOL) > 0:
		statuses.apply(pressured_status())
	return false


## POISE (C3.3): a real-time hit that LANDED takes `points` from `target`'s shield whatever it
## is weak to, so heavy swings stagger anything with a shield. True when that broke it. A
## pressured target takes more: `points` times 1 plus its `poise_taken` stat (C4.6).
static func wear(target: Combatant, points: int) -> bool:
	if points <= 0:
		return false
	return _chip(target, roundi(points * maxf(0.0, 1.0 + target.sheet.value(&"poise_taken"))))


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
		statuses.apply(_break_for(target))
		# A stagger ends the pressure that led to it.
		if target.real_time:
			statuses.cure(pressured_status().id)
	Events.combatant_broken.emit(target.combatant_id)
	return true


## Refills the shield of a fighter whose break is over: shield at zero, no longer broken.
## `Battle` calls it as each turn begins, after the statuses tick; a real-time fighter calls it
## every frame, after its statuses tick (C4.6).
static func recover(fighter: Combatant) -> void:
	var vitals: Vitals = Vitals.of(fighter.get_parent())
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	if vitals == null or vitals.maximum(SHIELD_POOL) <= 0 or vitals.current(SHIELD_POOL) > 0:
		return
	if statuses != null and statuses.stacks(_break_for(fighter).id) > 0:
		return
	vitals.set_to(SHIELD_POOL, vitals.maximum(SHIELD_POOL))


## The built-in status (broken, pressured or staggered, or a game's override of one) whose id is
## `status_id`, else null. These are made in code, not loaded from `StatusDb`, so a save that
## holds one finds its definition here (C5.2): without this a player saved while staggered
## loaded with an empty shield, no stagger and a warning.
static func built_in(status_id: StringName) -> StatusEffect:
	for effect: StatusEffect in [broken_status(), pressured_status(), staggered_status()]:
		if effect.id == status_id:
			return effect
	return null


## The break that suits `target`'s clock: STAGGERED, counted in seconds, for a real-time
## fighter; BROKEN, counted in turns, in a battle.
static func _break_for(target: Combatant) -> StatusEffect:
	return staggered_status() if target.real_time else broken_status()


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
