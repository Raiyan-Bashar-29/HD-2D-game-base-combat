class_name FormRun
extends PowerExecutor
## Runs an M5 form (C6.5a) on one fighter, the same in the field and in a battle. Its settings
## are a `FormMechanism`; read its header for what a form is.
##
## IN PLAIN WORDS: the form IS its status. Whether the fighter is in the form, and in which stage
## of a cycle, is read back from the statuses it holds each time it matters (`_sync`). So when
## something else takes the status off (a cure, a dispel, a timed form running out, a new game)
## the form is simply over, with no extra wiring, and nothing here needs saving.
## - `use`: a plain form toggles on and off; a cycle moves to its next stage.
## - entering leaves every other form of the same `exclusive_group` in the kit.
## - `tick`: the drain, by the second in the field (`Combatant.real_time`) and by the turn in a
##   battle, carrying fractions of a point; at an empty pool the form ends.
## - `power_used`: a cycle moves on after a power named in `advance_after`.
## - `moves` (C6.5b): while on, the field plays the held stage's attack chain and dodge in place
##   of the fighter's own. The set built is kept, so nothing is made anew each frame.
## - `moved` (C6.5b): each move the fighter starts in the field drains `drain_per_action`.
## - `end`: the kit came off, so the form ends (its status comes off with it).
##
## OWNS: entering, leaving and draining one form on one fighter.
## MUST NOT: name a character, or touch another kit's forms.

## The stage held now: 0 for a plain form that is on, -1 when off.
var stage: int = -1
# Fractions of a drain point owed, until they make a whole one.
var _owed: float = 0.0
# The move sets built over a base, by base and stage, so the same set comes back each frame.
var _built: Dictionary[int, MoveSet] = {}


func use(_user: Combatant, _targets: Array[Combatant], _rng: RandomNumberGenerator) -> void:
	_sync()
	var form: FormMechanism = mechanism as FormMechanism
	if not form.cycle.is_empty():
		_enter((stage + 1) % form.cycle.size())
	elif stage >= 0:
		leave()
	else:
		_enter(0)


func tick(amount: float) -> void:
	_sync()
	var form: FormMechanism = mechanism as FormMechanism
	var fighter: Combatant = Combatant.of(holder.get_parent()) if holder != null else null
	if stage < 0 or fighter == null:
		return
	_drain(form.drain_per_second if fighter.real_time else form.drain_per_turn, amount)


func moved(_move: ActionMove) -> void:
	_sync()
	if stage >= 0:
		_drain((mechanism as FormMechanism).drain_per_action, 1.0)


func moves(base: MoveSet) -> MoveSet:
	_sync()
	if stage < 0 or base == null:
		return base
	var key: int = base.get_instance_id() * 64 + stage
	if not _built.has(key):
		_built[key] = _build(base)
	return _built[key]


func power_used(used: Power) -> void:
	var form: FormMechanism = mechanism as FormMechanism
	if used == null or used == power or form.cycle.is_empty():
		return
	_sync()
	if stage >= 0 and form.advance_after.has(used.power_id):
		_enter((stage + 1) % form.cycle.size())


func end() -> void:
	# Freed with the body, there is no status left to take off; only the kit coming off cures it.
	if holder != null and holder.is_inside_tree():
		leave()
	else:
		stage = -1


## Leaves the form: its status comes off. Nothing happens when it is not held.
func leave() -> void:
	_sync()
	if stage >= 0:
		var statuses: StatusSet = _statuses()
		var held: StatusEffect = _stage_status(stage)
		if statuses != null and held != null:
			statuses.cure(held.id)
	stage = -1
	_owed = 0.0


# Enters stage `index`: the other forms of the group end, then this stage's status goes on.
func _enter(index: int) -> void:
	var form: FormMechanism = mechanism as FormMechanism
	if form.exclusive_group != &"" and holder != null:
		for other: PowerExecutor in holder.running():
			var rival: FormRun = other as FormRun
			if rival != null and rival != self \
					and (rival.mechanism as FormMechanism).exclusive_group == form.exclusive_group:
				rival.leave()
	var statuses: StatusSet = _statuses()
	if statuses == null:
		return
	if stage >= 0 and stage != index and _stage_status(stage) != null:
		statuses.cure(_stage_status(stage).id)
	var entering: StatusEffect = _stage_status(index)
	if entering != null and statuses.apply(entering):
		stage = index
	else:
		stage = -1


# Reads which stage is held from the statuses: the first stage whose status is held, or -1.
func _sync() -> void:
	var statuses: StatusSet = _statuses()
	var found: int = -1
	if statuses != null:
		var stages: Array[StatusEffect] = (mechanism as FormMechanism).stage_statuses()
		for i: int in stages.size():
			if stages[i] != null and statuses.stacks(stages[i].id) > 0:
				found = i
				break
	if found < 0:
		_owed = 0.0
	stage = found


# The set played over `base` at this stage: the stage's chain and dodge where it has them. When
# it has neither, `base` itself, so nothing new is made.
func _build(base: MoveSet) -> MoveSet:
	var own: FormMechanism = (mechanism as FormMechanism).moves_of(stage)
	if own.attack_chain.is_empty() and own.dodge == null:
		return base
	var built := MoveSet.new()
	built.attack_chain = own.attack_chain if not own.attack_chain.is_empty() else base.attack_chain
	built.dodge = own.dodge if own.dodge != null else base.dodge
	built.skills = base.skills
	return built


# Takes `rate * amount` points of the drain pool, carrying fractions; at empty, the form ends.
func _drain(rate: float, amount: float) -> void:
	var form: FormMechanism = mechanism as FormMechanism
	var vitals: Vitals = Vitals.of(holder.get_parent()) if holder != null else null
	if form.drain_pool == &"" or vitals == null or rate <= 0.0:
		return
	_owed += rate * amount
	var whole: int = floori(_owed)
	if whole > 0:
		_owed -= whole
		vitals.change(form.drain_pool, -whole)
	if vitals.current(form.drain_pool) <= 0:
		leave()


func _stage_status(index: int) -> StatusEffect:
	var stages: Array[StatusEffect] = (mechanism as FormMechanism).stage_statuses()
	return stages[index] if index >= 0 and index < stages.size() else null


func _statuses() -> StatusSet:
	return StatusSet.of(holder.get_parent()) if holder != null else null
