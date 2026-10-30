class_name FieldCommands
extends RefCounted
## Using a skill or an item in the field, mid-fight (C4.3): the hybrid formula's twin of
## `Battle.allows` and `Battle.act`.
##
## IN PLAIN WORDS: in the hybrid, the player opens a menu while fighting and picks a spell or an
## item. This file answers the menu's three questions about one `BattleCommand`:
## - `targets`: who it would land on. An enemy skill goes to the locked target, or the nearest
##   foe in reach; "all enemies" to every foe in reach; a self or ally skill to the user.
##   `candidates` is everyone it could land on, from which a thinking ally picks (C4.8).
## - `refusal`: why it cannot be used now, as a `Reason`: no ATB, a status forbids it, the mp is
##   short, the item has run out, or there is nobody to aim at. `Reason.NONE` means it can. The
##   menu (C4.4, in `ui`) turns a reason into words; this file is gameplay and names no text.
## - `use`: does it. It spends the ATB bars and the cost, takes the item, and resolves the skill
##   through `SkillUse.apply`, the same path a turn-based battle and a real-time hit take.
##
## OWNS: the field's rules for aiming, refusing and using a command.
## MUST NOT: draw a menu or slow the fight. The command overlay (C4.4) does both.

## Why a command cannot be used now. NONE means it can.
enum Reason { NONE, ATB, BLOCKED, COST, ITEM, TARGET }

## How far, in metres, a field command can reach when nothing is locked on.
const REACH: float = 8.0


## Everyone `command` would land on if `user` used it now, nearest first.
static func targets(user: Combatant, command: BattleCommand) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var found: Array[Combatant] = candidates(user, command)
	if found.is_empty() or command.skill.scope == Skill.Scope.ALL:
		return found
	# One target: the locked one, when it is a fair target, else the nearest.
	var locked: Combatant = _locked(user)
	if locked != null and found.has(locked):
		out.append(locked)
	else:
		out.append(found[0])
	return out


## Everyone `command` COULD land on: each fighter in `REACH` the skill may aim at, nearest
## first, whatever its scope. A thinking ally picks its one target from these (C4.8).
static func candidates(user: Combatant, command: BattleCommand) -> Array[Combatant]:
	var found: Array[Combatant] = []
	if user == null or command == null or command.skill == null or not user.is_inside_tree():
		return found
	var skill: Skill = command.skill
	var here: Vector3 = (user.get_parent() as Node3D).global_position
	for node: Node in user.get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var fighter: Combatant = (node as Hurtbox).fighter() if node is Hurtbox else null
		if fighter == null or found.has(fighter) or not user.can_target(fighter, skill.target):
			continue
		var body: Node3D = fighter.get_parent() as Node3D
		var vitals: Vitals = Vitals.of(body)
		# A reviving skill aims only at the fallen; everything else only at those standing.
		if vitals == null or vitals.is_defeated() != skill.revives():
			continue
		if body != null and here.distance_to(body.global_position) <= REACH:
			found.append(fighter)
	found.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return _distance(here, a) < _distance(here, b))
	return found


## Why `user` cannot use `command` now; `Reason.NONE` when it can.
static func refusal(user: Combatant, command: BattleCommand) -> Reason:
	if user == null or command == null or command.skill == null:
		return Reason.TARGET
	var body: Node = user.get_parent()
	var statuses: StatusSet = StatusSet.of(body)
	var block: StatusEffect.Block = StatusEffect.Block.NO_ITEMS \
			if command.kind == BattleCommand.Kind.ITEM else StatusEffect.Block.NO_SKILLS
	if statuses != null and statuses.blocker(block) != &"":
		return Reason.BLOCKED
	var meter: AtbMeter = AtbMeter.of(body)
	if meter == null or not meter.gauge.can_spend(command.skill.atb_cost):
		return Reason.ATB
	if command.kind == BattleCommand.Kind.ITEM:
		var inventory: Inventory = Inventory.of(body)
		if inventory == null or not inventory.has(command.item_id):
			return Reason.ITEM
	elif not SkillUse.affordable(user, command.skill):
		return Reason.COST
	if targets(user, command).is_empty():
		return Reason.TARGET
	return Reason.NONE


## `user` uses `command` now: spends its ATB and cost, takes the item, and resolves the skill.
## It lands on `targets(user, command)`, unless `aim` names who: a thinking ally's choice, which
## must be among the `candidates` (C4.8). False, changing nothing, when `refusal` has a reason or
## `aim` names someone the command cannot reach.
static func use(user: Combatant, command: BattleCommand, rng: RandomNumberGenerator,
		aim: Array[Combatant] = []) -> bool:
	if refusal(user, command) != Reason.NONE:
		return false
	var aimed: Array[Combatant] = targets(user, command)
	if not aim.is_empty():
		var reachable: Array[Combatant] = candidates(user, command)
		for fighter: Combatant in aim:
			if not reachable.has(fighter):
				return false
		aimed = aim
	var body: Node = user.get_parent()
	AtbMeter.of(body).spend(command.skill.atb_cost)
	if command.kind == BattleCommand.Kind.ITEM:
		Inventory.of(body).remove(command.item_id)
	else:
		SkillUse.pay(user, command.skill)
	SkillUse.apply(user, command.skill, aimed, rng)
	return true


## The fighter `user`'s lock-on holds, or null.
static func _locked(user: Combatant) -> Combatant:
	for child: Node in user.get_parent().get_children():
		var lock: LockOn = child as LockOn
		if lock != null and lock.target != null:
			return lock.target.fighter()
	return null


static func _distance(from: Vector3, fighter: Combatant) -> float:
	var body: Node3D = fighter.get_parent() as Node3D
	return from.distance_to(body.global_position) if body != null else INF
