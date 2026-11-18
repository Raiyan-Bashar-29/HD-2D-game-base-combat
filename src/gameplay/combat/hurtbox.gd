class_name Hurtbox
extends Area3D
## The part of a fighter that can be hit in real time (C3.3). Put it under the actor, beside
## the actor's `Combatant`, with a CollisionShape3D child of its own.
##
## IN PLAIN WORDS: a `Hitbox` that touches this calls `take`, and `take` decides what the hit
## does. It refuses a hit from its own fighter, from an ally (by the faction table, as in a
## turn-based battle), or on a fighter already down. During i-frames it lets the hit pass and
## announces a dodge; inside the dodge's `perfect_window` it also announces a perfect dodge
## (`Events.perfect_dodge`, C6.6c); the fighter's `perfect_window` stat widens that window
## (ADD 0.5 = 1.5 times, C6.10b). Otherwise it resolves the hit:
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
## LAUNCH (C8.8a): a landed hit whose move has a `launch` time, or any landed hit on a fighter
## already in the air, lifts the fighter (`Juggle.lift`) and drops its swing, unless the hit was
## countered, the fighter is in an armour stretch, or it does not flinch at all.
##
## INTERRUPT (C8.8c): a landed hit of a move that `interrupts` stops this fighter's own move
## while it is winding up or in its armour stretch, and stuns it as a push does.
## PROMPT (C8.8c): `boost` multiplies a plain move's power; the `Hitbox` passes what the
## attacker's timed press earned.
##
## FOLLOW-UPS (C8.22c): a landed hit that took hp lets the attacker's allies near this fighter
## follow up (`FieldFollowUps`), as a battle's attack or one-target skill does.
##
## `flinched` says whether the last hit moved the fighter at all: it landed, was not countered,
## and the fighter flinches. A grab (C8.8b) holds only a fighter that flinched.
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
## The stat that widens this fighter's perfect-dodge window (C6.10b).
const PERFECT_WINDOW: StringName = &"perfect_window"

## What became of a hit: every hit missed, at least one was blocked and none landed, or one landed.
enum Outcome { MISSED, BLOCKED, LANDED }

## The clock of this fighter's own moves; null means it never has i-frames.
var timeline: MoveTimeline
## True when the last hit `take` resolved landed (not missed, blocked, dodged or refused).
var landed: bool = false
## True when that hit also made the fighter flinch: not countered, no armour, not unflinching.
var flinched: bool = false
## True when that hit stopped this fighter's move as an interrupt (C8.8c).
var interrupted: bool = false


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
		if hurtbox == null or not Unseen.open(me, hurtbox.fighter(), FactionTable.Target.ENEMY):
			continue
		var vitals: Vitals = Vitals.of(hurtbox.get_parent())
		var distance: float = body.global_position.distance_to(hurtbox.global_position)
		if (vitals == null or not vitals.is_defeated()) and distance < best_distance:
			best = hurtbox
			best_distance = distance
	return best


## `attacker` struck this with `move`, from the point `from`. True when the hit counted:
## resolved on this fighter, whether or not it then missed. False when refused or dodged.
func take(attacker: Combatant, move: ActionMove, rng: RandomNumberGenerator, from: Vector3,
		boost: float = 1.0) -> bool:
	var target: Combatant = fighter()
	landed = false
	flinched = false
	interrupted = false
	if attacker == null or move == null or target == null or target == attacker:
		return false
	var filter: FactionTable.Target = move.skill.target if move.skill != null else FactionTable.Target.ENEMY
	var vitals: Vitals = Vitals.of(get_parent())
	if not attacker.can_target(target, filter) or vitals == null or vitals.is_defeated():
		return false
	if timeline != null and timeline.invulnerable():
		Events.attack_dodged.emit(target.combatant_id, attacker.combatant_id)
		if timeline.perfectly(target.sheet.value(PERFECT_WINDOW)):
			Events.perfect_dodge.emit(target.combatant_id, attacker.combatant_id)
		return true
	var before: int = vitals.current(target.damage_pool)
	var outcome: Outcome = _resolve(attacker, move, target, rng, boost)
	var countered: bool = outcome != Outcome.MISSED and _counter(attacker, target, rng)
	landed = outcome == Outcome.LANDED
	if landed:
		Weakness.wear(target, move.poise)
		# Allies near the foe holding a follow-up stance strike it too (C8.22c), when the hit really
		# took hp: a skill move counts as landed even when it missed or bounced (C8.24).
		if vitals.current(target.damage_pool) < before:
			FieldFollowUps.after_hit(attacker, target, rng)
		if not countered:
			_interrupt(target, move)
			_push(target, move, from)
			flinched = target.sheet.value(&"knockback_taken") > -1.0 \
				and not (timeline != null and timeline.armoured())
			_launch(move)
	return true


