class_name BattlefieldRun
extends FormRun
## Runs an M4 battlefield (C6.9a) on its caster, the same in the field and in a battle. Its
## settings are a `BattlefieldMechanism`; read its header for what a battlefield is.
##
## IN PLAIN WORDS: a battlefield is a form, so raising and ending it is `FormRun`'s work: it stands
## while the caster holds its status. This adds what reaches the other fighters:
## - `_settle` notices the status coming on or off, however that happened (used, drained dry, run
##   out, cured, the kit coming off), and raises or lowers the field to match.
## - Raising starts its clock: `seconds` in the field, `turns` in a battle (each `tick` is a
##   second's share in the field and one of the caster's turns in a battle). At 0 it ends by its
##   own rules, so the form's `aftermath` goes on.
## - `_refresh`, on raising and on every tick, walks the fighters of the same fight (every
##   `Combatant` on the caster's clock: real time in the field, turns in a battle) and lets in the
##   ones now within reach and out the ones that left. Each one inside gets the modifiers and
##   statuses of every effect whose group it is in, under the source `field/<power id>`; leaving
##   takes them off again.
## - The caster falling ends it at once, with no aftermath.
##
## NOT SAVED: a load puts the caster's status back (the kit knows it), and the next tick raises the
## field again with a fresh clock and lets everyone in.
##
## OWNS: which fighters are inside one battlefield, and what it has put on them.
## MUST NOT: name a character, or touch another battlefield's fighters.

# The fighters inside now, by instance id.
var _inside: Dictionary[int, Combatant] = {}
# Seconds or turns left to stand; 0 or less stands until ended.
var _left: float = 0.0
# True while the field is raised.
var _up: bool = false


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	super.use(user, targets, rng)
	_settle()


func tick(amount: float) -> void:
	super.tick(amount)
	_settle()
	if not _up:
		return
	if _left > 0.0:
		_left -= amount
		if _left <= 0.0:
			_finish()
			_settle()
			return
	_refresh()


func end() -> void:
	super.end()
	_lower()


## True while the battlefield stands. Asked by tests and, later, the HUD.
func standing() -> bool:
	return _up


# A stage status ran out or came off: the field follows.
func _on_expired(who: StringName, status_id: StringName) -> void:
	super._on_expired(who, status_id)
	_settle()


# Raises or lowers the field to match whether the caster holds its status.
func _settle() -> void:
	var on: bool = held() >= 0
	if on and not _up:
		_raise()
	elif not on and _up:
		_lower()


func _raise() -> void:
	var field: BattlefieldMechanism = mechanism as BattlefieldMechanism
	var me: Combatant = _caster()
	_up = true
	_left = (field.seconds if me != null and me.real_time else float(field.turns))
	if not Events.combatant_defeated.is_connected(_on_defeated):
		Events.combatant_defeated.connect(_on_defeated)
	_refresh()


func _lower() -> void:
	_up = false
	_left = 0.0
	if Events.combatant_defeated.is_connected(_on_defeated):
		Events.combatant_defeated.disconnect(_on_defeated)
	for id: int in _inside.keys():
		var other: Combatant = _inside[id]
		if is_instance_valid(other):
			_part(other)
	_inside.clear()


# Lets in the fighters now within reach and out the ones that left or are gone.
func _refresh() -> void:
	var me: Combatant = _caster()
	if me == null or not me.is_inside_tree():
		return
	var seen: Dictionary[int, bool] = {}
	for node: Node in me.get_tree().get_nodes_in_group(Combatant.GROUP):
		var other: Combatant = node as Combatant
		if other == null or other.real_time != me.real_time:
			continue
		var id: int = other.get_instance_id()
		seen[id] = true
		var vitals: Vitals = Vitals.of(other.get_parent())
		if vitals != null and vitals.is_defeated():
			continue
		var reached: bool = _reaches(me, other)
		if reached and not _inside.has(id):
			_join(other)
		elif not reached and _inside.has(id):
			_part(other)
	for id: int in _inside.keys():
		if not seen.has(id):
			if is_instance_valid(_inside[id]):
				_part(_inside[id])
			_inside.erase(id)


# True when `other` is within the field's reach of `me`: always in a battle or with no radius.
func _reaches(me: Combatant, other: Combatant) -> bool:
	var radius: float = (mechanism as BattlefieldMechanism).radius
	var from: Node3D = me.get_parent() as Node3D
	var to: Node3D = other.get_parent() as Node3D
	if not me.real_time or radius <= 0.0 or from == null or to == null:
		return true
	var gap: Vector3 = to.global_position - from.global_position
	gap.y = 0.0
	return gap.length() <= radius


# `other` comes inside: each of its effects' modifiers and statuses goes on.
func _join(other: Combatant) -> void:
	_inside[other.get_instance_id()] = other
	var source: StringName = _source()
	other.sheet.remove_from(source)
	var statuses: StatusSet = StatusSet.of(other.get_parent())
	for effect: BattlefieldEffect in _effects_for(other):
		for modifier: StatModifier in effect.modifiers:
			other.sheet.add(StatModifier.of(modifier.stat, modifier.op, modifier.value, source))
		if statuses != null:
			for status: StatusEffect in effect.statuses:
				statuses.apply(status)


# `other` leaves: what the field put on it comes off.
func _part(other: Combatant) -> void:
	_inside.erase(other.get_instance_id())
	other.sheet.remove_from(_source())
	var statuses: StatusSet = StatusSet.of(other.get_parent())
	if statuses == null:
		return
	for effect: BattlefieldEffect in _effects_for(other):
		for status: StatusEffect in effect.statuses:
			statuses.cure(status.id)


# The effects whose group `other` is in.
func _effects_for(other: Combatant) -> Array[BattlefieldEffect]:
	var out: Array[BattlefieldEffect] = []
	var me: Combatant = _caster()
	if me == null:
		return out
	for effect: BattlefieldEffect in (mechanism as BattlefieldMechanism).effects:
		var mine: bool = other == me
		var match_found: bool = false
		match effect.who:
			BattlefieldEffect.Who.CASTER:
				match_found = mine
			BattlefieldEffect.Who.CASTER_SIDE:
				match_found = mine or me.can_target(other, FactionTable.Target.ALLY)
			BattlefieldEffect.Who.OTHER_SIDE:
				match_found = not mine and me.can_target(other, FactionTable.Target.ENEMY)
			BattlefieldEffect.Who.EVERYONE:
				match_found = true
			BattlefieldEffect.Who.EVERYONE_BUT_CASTER:
				match_found = not mine
		if match_found:
			out.append(effect)
	return out


# The caster fell: the field ends at once, with no aftermath.
func _on_defeated(who: StringName) -> void:
	var me: Combatant = _caster()
	var vitals: Vitals = Vitals.of(me.get_parent()) if me != null else null
	if me != null and who == me.combatant_id and vitals != null and vitals.is_defeated():
		leave()
		_settle()


func _caster() -> Combatant:
	return Combatant.of(holder.get_parent()) if holder != null and holder.get_parent() != null else null


func _source() -> StringName:
	return StringName("field/" + String(power.power_id if power != null else &""))
