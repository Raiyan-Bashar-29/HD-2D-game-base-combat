class_name FallNet
extends RefCounted
## The fall safety net (C5.8): what happens to a field fighter that drops off the world.
##
## IN PLAIN WORDS: a body knocked off a floor's open edge would fall for ever. Below the kill
## height (the project setting `combat/field/kill_height`) `catch` deals with it: it can put
## the body back at a safe place, and it can fell the fighter so the usual defeat follows (a
## foe's loot and experience, the player's `DefeatRule`).
## - A field foe is felled where it is, or, with `returns_home` on, put back at its home unhurt.
## - The player is put back on the last floor they stood on, then felled.
##
## OWNS: the kill height and what crossing it does.
## MUST NOT: decide what a defeat means, or watch bodies itself. `ActionEnemy` and
## `ActionFighter` ask each physics frame.

const SETTING: String = "combat/field/kill_height"
const DEFAULT_HEIGHT: float = -50.0


## The height below which a body has fallen out of the world.
static func height() -> float:
	var configured: float = ProjectSettings.get_setting(SETTING, DEFAULT_HEIGHT)
	return configured


## Deals with `body` if it is below the kill height, and returns true when it was. `back_to`,
## when it is a real place, is where the body is put (its speed cleared); `fell` empties the
## fighter's defeat pool.
static func catch(body: Node3D, back_to: Vector3, fell: bool) -> bool:
	if body == null or body.global_position.y >= height():
		return false
	if back_to.is_finite():
		body.global_position = back_to
		var mover: CharacterBody3D = body as CharacterBody3D
		if mover != null:
			mover.velocity = Vector3.ZERO
	var vitals: Vitals = Vitals.of(body)
	if fell and vitals != null and not vitals.is_defeated():
		vitals.set_to(vitals.defeat_pool, 0)
	return true
