class_name FinisherRun
extends PowerExecutor
## Runs an M2 finisher (C6.8) on one fighter. Its settings are a `FinisherMechanism`; read its
## header for the charge, the break, the flourish and the pool.
##
## IN PLAIN WORDS: using the power remembers who it aims at and starts the charge (or lands at
## once, with none). Time passing (`tick`: seconds in the field, a turn in a battle) fills the
## charge; when it is full the `charging` status comes off, the fight stands still for the
## `flourish` (field only, through a `Flourish` node), and the strike lands. Using the power
## again while it charges or stands still changes nothing.
##
## THE BREAK: each tick it checks the charge still stands: the `charging` status is held and the
## user is up. A hit of `break_damage` or more on the user breaks it at once. A broken charge is
## simply lost; the power's cooldown and cost are already spent.
##
## WHERE IT LANDS: in the field, through each struck foe's `Hurtbox.take` (one aimed foe, or
## every foe within `reach` with `all_foes`); in a battle, through `BarrageRun.strike_with` (the
## first standing foe it was given, or all of them). The strike is a copy with the power's POWER
## and HITS scaling read now; then `drain_pool` is emptied.
##
## OWNS: one charge and its strike on one fighter.
## MUST NOT: resolve a hit itself (`Hurtbox.take` and `BarrageRun.strike_with` do), or name a
## character.

var _user: Combatant
var _rng: RandomNumberGenerator
var _targets: Array[Combatant] = []
## What is left of the charge: seconds in the field, turns in a battle. Below 0 when not charging.
var _left: float = -1.0
var _flourish: Flourish


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	if charging() or (_flourish != null and is_instance_valid(_flourish)):
		return
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	_user = user
	_rng = rng
	_targets = targets.duplicate()
	var wait: float = finisher.charge_time if user.real_time else float(finisher.charge_turns)
	if wait <= 0.0:
		_land()
		return
	_left = wait
	var statuses: StatusSet = StatusSet.of(user.get_parent())
	if finisher.charging != null and statuses != null:
		statuses.apply(finisher.charging)
	_listen(finisher.break_damage > 0)


func tick(amount: float) -> void:
	if not charging():
		return
	if _broken():
		_drop()
		return
	_left -= amount
	if _left <= 0.0001:
		_release()


func end() -> void:
	_drop()
	if _flourish != null and is_instance_valid(_flourish):
		_flourish.finished.disconnect(_land)
		_flourish.queue_free()
	_flourish = null


## True while the charge is filling.
func charging() -> bool:
	return _left >= 0.0


# The charge is full: the charging status comes off, then a flourish or the strike at once.
func _release() -> void:
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	_drop()
	var body: Node = _user.get_parent() if is_instance_valid(_user) else null
	if finisher.flourish <= 0.0 or not _user.real_time or body == null or body.get_parent() == null:
		_land()
		return
	_flourish = Flourish.new()
	_flourish.seconds = finisher.flourish
	_flourish.finished.connect(_land)
	body.get_parent().add_child(_flourish)


# Ends the charge, landing nothing: the status comes off and nothing listens any more.
func _drop() -> void:
	_left = -1.0
	_listen(false)
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	var statuses: StatusSet = StatusSet.of(_user.get_parent()) if is_instance_valid(_user) else null
	if finisher.charging != null and statuses != null:
		statuses.cure(finisher.charging.id)


# True when the charge no longer stands: the user fell, or its charging status ended early.
func _broken() -> bool:
	if not is_instance_valid(_user) or not BarrageRun.standing(_user):
		return true
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	var statuses: StatusSet = StatusSet.of(_user.get_parent())
	return finisher.charging != null and statuses != null and statuses.stacks(finisher.charging.id) == 0


# The strike lands now, on the field's foes or the battle's.
func _land() -> void:
	_flourish = null
	if not is_instance_valid(_user) or not BarrageRun.standing(_user):
		return
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	var strike: ActionMove = _scaled()
	if finisher.drain_pool != &"":
		var vitals: Vitals = Vitals.of(_user.get_parent())
		if vitals != null:
			vitals.set_to(finisher.drain_pool, 0)
	if _user.real_time:
		for hurtbox: Hurtbox in _field_targets():
			hurtbox.take(_user, strike, _rng, (_user.get_parent() as Node3D).global_position)
		return
	for foe: Combatant in _battle_targets():
		BarrageRun.strike_with(_user, foe, strike, _rng)


# The strike with the power's POWER and HITS scaling read now, on a copy.
func _scaled() -> ActionMove:
	var strike: ActionMove = (mechanism as FinisherMechanism).strike
	if power == null or power.scaling.is_empty():
		return strike
	var first: Combatant = _targets[0] if not _targets.is_empty() else null
	var copy: ActionMove = strike.duplicate() as ActionMove
	copy.power = strike.power * PowerUse.multiplier(_user, power, PowerScaling.Affects.POWER, first)
	copy.hits = maxi(1, roundi(maxi(1, strike.hits) * PowerUse.multiplier(_user, power,
			PowerScaling.Affects.HITS, first)))
	return copy


# The hurtboxes a field strike lands on: every hostile one within `reach`, or the aimed foe's.
func _field_targets() -> Array[Hurtbox]:
	var finisher: FinisherMechanism = mechanism as FinisherMechanism
	var body: Node3D = _user.get_parent() as Node3D
	var out: Array[Hurtbox] = []
	if body == null or not body.is_inside_tree():
		return out
	var aim: Combatant = null if finisher.all_foes else BarrageRun.aim_of(_user, _targets)
	for node: Node in body.get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		var foe: Combatant = hurtbox.fighter() if hurtbox != null else null
		if foe == null or foe == _user or not BarrageRun.standing(foe):
			continue
		if finisher.all_foes:
			var there: Vector3 = (foe.get_parent() as Node3D).global_position - body.global_position
			if _user.can_target(foe, FactionTable.Target.ENEMY) and Vector2(there.x, there.z).length() <= finisher.reach:
				out.append(hurtbox)
		elif foe == aim:
			out.append(hurtbox)
	return out


# The foes a battle strike lands on: the standing ones it was given, or the first of them.
func _battle_targets() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for foe: Combatant in _targets:
		if is_instance_valid(foe) and foe != _user and BarrageRun.standing(foe):
			out.append(foe)
	if not (mechanism as FinisherMechanism).all_foes and out.size() > 1:
		out.resize(1)
	return out


# Listens, or stops listening, for a hit on the user strong enough to break the charge.
func _listen(on: bool) -> void:
	var listening: bool = Events.combatant_damaged.is_connected(_on_damaged)
	if on and not listening:
		Events.combatant_damaged.connect(_on_damaged)
	elif not on and listening:
		Events.combatant_damaged.disconnect(_on_damaged)


func _on_damaged(who: StringName, _by: StringName, amount: int, _critical: bool) -> void:
	if charging() and is_instance_valid(_user) and who == _user.combatant_id \
			and amount >= (mechanism as FinisherMechanism).break_damage:
		_drop()
