class_name Unseen
extends RefCounted
## Unseen fighters (C8.12): a status that stops foes choosing its holder as a target.
##
## IN PLAIN WORDS: a fighter holding a status marked `unseen` cannot be picked by a foe: not in
## a battle's target list, not by lock-on, not by a field enemy or follower looking for someone
## to attack. Allies still see it (a heal reaches it). It is not untouchable: a skill that hits
## everyone, or a swing that happens to pass through it, still lands. It ends when the holder
## hits a foe or is hit by one, and any cure of the status (a DISPEL by its tag) reveals it.
##
## OWNS: what `unseen` means for choosing a target, and when it ends.
## MUST NOT: search for targets itself. `Battle`, `LockOn`, `Hurtbox`, `Aggro` and
## `FieldCommands` each ask `open` in place of `Combatant.can_target`.


## True while `fighter` holds a status marked `unseen`.
static func hides(fighter: Combatant) -> bool:
	var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if fighter != null else null
	if statuses == null:
		return false
	for effect: StatusEffect in statuses.held():
		if effect.unseen:
			return true
	return false


## True when `user` may choose `other` under `filter`: the faction table allows it, and
## `other` is not an unseen foe. A `skill` that hits everyone reaches the unseen too.
static func open(user: Combatant, other: Combatant, filter: FactionTable.Target,
		skill: Skill = null) -> bool:
	if user == null or not user.can_target(other, filter):
		return false
	if skill != null and skill.scope == Skill.Scope.ALL:
		return true
	return not (hides(other) and user.can_target(other, FactionTable.Target.ENEMY))


## Ends every `unseen` status `fighter` holds. Returns how many ended.
static func reveal(fighter: Combatant) -> int:
	var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if fighter != null else null
	var ended: int = 0
	if statuses == null:
		return ended
	for effect: StatusEffect in statuses.held():
		if effect.unseen and statuses.cure(effect.id):
			ended += 1
	return ended


## `attacker` hit at `target`: when they are foes, both are seen from now on.
static func struck(attacker: Combatant, target: Combatant) -> void:
	if attacker == null or target == null \
			or not attacker.can_target(target, FactionTable.Target.ENEMY):
		return
	reveal(attacker)
	reveal(target)
