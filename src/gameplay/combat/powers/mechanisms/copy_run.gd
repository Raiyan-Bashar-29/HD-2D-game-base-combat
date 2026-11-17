class_name CopyRun
extends PowerExecutor
## Runs a copy (C8.13b) on one fighter. Its settings are a `CopyMechanism`; read its header for
## what the fields mean.
##
## IN PLAIN WORDS: it listens to `Events.power_used` and keeps the last power it may copy. A use
## puts a one-power kit on the user with `PowerSet.hold_kit` under its own source, replacing an
## earlier borrow, and `tick` counts it down and takes it off with `release_kit`. `end` takes it off.
##
## OWNS: the remembered power and the borrow's clock.
## MUST NOT: change the power it copies, or name a character.

var _seen: Power
var _left: float = 0.0
var _listening: bool = false


func use(_user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	_listen()
	if _seen == null or not is_instance_valid(holder):
		return
	_release()
	var kit := PowerKit.new()
	kit.kit_id = StringName("kit/borrowed_" + String(_seen.power_id))
	kit.powers = [_seen]
	holder.hold_kit(kit, _source())
	_left = (mechanism as CopyMechanism).lasts


## Time passed: the borrow counts down and goes at 0. The first tick also starts listening.
func tick(amount: float) -> void:
	_listen()
	if _left <= 0.0:
		return
	_left -= amount
	if _left <= 0.0:
		_release()


## The kit came off: the borrow goes too.
func end() -> void:
	_release()
	if _listening:
		Events.power_used.disconnect(_on_power_used)
		_listening = false


## The power a use would lend now, or null: for a menu, or a test.
func seen() -> Power:
	return _seen


func _listen() -> void:
	if not _listening:
		Events.power_used.connect(_on_power_used)
		_listening = true


func _release() -> void:
	_left = 0.0
	if is_instance_valid(holder):
		holder.release_kit(_source())


func _source() -> StringName:
	return StringName("copy/" + (String(power.power_id) if power != null else ""))


func _on_power_used(who: StringName, used: Resource, targets: Array[StringName]) -> void:
	var me: Combatant = Combatant.of(holder.get_parent()) if is_instance_valid(holder) else null
	var copied: Power = used as Power
	if me == null or copied == null or who == me.combatant_id or copied.passive:
		return
	if copied.mechanism is CopyMechanism:
		return
	if (mechanism as CopyMechanism).suffered_only and not targets.has(me.combatant_id):
		return
	_seen = copied
