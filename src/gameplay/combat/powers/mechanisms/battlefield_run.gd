class_name BattlefieldRun
extends FormRun
## Runs an M4 battlefield (C6.9a, C6.9b) on its caster, the same in the field and in a battle. Its
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
## - C6.9b: as a fighter comes in, each of its effects' `on_enter` skill is used on it by the
##   caster; as it leaves (or the field ends) the `on_exit` skill. Every tick also counts each
##   effect's own clock (`tick_seconds` of field time, `tick_turns` of the caster's turns) and,
##   when it comes round, uses its `tick` skill on every fighter of its group inside, each tick
##   `tick_grows` stronger than the last. In the field `pull` and `push` move them.
## - Immunity: a fighter whose stat `resist_field_<name>` is 1 or more is never let in (and is
##   let out once it gains it); one holding a status tagged with an effect's `immune_tags` is
##   left out of that effect. The tags are read as it comes in and at each tick and pull, so a
##   tag gained while inside keeps the modifiers and statuses it came in with until it leaves.
##
## - C6.9d: a raise first asks `BattlefieldClash.allows`. A battlefield that loses a clash never
##   stands, and one that beats a rival ends it. A `closed` one keeps those already inside
##   (`_refresh`) and holds their bodies at its edge each tick (`BattlefieldWall`).
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
# Each effect's clock, by its index: field seconds or caster turns since its last tick.
var _clock: Dictionary[int, float] = {}
# How many times each effect has ticked since the field rose, by index (for `tick_grows`).
var _ticks: Dictionary[int, int] = {}
# The dice the skills roll with: the use's, else a fresh one.
var _rng := RandomNumberGenerator.new()
# The caster's status with its hit flags added (C6.9c), made on first use. Null until then.
var _granted: StatusEffect = null


func use(user: Combatant, targets: Array[Combatant], rng: RandomNumberGenerator) -> void:
	if rng != null:
		_rng = rng
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
	_work(amount)


func end() -> void:
	super.end()
	_lower()


## True while the battlefield stands. Asked by tests and, later, the HUD.
func standing() -> bool:
	return _up


## Brings the battlefield down at once, with no aftermath, because a hit broke it (C6.9c). The
## caster's status comes off, and `_settle` then lowers the field.
func break_down() -> void:
	leave()
	_settle()


## Ends every standing battlefield on `target` whose `broken_by_tags` names one of `tags` (C6.9c).
## Called on each landed hit, so an anti-world attack ends a reality marble on its caster.
static func breaks(target: Combatant, tags: Array[StringName]) -> void:
	if target == null or tags.is_empty() or target.get_parent() == null:
		return
	var powers: PowerSet = PowerSet.of(target.get_parent())
	if powers == null:
		return
	for run: PowerExecutor in powers.running():
		var field := run as BattlefieldRun
		if field != null and field.standing() and (field.mechanism as BattlefieldMechanism).broken_by(tags):
			field.break_down()


# The caster's status, with what the battlefield grants on it (C6.9c). Made once and kept, so a
# shared status resource is never changed.
func _stage_status(index: int) -> StatusEffect:
	var base: StatusEffect = super._stage_status(index)
	var field: BattlefieldMechanism = mechanism as BattlefieldMechanism
	if base == null or field == null:
		return base
	if not (field.sure_hit or not field.hit_tags.is_empty() or field.cancelled_by != &""):
		return base
	if _granted == null:
		_granted = HitFlags.granted(base, field)
	return _granted


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
	# A clash (C6.9d) may keep it from standing: it then shatters at once, with no aftermath.
	if not BattlefieldClash.allows(me, field, self):
		leave()
		return
	_up = true
	_left = (field.seconds if me != null and me.real_time else float(field.turns))
	_clock.clear()
	_ticks.clear()
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
		# A closed battlefield keeps those already inside (C6.9d); its edge is held in `_work`.
		var keep: bool = (mechanism as BattlefieldMechanism).closed and _inside.has(id)
		var reached: bool = (_reaches(me, other) or keep) and not _immune(other)
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
	_use_on(other, true)


# `other` leaves: what the field put on it comes off, then its `on_exit` skills land.
func _part(other: Combatant) -> void:
	_inside.erase(other.get_instance_id())
	other.sheet.remove_from(_source())
	var statuses: StatusSet = StatusSet.of(other.get_parent())
	if statuses != null:
		# Every status the field could have given comes off, immune or not: a tag gained while
		# inside must not keep the field's statuses on for good.
		for effect: BattlefieldEffect in _effects_for(other, false):
			for status: StatusEffect in effect.statuses:
				statuses.cure(status.id)
	_use_on(other, false)


