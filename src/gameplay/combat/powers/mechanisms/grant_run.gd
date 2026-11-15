class_name GrantRun
extends PowerExecutor
## Runs an M12 grant (C6.11) on one fighter. Its settings are a `GrantMechanism`.
##
## IN PLAIN WORDS: using the power finds the receivers, puts the gifts on each, and has each
## hold the lent kit (`PowerSet.hold_kit`) under this power's own source. Each lent kit has a
## clock of `lasts`, counted by `tick` (the user's turns in a battle, seconds in the field);
## when it runs out, or the kit comes off the user, the receiver lets the kit go. Granting
## again to a receiver that still holds the kit starts its clock over.
##
## OWNS: carrying out one grant, and the clocks of the kits it lent.
## MUST NOT: name a character, or put a kit on anyone by any other source.

# Receiver body instance id -> time its lent kit has left.
var _lent: Dictionary[int, float] = {}


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var grant: GrantMechanism = mechanism as GrantMechanism
	for receiver: Combatant in _receivers(user, targets):
		var body: Node = receiver.get_parent()
		var statuses: StatusSet = StatusSet.of(body)
		if statuses != null:
			for gift: StatusEffect in _gifts(rng):
				statuses.apply(gift, rng, user.combatant_id)
		var powers: PowerSet = PowerSet.of(body)
		if grant.kit != null and powers != null:
			powers.hold_kit(grant.kit, _source())
			_lent[body.get_instance_id()] = grant.lasts


## Who receives: every standing ally in reach with `to_all` (the user too when `with_user`),
## else whoever the skill landed on, else the user.
func _receivers(user: Combatant, targets: Array[Combatant]) -> Array[Combatant]:
	var grant: GrantMechanism = mechanism as GrantMechanism
	var out: Array[Combatant] = []
	if grant.to_all:
		if grant.with_user:
			out.append(user)
		out.append_array(SacrificeRun.side(user, grant.radius))
		return out
	for target: Combatant in targets:
		if BarrageRun.standing(target) and user.can_target(target, FactionTable.Target.ALLY):
			out.append(target)
	if out.is_empty():
		out.append(user)
	return out


## The source a receiver holds the lent kit under.
func _source() -> StringName:
	return StringName("grant/%s" % power.power_id)


func tick(amount: float) -> void:
	for body_id: int in _lent.keys():
		_lent[body_id] -= amount
		if _lent[body_id] <= 0.0:
			_let_go(body_id)


func end() -> void:
	for body_id: int in _lent.keys():
		_let_go(body_id)


func _gifts(rng: RandomNumberGenerator) -> Array[StatusEffect]:
	var all: Array[StatusEffect] = (mechanism as GrantMechanism).statuses()
	if not (mechanism as GrantMechanism).pick_one or all.is_empty():
		return all
	var one: Array[StatusEffect] = [all[rng.randi_range(0, all.size() - 1)]]
	return one


func _let_go(body_id: int) -> void:
	_lent.erase(body_id)
	var body: Node = instance_from_id(body_id) as Node
	var powers: PowerSet = PowerSet.of(body) if body != null else null
	if powers != null:
		powers.release_kit(_source())
