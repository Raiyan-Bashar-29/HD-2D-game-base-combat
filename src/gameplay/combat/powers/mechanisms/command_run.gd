class_name CommandRun
extends PowerExecutor
## Runs an M8 command (C6.11) on one fighter. Its settings are a `CommandMechanism`; read its
## header for what each order does and when one is refused.
##
## IN PLAIN WORDS: using the power picks the aimed foe (the first target, else the locked-on
## or nearest foe in the field), checks the foe will take the order, marks it under the once
## flag, puts the status on, and carries out FORGET or FALL.
##
## OWNS: carrying out one order, the refusal test, and the status a forgotten battle foe holds.
## MUST NOT: name a character, or decide who wins a battle (`Battle` reads the statuses).

## The status a battle foe told to FORGET holds: it stands aside, counted as fallen.
const FORGOTTEN: StringName = &"status/command_forgotten"

static var _forgotten: StatusEffect


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var command: CommandMechanism = mechanism as CommandMechanism
	var foe: Combatant = BarrageRun.aim_of(user, targets)
	if _refuses(command, user, foe):
		return
	if command.once_flag != "":
		Flags.set_flag(_flag_of(command, foe), true)
	var statuses: StatusSet = StatusSet.of(foe.get_parent())
	if command.status != null and statuses != null:
		statuses.apply(command.status, rng, user.combatant_id)
	match command.order:
		CommandMechanism.Order.FORGET:
			if foe.real_time:
				foe.get_parent().queue_free()
			elif statuses != null:
				statuses.apply(_forgotten_status(), rng, user.combatant_id)
		CommandMechanism.Order.FALL:
			var vitals: Vitals = Vitals.of(foe.get_parent())
			if vitals != null and not _invincible(statuses):
				vitals.set_to(vitals.defeat_pool, 0)


## True when `foe` does not take `command` from `user`. See `CommandMechanism` for each reason.
## A canceller clears the foe's once flag on the way.
static func _refuses(command: CommandMechanism, user: Combatant, foe: Combatant) -> bool:
	if not BarrageRun.standing(foe) or not user.can_target(foe, FactionTable.Target.ENEMY):
		return true
	if command.immune_tag != &"" and foe.traits.has(command.immune_tag):
		return true
	if command.canceller_tag != &"" and _holds_tag(foe, command.canceller_tag):
		if command.once_flag != "":
			Flags.erase_flag(_flag_of(command, foe))
		return true
	if command.once_flag != "" and Flags.get_bool(_flag_of(command, foe)):
		return true
	return user.real_time and not _in_sight(command, user, foe)


## The flag that says `foe` has answered `command`'s family once.
static func _flag_of(command: CommandMechanism, foe: Combatant) -> StringName:
	return StringName("%s/%s" % [command.once_flag, foe.combatant_id])


## The status a forgotten battle foe holds, built once.
static func _forgotten_status() -> StatusEffect:
	if _forgotten == null:
		_forgotten = StatusEffect.new()
		_forgotten.id = FORGOTTEN
		_forgotten.name_key = "ui.combat_status.forgotten"
		_forgotten.duration = 0.0
		_forgotten.blocks = [StatusEffect.Block.SKIP_TURN]
		_forgotten.counts_as_fallen = true
	return _forgotten


static func _in_sight(command: CommandMechanism, user: Combatant, foe: Combatant) -> bool:
	var body: Node3D = user.get_parent() as Node3D
	var there: Node3D = foe.get_parent() as Node3D
	if body == null or there == null:
		return true
	var to: Vector3 = there.global_position - body.global_position
	to.y = 0.0
	if command.reach > 0.0 and to.length() > command.reach:
		return false
	return not command.sight or to.length() < 0.001 or BarrageRun.facing_of(body).dot(to) > 0.0


static func _holds_tag(fighter: Combatant, tag: StringName) -> bool:
	var statuses: StatusSet = StatusSet.of(fighter.get_parent())
	if statuses != null:
		for held: StatusEffect in statuses.held():
			if held.tags.has(tag):
				return true
	return false


static func _invincible(statuses: StatusSet) -> bool:
	if statuses != null:
		for held: StatusEffect in statuses.held():
			if held.invincible:
				return true
	return false
