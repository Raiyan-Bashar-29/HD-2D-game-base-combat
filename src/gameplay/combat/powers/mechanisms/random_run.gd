class_name RandomRun
extends PowerExecutor
## Runs a random power (C8.13c). Its settings are a `RandomMechanism`; read its header.
##
## IN PLAIN WORDS: a use picks one of `powers` with the use's rng, lands its skill with
## `SkillUse.apply`, and makes and uses an executor for its mechanism (`PowerMechanisms.make`).
## That executor is kept and hears `tick`, `moved` and `end` until the next pick replaces it.
##
## OWNS: the last pick and its executor.
## MUST NOT: pay a picked power's cost or start its cooldown, or name a character.

var _picked: Power
var _running: PowerExecutor


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	var list: Array[Power] = (mechanism as RandomMechanism).powers
	if list.is_empty():
		return
	_stop()
	_picked = list[rng.randi_range(0, list.size() - 1) if rng != null else 0]
	if _picked == null:
		return
	if _picked.skill != null and not targets.is_empty():
		SkillUse.apply(user, _picked.skill, targets, rng)
	if _picked.mechanism != null:
		_running = PowerMechanisms.make(_picked.mechanism)
		if _running != null:
			_running.power = _picked
			_running.holder = holder
			_running.use(user, targets, rng)


func tick(amount: float) -> void:
	if _running != null:
		_running.tick(amount)


func moved(move: ActionMove) -> void:
	if _running != null:
		_running.moved(move)


func end() -> void:
	_stop()


## The power the last use picked, or null: for a log, a menu or a test.
func picked() -> Power:
	return _picked


func _stop() -> void:
	if _running != null:
		_running.end()
	_running = null