# A move that interrupts stops this fighter's wind-up or armoured move, and stuns it (C8.8c).
func _interrupt(target: Combatant, move: ActionMove) -> void:
	if not move.interrupts or timeline == null or not timeline.busy():
		return
	if timeline.phase != MoveTimeline.Phase.STARTUP and not timeline.armoured():
		return
	if target.sheet.value(&"knockback_taken") <= -1.0:
		return
	timeline.cancel()
	interrupted = true
	# A move with no push of its own still stuns: a push of no length.
	if move.knockback <= 0.0:
		Events.knockback_requested.emit(target.combatant_id, Vector3.ZERO)


# Lifts the fighter off its feet (C8.8a) when the move launches or it is already in the air.
func _launch(move: ActionMove) -> void:
	var body: Node = get_parent()
	if not flinched or (move.launch <= 0.0 and not Juggle.airborne(body)):
		return
	Juggle.lift(body, move)
	if timeline != null:
		timeline.cancel()


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


# What a wrapped skill's hits on `target` came to: landed if any landed, else blocked if any was,
# else missed. A skill with no hit (a pure status) has landed.
static func _skill_outcome(target: Combatant) -> Outcome:
	var outcome: Outcome = Outcome.LANDED if not SkillUse.struck.has(target) else Outcome.MISSED
	for i: int in SkillUse.struck.size():
		if SkillUse.struck[i] != target or SkillUse.results[i].missed:
			continue
		if not SkillUse.results[i].blocked:
			return Outcome.LANDED
		outcome = Outcome.BLOCKED
	return outcome


## Resolves the hit itself, and says what became of it.
func _resolve(attacker: Combatant, move: ActionMove, target: Combatant,
		rng: RandomNumberGenerator, boost: float) -> Outcome:
	if move.skill != null:
		# A skill lands the way it does in a battle: power, effects, statuses, reflect and all,
		# grown by a timed press, and says whether its hits on `target` missed or were blocked
		# (C10.16), so poise and knockback follow what really happened.
		var skill: Skill = move.skill
		if boost != 1.0:
			skill = move.skill.duplicate() as Skill
			skill.power *= boost
		SkillUse.struck.clear()
		SkillUse.results.clear()
		SkillUse.apply(attacker, skill, [target], rng)
		BattlefieldRun.breaks(target, move.skill.tags)
		return _skill_outcome(target)
	# A move with no element of its own takes the worn weapon's, and its tags too (C7.1c).
	var element: StringName = attacker.strike_element(move.element)
	var keys: Array[StringName] = [element]
	keys.append_array(attacker.strike_tags())
	var outcome: Outcome = Outcome.MISSED
	# Hits spaced in time land one a strike; the hitbox strikes again after the gap (C10.16).
	for i: int in (1 if move.hit_gap > 0.0 else maxi(1, move.hits)):
		# Foresight's observe knows a move by its key (C6.10).
		Foresight.striking = StringName("move_%d" % move.get_instance_id())
		var result: DamageResult = attacker.hit(target, move.power * boost, element, rng)
		Foresight.striking = &""
		if result == null or result.missed:
			continue
		# A hit a barrier stopped whole did not land: no shield chip, no poise, no push (C6.6a).
		if result.blocked:
			outcome = maxi(outcome, Outcome.BLOCKED) as Outcome
		else:
			outcome = Outcome.LANDED
			Weakness.strike(target, keys)
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
