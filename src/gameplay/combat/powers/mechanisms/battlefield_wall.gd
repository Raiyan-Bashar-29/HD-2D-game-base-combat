class_name BattlefieldWall
extends RefCounted
## The edge of a closed battlefield in the field (C6.9d): a fighter inside that would walk past
## `radius` from the caster is walked back to the edge.
##
## IN PLAIN WORDS: a closed battlefield is a barrier. `BattlefieldRun._refresh` keeps those already
## inside inside, and this holds their bodies at the edge each tick. It only moves bodies; it does
## not decide who is inside, and it changes no statuses or modifiers.
##
## OWNS: holding a closed battlefield's fighters at its edge, the pull and push (`drift`), and the
## body step they share (`step_body`).
## MUST NOT: decide who is inside, or change statuses, modifiers or hit points.

## Walks each fighter in `inside` (a list of `Combatant`s) that stands beyond `radius` from `me`
## back onto the edge, along the line to `me`.
static func hold(me: Combatant, radius: float, inside: Array) -> void:
	var centre := me.get_parent() as Node3D
	if centre == null or radius <= 0.0:
		return
	for value: Variant in inside:
		var other := value as Combatant
		if other == null or other.get_parent() == null:
			continue
		var body := other.get_parent() as Node3D
		if body == null:
			continue
		var gap: Vector3 = body.global_position - centre.global_position
		gap.y = 0.0
		if gap.length() > radius:
			step_body(body, gap.normalized() * radius - gap)


## Draws each standing fighter of `members` toward `me` (`speed` above 0, a pull) or away (below
## 0, a push) for `seconds`, on the ground, never past `me`. `me` itself never moves. Moved here
## from `BattlefieldRun` in C6.9f, to keep that file in its budget.
static func drift(me: Combatant, members: Array[Combatant], speed: float, seconds: float) -> void:
	var centre := me.get_parent() as Node3D
	if is_zero_approx(speed) or centre == null:
		return
	for other: Combatant in members:
		var body: Node3D = (other.get_parent() as Node3D) if is_instance_valid(other) else null
		var vitals: Vitals = Vitals.of(body) if body != null else null
		if other == me or body == null or vitals == null or vitals.is_defeated():
			continue
		var gap: Vector3 = centre.global_position - body.global_position
		gap.y = 0.0
		if gap.length() < 0.001:
			continue
		step_body(body, gap.normalized() * minf(speed * seconds, gap.length()))


## Moves `body` by `step` on the ground. A physics body slides and stops at walls; any other moves
## outright. The pull, the push and the wall all move bodies this way.
static func step_body(body: Node3D, step: Vector3) -> void:
	var mover := body as CharacterBody3D
	if mover != null:
		mover.move_and_collide(step)
	else:
		body.global_position += step
