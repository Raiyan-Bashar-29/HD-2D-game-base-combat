class_name RewindRun
extends PowerExecutor
## Runs a rewind (C8.11b) on one fighter. Its settings are a `RewindMechanism`; read its header
## for what the fields mean.
##
## IN PLAIN WORDS: each `tick` (seconds in the field, one of the user's turns in a battle) writes
## down the time, the user's place and its hp, and forgets records older than `back` plus a
## little. `use` finds the newest record at least `back` old (else the oldest) and puts the place
## (in the field only) and the hp back. The defeat pool is set with `Vitals.set_to`, which never
## raises the fallen.
##
## OWNS: the user's time record.
## MUST NOT: touch anyone but its user, or name a character.

var _age: float = 0.0
var _times: PackedFloat64Array = PackedFloat64Array()
var _places: PackedVector3Array = PackedVector3Array()
var _hps: PackedInt32Array = PackedInt32Array()


func use(user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	var at: int = _record_back()
	if at < 0:
		return
	var rewind: RewindMechanism = mechanism as RewindMechanism
	var body: Node3D = user.get_parent() as Node3D
	if rewind.restore_place and user.real_time and body != null:
		body.global_position = _places[at]
		var moving: CharacterBody3D = body as CharacterBody3D
		if moving != null:
			moving.velocity = Vector3.ZERO
	var vitals: Vitals = Vitals.of(body)
	if rewind.restore_hp and vitals != null and not vitals.is_defeated():
		vitals.set_to(vitals.defeat_pool, _hps[at])


## Time passed: writes the user down, and forgets what is too old to need.
func tick(amount: float) -> void:
	var body: Node3D = holder.get_parent() as Node3D if is_instance_valid(holder) else null
	if body == null:
		return
	_age += amount
	var vitals: Vitals = Vitals.of(body)
	_times.append(_age)
	_places.append(body.global_position)
	_hps.append(vitals.current(vitals.defeat_pool) if vitals != null else 0)
	var keep: float = (mechanism as RewindMechanism).back
	while _times.size() > 2 and _times[1] <= _age - keep:
		_times.remove_at(0)
		_places.remove_at(0)
		_hps.remove_at(0)


# The newest record at least `back` old, else the oldest; -1 with none.
func _record_back() -> int:
	if _times.is_empty():
		return -1
	var when: float = _age - (mechanism as RewindMechanism).back + 0.0001
	for index: int in range(_times.size() - 1, -1, -1):
		if _times[index] <= when:
			return index
	return 0
