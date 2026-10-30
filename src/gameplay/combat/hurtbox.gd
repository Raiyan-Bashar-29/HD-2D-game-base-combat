class_name Hurtbox
extends Area3D
## The part of a fighter that can be hit in real time (C3.3). Put it under the actor, beside
## the actor's `Combatant`, with a CollisionShape3D child of its own.
##
## IN PLAIN WORDS: a `Hitbox` that touches this calls `take`, and `take` decides what the hit
## does. It refuses a hit from its own fighter, from an ally (by the faction table, as in a
## turn-based battle), or on a fighter already down. During i-frames it lets the hit pass and
## announces a dodge. Otherwise it resolves the hit:
## - a move wrapping a `Skill` goes through `SkillUse.apply`, exactly as in a turn-based battle;
## - a plain move hits `hits` times for its `power` and `element`, and each hit that lands chips
##   a matching weakness (`Weakness.strike`).
## Then, if anything landed, its `poise` wears the shield (`Weakness.wear`) and its `knockback`
## asks for a push away from where the hit came from (`Events.knockback_requested`).
##
## `timeline` is set by whoever runs this fighter's moves (C3.4's fighter, C3.7's enemy), so a
## dodge's i-frames are read from the same clock that plays the dodge.
##
## OWNS: whether one real-time hit counts, and resolving it on this fighter.
## MUST NOT: move the body, decide what defeat means, or remember who struck it: once per swing
## is the `Hitbox`'s rule.

## Every hurtbox in the tree joins this group, so a `LockOn` can find targets without
## asking the physics engine (C3.5).
const GROUP: StringName = &"combat_hurtboxes"

## The clock of this fighter's own moves; null means it never has i-frames.
var timeline: MoveTimeline


func _ready() -> void:
	collision_layer = CombatLayers.HURTBOX
	collision_mask = CombatLayers.HURTBOX_MASK
	# Hurtboxes are found by hitboxes; they do not look for anything themselves.
	monitoring = false
	monitorable = true
	add_to_group(GROUP)


## The combatant this hurtbox belongs to: the `Combatant` beside it under the same actor.
func fighter() -> Combatant:
	return Combatant.of(get_parent())


## `attacker` struck this with `move`, from the point `from`. True when the hit counted:
## resolved on this fighter, whether or not it then missed. False when refused or dodged.
func take(attacker: Combatant, move: ActionMove, rng: RandomNumberGenerator, from: Vector3) -> bool:
	var target: Combatant = fighter()
	if attacker == null or move == null or target == null or target == attacker:
		return false
	var filter: FactionTable.Target = move.skill.target if move.skill != null else FactionTable.Target.ENEMY
	var vitals: Vitals = Vitals.of(get_parent())
	if not attacker.can_target(target, filter) or vitals == null or vitals.is_defeated():
		return false
	if timeline != null and timeline.invulnerable():
		Events.attack_dodged.emit(target.combatant_id, attacker.combatant_id)
		return true
	var landed: bool = _resolve(attacker, move, target, rng)
	if landed:
		Weakness.wear(target, move.poise)
		_push(target, move, from)
	return true


## Resolves the hit itself. True when at least one hit landed (did not miss).
func _resolve(attacker: Combatant, move: ActionMove, target: Combatant,
		rng: RandomNumberGenerator) -> bool:
	if move.skill != null:
		# A skill lands the way it does in a battle: power, effects, statuses, reflect and all.
		# It does not report misses one by one, so poise and knockback treat it as landed.
		SkillUse.apply(attacker, move.skill, [target], rng)
		return true
	var keys: Array[StringName] = [move.element]
	keys.append_array(attacker.attack_tags)
	var landed: bool = false
	for i: int in maxi(1, move.hits):
		var result: DamageResult = attacker.hit(target, move.power, move.element, rng)
		if result != null and not result.missed:
			landed = true
			Weakness.strike(target, keys)
	return landed


## Asks for a push away from `from`, flat on the ground, `move.knockback` metres long.
func _push(target: Combatant, move: ActionMove, from: Vector3) -> void:
	if move.knockback <= 0.0:
		return
	var away: Vector3 = global_position - from
	away.y = 0.0
	# Struck from exactly above or inside: push the way this hurtbox faces is away from.
	if away.length_squared() < 0.0001:
		away = global_transform.basis.z
	Events.knockback_requested.emit(target.combatant_id, away.normalized() * move.knockback)
