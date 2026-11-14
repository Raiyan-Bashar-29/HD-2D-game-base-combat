class_name Hurtbox
extends Area3D
## The part of a fighter that can be hit in real time (C3.3). Put it under the actor, beside
## the actor's `Combatant`, with a CollisionShape3D child of its own.
##
## IN PLAIN WORDS: a `Hitbox` that touches this calls `take`, and `take` decides what the hit
## does. It refuses a hit from its own fighter, from an ally (by the faction table, as in a
## turn-based battle), or on a fighter already down. During i-frames it lets the hit pass and
## announces a dodge; inside the dodge's `perfect_window` it also announces a perfect dodge
## (`Events.perfect_dodge`, C6.6c). Otherwise it resolves the hit:
## - a move wrapping a `Skill` goes through `SkillUse.apply`, exactly as in a turn-based battle;
## - a plain move hits `hits` times for its `power` and `element`, and each hit that lands chips
##   a matching weakness (`Weakness.strike`).
## Then, if anything landed, its `poise` wears the shield (`Weakness.wear`) and its `knockback`
## asks for a push away from where the hit came from (`Events.knockback_requested`).
##
## NO FLINCH (C6.6c): the push is scaled by 1 plus the target's `knockback_taken` stat, never
## below 0. At -1 there is no push at all, so no stun either: the fighter keeps its swing (super
## armor, "will not flinch"). The player, enemies and followers all flinch only on that push, so
## this one place covers them all.
##
## COUNTER (C6.6d, M13 counter stance): when a hit lands, or a barrier blocks it, on a fighter
## holding a COUNTER status (`SkillUse.counter_stance` says whether it answers), the fighter
## answers. With the status's `counter_move` and a `timeline`, that move starts on the fighter's
## own clock, so its own hitbox swings it; otherwise the attacker is struck at once
## (`SkillUse.answer`). A countered hit does not push (the stance stands firm, and a push would
## cancel the counter), and a hit arriving while that counter already plays is not answered
## again. `Events.countered` is announced either way. A parry is a timed block whose status
## counters: the perfect press stops the hit, and the counter answers it.
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

## What became of a hit: every hit missed, at least one was blocked and none landed, or one landed.
enum Outcome { MISSED, BLOCKED, LANDED }

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


## The nearest standing hurtbox that `body`'s fighter may attack (the faction table calls it an
## enemy), or null. A real-time enemy (C3.7) and a fighting party follower (C4.9) both pick
## their target with this.
static func nearest_hostile(body: Node3D) -> Hurtbox:
	var me: Combatant = Combatant.of(body)
	if me == null or not body.is_inside_tree():
		return null
	var best: Hurtbox = null
	var best_distance: float = INF
	for node: Node in body.get_tree().get_nodes_in_group(GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox == null or not me.can_target(hurtbox.fighter(), FactionTable.Target.ENEMY):
			continue
		var vitals: Vitals = Vitals.of(hurtbox.get_parent())
		var distance: float = body.global_position.distance_to(hurtbox.global_position)
		if (vitals == null or not vitals.is_defeated()) and distance < best_distance:
			best = hurtbox
			best_distance = distance
	return best


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
		if timeline.perfectly():
			Events.perfect_dodge.emit(target.combatant_id, attacker.combatant_id)
		return true
	var outcome: Outcome = _resolve(attacker, move, target, rng)
	var countered: bool = outcome != Outcome.MISSED and _counter(attacker, target, rng)
	if outcome == Outcome.LANDED:
		Weakness.wear(target, move.poise)
		if not countered:
			_push(target, move, from)
	return true


## `target` answers `attacker` when it holds a counter stance that fires (C6.6d). True when it did.
func _counter(attacker: Combatant, target: Combatant, rng: RandomNumberGenerator) -> bool:
	var stance: StatusEffect = SkillUse.counter_stance(attacker, target, rng)
	if stance == null:
		return false
	var move: ActionMove = stance.counter_move
	if move != null and timeline != null:
		# Already swinging this counter: the stance holds, and the counter is not begun again.
		if timeline.busy() and timeline.move == move:
			return true
		timeline.start(move)
	else:
		# No clock to swing it on: the counter lands at once, with the move's numbers if it has one.
		SkillUse.answer(target, attacker, move, rng)
	Events.countered.emit(target.combatant_id, attacker.combatant_id)
	return true


## Resolves the hit itself, and says what became of it.
func _resolve(attacker: Combatant, move: ActionMove, target: Combatant,
		rng: RandomNumberGenerator) -> Outcome:
	if move.skill != null:
		# A skill lands the way it does in a battle: power, effects, statuses, reflect and all.
		# It does not report misses one by one, so poise and knockback treat it as landed.
		SkillUse.apply(attacker, move.skill, [target], rng)
		BattlefieldRun.breaks(target, move.skill.tags)
		return Outcome.LANDED
	# A move with no element of its own takes the worn weapon's, and its tags too (C7.1c).
	var element: StringName = attacker.strike_element(move.element)
	var keys: Array[StringName] = [element]
	keys.append_array(attacker.strike_tags())
	var outcome: Outcome = Outcome.MISSED
	for i: int in maxi(1, move.hits):
		var result: DamageResult = attacker.hit(target, move.power, element, rng)
		if result == null or result.missed:
			continue
		# A hit a barrier stopped whole did not land: no shield chip, no poise, no push (C6.6a).
		if result.blocked:
			outcome = maxi(outcome, Outcome.BLOCKED) as Outcome
		else:
			outcome = Outcome.LANDED
			Weakness.strike(target, keys)
			# A landed hit may bring down a battlefield on its target (C6.9c).
			BattlefieldRun.breaks(target, result.tags)
	return outcome


## Asks for a push away from `from`, flat on the ground, `move.knockback` metres long times
## 1 plus the target's `knockback_taken`. Nothing at all when that comes to 0 or less.
func _push(target: Combatant, move: ActionMove, from: Vector3) -> void:
	var distance: float = move.knockback * (1.0 + target.sheet.value(&"knockback_taken"))
	# Inside its own move's armour stretch (C8.16) the fighter takes the hit and is not pushed.
	if distance <= 0.0 or (timeline != null and timeline.armoured()):
		return
	var away: Vector3 = global_position - from
	away.y = 0.0
	# Struck from exactly above or inside: push the way this hurtbox faces is away from.
	if away.length_squared() < 0.0001:
		away = global_transform.basis.z
	Events.knockback_requested.emit(target.combatant_id, away.normalized() * distance)
