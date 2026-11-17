class_name StealRun
extends PowerExecutor
## Runs a steal (C8.13c). Its settings are a `StealMechanism`; read its header for the fields.
##
## IN PLAIN WORDS: a use goes through the targets in order and, for each held status carrying
## the tag, cures it on the target and applies it to the user, until `most` are taken.
##
## OWNS: nothing between uses.
## MUST NOT: touch a status without the tag, or name a character.


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var steal: StealMechanism = mechanism as StealMechanism
	var mine: StatusSet = StatusSet.of(user.get_parent())
	if mine == null:
		return
	var taken: int = 0
	for target: Combatant in targets:
		var theirs: StatusSet = StatusSet.of(target.get_parent()) if target != null else null
		if theirs == null or target == user:
			continue
		for effect: StatusEffect in theirs.held():
			if steal.most > 0 and taken >= steal.most:
				return
			if effect.tags.has(steal.tag) and theirs.cure(effect.id):
				mine.apply(effect, rng, user.combatant_id)
				taken += 1
