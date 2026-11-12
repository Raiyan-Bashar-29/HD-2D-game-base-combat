class_name BattlefieldWall
extends RefCounted
## The edge of a closed battlefield in the field (C6.9d): a fighter inside that would walk past
## `radius` from the caster is walked back to the edge.
##
## IN PLAIN WORDS: a closed battlefield is a barrier. `BattlefieldRun._refresh` keeps those already
## inside inside, and this holds their bodies at the edge each tick. It only moves bodies; it does
## not decide who is inside, and it changes no statuses or modifiers.
##
## OWNS: holding a closed battlefield's fighters at its edge, and the body step the pull and push
## share (`step_body`).
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


## Moves `body` by `step` on the ground. A physics body slides and stops at walls; any other moves
## outright. The pull, the push and the wall all move bodies this way.
static func step_body(body: Node3D, step: Vector3) -> void:
	var mover := body as CharacterBody3D
	if mover != null:
		mover.move_and_collide(step)
	else:
		body.global_position += step
