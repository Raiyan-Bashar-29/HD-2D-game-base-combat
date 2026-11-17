class_name DefenceWatch
extends Node
## The defence prompt of the hybrid (C8.20): "Evade!" or "Block!" just before a foe's hit lands.
##
## IN PLAIN WORDS: one sits on the player's body when the loadout has ATB rules (the hybrid).
## Each physics frame it looks for a threat to the player:
## - a foe whose move is winding up (STARTUP) and whose swing reaches the player;
## - a foe's live shot heading at the player and at most `WARN` seconds away.
## The first frame it sees a new threat (a swing or a shot) it emits
## `Events.defence_prompt(kind, seconds)`: BLOCK when the player wears a timed-block guard
## (`BarrierMechanism` TIMED_BLOCK, C6.6b), else EVADE; `seconds` is the time left before the hit.
## When no threat is left it emits `&""`. The dodge and the timed block already do what the
## prompt asks; this only warns.
##
## OWNS: deciding when to warn and what to ask for.
## MUST NOT: dodge, block, or change any hit.

const EVADE: StringName = &"evade"
const BLOCK: StringName = &"block"
## Seconds of a shot's travel before it is a threat.
const WARN: float = 0.5
## Metres added to a swing's reach, so the prompt comes a little early rather than late.
const REACH_PAD: float = 0.5

## How many prompts this node has emitted, for a test to count.
var shown: int = 0

var _seen: Dictionary[String, bool] = {}
var _open: bool = false


func _physics_process(_delta: float) -> void:
	watch()


## Warns of every new threat now. Public so a test steps it without waiting for frames.
func watch() -> void:
	var body: Node3D = get_parent() as Node3D
	var me: Combatant = Combatant.of(body) if body != null else null
	if me == null:
		return
	var threats: Dictionary[String, float] = _swings(body, me)
	threats.merge(_shots(body, me))
	for key: String in threats:
		if not _seen.has(key):
			_seen[key] = true
			shown += 1
			_open = true
			Events.defence_prompt.emit(_kind(body), threats[key])
	if threats.is_empty() and _open:
		_open = false
		_seen.clear()
		Events.defence_prompt.emit(&"", 0.0)


# Foes winding up a swing that reaches the player: key -> seconds before it lands.
func _swings(body: Node3D, me: Combatant) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		var foe: Combatant = hurtbox.fighter() if hurtbox != null else null
		var clock: MoveTimeline = hurtbox.timeline if hurtbox != null else null
		if foe == null or foe == me or clock == null or clock.move == null \
				or clock.phase != MoveTimeline.Phase.STARTUP or not foe.can_target(me, FactionTable.Target.ENEMY):
			continue
		var from: Node3D = hurtbox.get_parent() as Node3D
		var reach: float = absf(clock.move.hitbox_offset.z) + clock.move.hitbox_size.z * 0.5 + REACH_PAD
		if from != null and _flat(from.global_position - body.global_position).length() <= reach:
			out["%d:%d" % [from.get_instance_id(), clock.swing]] = maxf(0.0, clock.move.startup - clock.elapsed)
	return out


# Foes' live shots heading at the player within `WARN` seconds.
func _shots(body: Node3D, me: Combatant) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for node: Node in get_tree().get_nodes_in_group(Projectile.GROUP):
		var shot: Projectile = node as Projectile
		if shot == null or shot.gone() or shot.attacker == null or shot.speed <= 0.0 \
				or not shot.attacker.can_target(me, FactionTable.Target.ENEMY):
			continue
		var to: Vector3 = _flat(body.global_position - shot.global_position)
		var seconds: float = to.length() / shot.speed
		if seconds <= WARN and _flat(shot.direction).normalized().dot(to.normalized()) > 0.5:
			out[str(shot.get_instance_id())] = seconds
	return out


# BLOCK when the player wears a timed-block guard, else EVADE.
func _kind(body: Node3D) -> StringName:
	for child: Node in body.get_children():
		if child is PowerSet:
			for power: Power in (child as PowerSet).powers():
				var guard: BarrierMechanism = power.mechanism as BarrierMechanism
				if guard != null and guard.mode == BarrierMechanism.Mode.TIMED_BLOCK:
					return BLOCK
	return EVADE


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
