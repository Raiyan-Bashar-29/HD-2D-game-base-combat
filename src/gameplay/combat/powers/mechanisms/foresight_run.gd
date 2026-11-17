class_name ForesightRun
extends PowerExecutor
## Runs M7 foresight (C6.10) on one fighter. Its settings are a `ForesightMechanism`.
##
## IN PLAIN WORDS: it keeps the rewrites left this fight, the field gap before the next one,
## and the skills and moves already seen. `Foresight` (called from `Combatant.hit`) asks it to
## spend a rewrite or whether a hit was seen before. Time passing counts the gap down and, with
## `reveal`, shows the foes' weaknesses. Entering an area fills the rewrites again and forgets
## what was seen.
##
## OWNS: one fighter's rewrites, gap and seen list.
## MUST NOT: change a hit itself (`Foresight` does), or name a character.

var left: int = -1
var _wait: float = 0.0
var _seen: Array[StringName] = []


func _init() -> void:
	Events.area_entered.connect(_refill)


func end() -> void:
	if Events.area_entered.is_connected(_refill):
		Events.area_entered.disconnect(_refill)


## True while the power works: inside its `active_hours`.
func works() -> bool:
	return power == null or power.active_at(Clock.minutes_today() / 60.0)


## Spends a rewrite of `kind` (DODGE when `dodging`, else FORCE) when one is left and the field
## gap has passed. True when it was spent.
func spend(dodging: bool) -> bool:
	var sight: ForesightMechanism = mechanism as ForesightMechanism
	if left < 0:
		left = sight.rewrites
	if not works() or left <= 0 or _wait > 0.0 or not (sight.dodge if dodging else sight.force):
		return false
	left -= 1
	var me: Combatant = Combatant.of(holder.get_parent()) if holder != null else null
	if me != null and me.real_time:
		_wait = sight.rewrite_gap
	return true


## With `observe`: true when `key` has landed on the user before.
func seen(key: StringName) -> bool:
	return key != &"" and (mechanism as ForesightMechanism).observe and works() and _seen.has(key)


## `key` has just landed on the user.
func note(key: StringName) -> void:
	if key != &"" and not _seen.has(key):
		_seen.append(key)


func tick(amount: float) -> void:
	_wait = maxf(0.0, _wait - amount)
	if (mechanism as ForesightMechanism).reveal and works():
		for foe: Combatant in _in_sight():
			Weakness.reveal_all(foe)


# The foes the user sees: a battle's standing foes, or the field lock-on's.
func _in_sight() -> Array[Combatant]:
	var out: Array[Combatant] = []
	var me: Combatant = Combatant.of(holder.get_parent()) if holder != null else null
	if me == null:
		return out
	if not me.real_time and Battle.running != null:
		for fighter: Combatant in Battle.running.party + Battle.running.enemies:
			if me.can_target(fighter, FactionTable.Target.ENEMY):
				out.append(fighter)
		return out
	for child: Node in me.get_parent().get_children():
		var lock: LockOn = child as LockOn
		if lock != null and lock.target != null and lock.target.fighter() != null:
			out.append(lock.target.fighter())
	return out


func _refill(_area: StringName) -> void:
	left = (mechanism as ForesightMechanism).rewrites
	_wait = 0.0
	_seen.clear()
