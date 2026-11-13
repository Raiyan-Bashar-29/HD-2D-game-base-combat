class_name PassiveMoments
extends RefCounted
## Tells a fighter's passives of the moments no signal carries (C9.2c): a skill or a power
## used, and a form starting or ending. See `docs/PASSIVES.md` § As built (C9.2c).
##
## IN PLAIN WORDS: `SkillUse.apply` and `PowerUse.use` call `skill` once per use, and a
## `FormRun` calls `form` when its holder goes into, or comes out of, a transformation. Each
## call wakes the matching triggers of that fighter's `PassiveSet`; a fighter with no passives
## hears nothing.
##
## OWNS: turning those calls into passive events.
## MUST NOT: decide whether a trigger wakes (`PassiveSet` does), or remember anything.


## `user` used a skill carrying `tags` (none for a power with no skill): SKILL_USED.
static func skill(user: Combatant, tags: Array[StringName]) -> void:
	var passives: PassiveSet = PassiveSet.of(user.get_parent()) if user != null else null
	if passives != null:
		passives.happened(PassiveTrigger.Event.SKILL_USED, tags)


## The fighter under `body` went into a form (`entered`) or came out of one.
static func form(body: Node, entered: bool) -> void:
	var passives: PassiveSet = PassiveSet.of(body)
	if passives != null:
		passives.happened(PassiveTrigger.Event.FORM_ENTERED if entered
			else PassiveTrigger.Event.FORM_LEFT, [])
