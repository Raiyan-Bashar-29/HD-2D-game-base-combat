class_name ActionDecider
extends RefCounted
## What a real-time enemy does next (C3.6), as pure code: no node, no physics, no frames. The
## enemy's body (C3.7) senses the world, hands the facts to `think`, and acts on the state it
## gets back.
##
## IN PLAIN WORDS, the states, checked in this order every think:
## - DEFEATED: it has fallen. Nothing else is ever chosen again.
## - STAGGERED: it is stunned or knocked back. It does nothing until that ends.
## - ATTACK: a move is playing. It finishes the move before choosing anything else.
## - RETURN: it was dragged past its leash. It walks home, ignoring everyone, until it is there.
## - RETREAT: it is hurt below `retreat_below` and the target is close: it backs away.
## - ATTACK (new): the cooldown is over and some move reaches the target: it picks one (`chosen`).
## - CHASE: it has noticed a target within `aggro_radius`, and keeps chasing until the target
##   is beyond `give_up_radius`. In range but cooling down, it is still CHASE: the body stands.
## - WANDER or IDLE: nobody to fight. It wanders every `wander_every` seconds, for a second.
##
## The facts arrive as plain numbers so a test can state any situation in one line.
##
## OWNS: the current state, the move chosen for an attack, and the cooldown and wander clocks.
## MUST NOT: move a body, read a node, or play a move. The enemy's body does all three.

enum State { IDLE, WANDER, CHASE, ATTACK, RETREAT, RETURN, STAGGERED, DEFEATED }

## How long one wander lasts, in seconds.
const WANDER_FOR: float = 1.0
## How near home counts as home, in metres.
const HOME_RADIUS: float = 0.5

var brain: ActionBrain
var state: State = State.IDLE
## The move picked on entering ATTACK; null otherwise.
var chosen: ActionMove

var _cooldown: float = 0.0
var _wander_clock: float = 0.0


func _init(with_brain: ActionBrain = null) -> void:
	brain = with_brain


## One decision. `target_distance` is INF with no hostile in sight; `busy` is true while a move
## plays; `hp_fraction` is current over maximum hp. Returns the state to act on.
func think(delta: float, target_distance: float, home_distance: float, hp_fraction: float,
		busy: bool, stunned: bool, defeated: bool, rng: RandomNumberGenerator) -> State:
	var was_attacking: bool = state == State.ATTACK
	_cooldown = maxf(0.0, _cooldown - delta)
	chosen = null
	if defeated or state == State.DEFEATED:
		state = State.DEFEATED
	elif stunned:
		state = State.STAGGERED
	elif busy and was_attacking:
		state = State.ATTACK
	else:
		if was_attacking:
			# The move just ended: the cooldown starts now, not when it began.
			_cooldown = brain.attack_cooldown
		state = _choose(delta, target_distance, home_distance, hp_fraction, rng)
	return state


## Picks a move for a target `distance` away, by weight among the entries whose conditions
## hold. Null when none may be used.
func pick(distance: float, hp_fraction: float, rng: RandomNumberGenerator) -> ActionMove:
	var usable: Array[ActionBrainEntry] = []
	var total: float = 0.0
	for entry: ActionBrainEntry in brain.moves:
		if entry == null or entry.move == null or entry.weight <= 0.0:
			continue
		var reach: float = entry.reach if entry.reach > 0.0 else brain.attack_range
		if distance > reach or distance < entry.min_reach or hp_fraction > entry.only_below:
			continue
		usable.append(entry)
		total += entry.weight
	if usable.is_empty():
		return null
	var roll: float = rng.randf() * total
	for entry: ActionBrainEntry in usable:
		roll -= entry.weight
		if roll < 0.0:
			return entry.move
	return usable.back().move


func _choose(delta: float, target_distance: float, home_distance: float, hp_fraction: float,
		rng: RandomNumberGenerator) -> State:
	if state == State.RETURN and home_distance > HOME_RADIUS:
		return State.RETURN
	if home_distance > brain.leash_radius:
		return State.RETURN
	if brain.retreat_below > 0.0 and hp_fraction < brain.retreat_below \
			and target_distance < brain.retreat_distance:
		return State.RETREAT
	var chasing: bool = state == State.CHASE or state == State.RETREAT
	var noticed: bool = target_distance <= brain.aggro_radius \
		or (chasing and target_distance <= brain.give_up_radius)
	if noticed:
		# Any move whose reach covers the target may start an attack: a lunge from afar, a jab
		# up close. `attack_range` is the default reach, and how close the body walks in.
		if _cooldown <= 0.0:
			chosen = pick(target_distance, hp_fraction, rng)
			if chosen != null:
				return State.ATTACK
		return State.CHASE
	return _idle(delta)


## Stands about, wandering for `WANDER_FOR` seconds every `wander_every`.
func _idle(delta: float) -> State:
	if brain.wander_radius <= 0.0 or brain.wander_every <= 0.0:
		return State.IDLE
	_wander_clock += delta
	if _wander_clock >= brain.wander_every + WANDER_FOR:
		_wander_clock = 0.0
	return State.WANDER if _wander_clock >= brain.wander_every else State.IDLE