# The caster uses each of `other`'s effects' `on_enter` (or `on_exit`) skill on it, free. A
# fallen fighter is left alone.
func _use_on(other: Combatant, entering: bool) -> void:
	var me: Combatant = _caster()
	if me == null or not _standing(other):
		return
	for effect: BattlefieldEffect in _effects_for(other):
		var skill: Skill = effect.on_enter if entering else effect.on_exit
		if skill != null:
			SkillUse.apply(me, skill, [other], _rng)


# One tick of `amount` (field seconds or caster turns) for every effect: its pull and push in the
# field, and its own clock, using its `tick` skill each time the clock comes round.
func _work(amount: float) -> void:
	var me: Combatant = _caster()
	if me == null:
		return
	# A closed battlefield holds those inside at its edge, in the field only (C6.9d).
	var field: BattlefieldMechanism = mechanism as BattlefieldMechanism
	if me.real_time and field.closed:
		BattlefieldWall.hold(me, field.radius, _inside.values())
	var effects: Array[BattlefieldEffect] = field.effects
	for i: int in effects.size():
		var effect: BattlefieldEffect = effects[i]
		if effect == null:
			continue
		if me.real_time:
			_drift(me, effect, amount)
		var every: float = effect.tick_seconds if me.real_time else float(effect.tick_turns)
		if effect.tick == null or every <= 0.0:
			continue
		_clock[i] = _clock.get(i, 0.0) + amount
		while _clock[i] >= every and _up:
			_clock[i] -= every
			_pulse(me, effect, i)


# Uses `effect`'s tick skill on every standing fighter of its group inside, as strong as its
# growth makes this tick.
func _pulse(me: Combatant, effect: BattlefieldEffect, index: int) -> void:
	var count: int = _ticks.get(index, 0)
	_ticks[index] = count + 1
	var targets: Array[Combatant] = []
	for other: Combatant in _members(effect):
		if _standing(other):
			targets.append(other)
	if not targets.is_empty():
		SkillUse.apply(me, effect.tick, targets, _rng, 0, 1.0 + effect.tick_grows * count)


# Draws each fighter of `effect`'s group toward the caster (pull) or away (push), on the ground,
# never past the caster. The caster itself never moves.
func _drift(me: Combatant, effect: BattlefieldEffect, seconds: float) -> void:
	var speed: float = effect.pull - effect.push
	var centre: Node3D = me.get_parent() as Node3D
	if is_zero_approx(speed) or centre == null:
		return
	for other: Combatant in _members(effect):
		var body: Node3D = other.get_parent() as Node3D
		if other == me or body == null or not _standing(other):
			continue
		var gap: Vector3 = centre.global_position - body.global_position
		gap.y = 0.0
		if gap.length() < 0.001:
			continue
		var step: Vector3 = gap.normalized() * minf(speed * seconds, gap.length())
		BattlefieldWall.step_body(body, step)


# The fighters inside now that `effect` touches.
func _members(effect: BattlefieldEffect) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for other: Combatant in _inside.values():
		if is_instance_valid(other) and _effects_for(other).has(effect):
			out.append(other)
	return out


# True when `other` resists this whole battlefield: its `resist_field_<name>` is 1 or more.
func _immune(other: Combatant) -> bool:
	var stat: StringName = StringName("resist_field_" + String(power.power_id).get_file()) if power != null else &""
	return stat != &"" and other.sheet.value(stat) >= 1.0


func _standing(other: Combatant) -> bool:
	var vitals: Vitals = Vitals.of(other.get_parent()) if is_instance_valid(other) else null
	return vitals != null and not vitals.is_defeated()


# True when `other` holds a status tagged with one of `tags`.
func _holds_any(other: Combatant, tags: Array[StringName]) -> bool:
	var statuses: StatusSet = StatusSet.of(other.get_parent()) if not tags.is_empty() else null
	if statuses == null:
		return false
	for held: StatusEffect in statuses.held():
		for tag: StringName in tags:
			if held.tags.has(tag):
				return true
	return false


# The effects whose group `other` is in, leaving out those it is immune to when `immunity`.
func _effects_for(other: Combatant, immunity: bool = true) -> Array[BattlefieldEffect]:
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
		if match_found and not (immunity and _holds_any(other, effect.immune_tags)):
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
