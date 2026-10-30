extends TestCase
## Enemies that chase, attack and retreat, as pure decisions (C3.6): idle and wander with nobody
## near; notice within aggro and chase until give-up; attack with a move whose reach and
## conditions fit, finish it, cool down, attack again; retreat when hurt and close; walk home
## past the leash and ignore everyone until there; stagger when stunned; stay down when
## defeated; and `problems()` on a brain.
##
## OWNS: assertions about `ActionDecider`, `ActionBrain` and `ActionBrainEntry`.
## MUST NOT: name a game's enemies, or touch a node. Every fact is a plain number.

const S := ActionDecider.State

var _rng := RandomNumberGenerator.new()
var _jab: ActionMove
var _lunge: ActionMove
var _flurry: ActionMove


func run() -> void:
	plan(21)
	_rng.seed = 11
	_idling()
	_noticing()
	_attacking()
	_retreat_leash_and_ends()
	_problems()


func _entry(move: ActionMove, weight: float) -> ActionBrainEntry:
	var made := ActionBrainEntry.new()
	made.move = move
	made.weight = weight
	return made


func _brain() -> ActionBrain:
	_jab = ActionMove.new()
	_lunge = ActionMove.new()
	_flurry = ActionMove.new()
	var lunge := _entry(_lunge, 1.0)
	lunge.reach = 4.0
	lunge.min_reach = 2.0
	var flurry := _entry(_flurry, 100.0)
	flurry.only_below = 0.25
	var made := ActionBrain.new()
	made.retreat_below = 0.3
	made.moves = [_entry(_jab, 1.0), lunge, flurry]
	return made


## One think with only the target's distance changing: at home, full hp, free to act.
func _see(decider: ActionDecider, distance: float, delta: float = 0.1) -> ActionDecider.State:
	return decider.think(delta, distance, 0.0, 1.0, false, false, false, _rng)


func _idling() -> void:
	var decider := ActionDecider.new(_brain())
	equal("with nobody near, it stands", _see(decider, INF), S.IDLE)
	_see(decider, INF, 3.0)
	equal("every three seconds it wanders", _see(decider, INF), S.WANDER)
	_see(decider, INF, 1.0)
	equal("for a second, then stands again", _see(decider, INF), S.IDLE)


func _noticing() -> void:
	var decider := ActionDecider.new(_brain())
	equal("a target 8 m away is not noticed", _see(decider, 8.0), S.IDLE)
	equal("one 5 m away is chased", _see(decider, 5.0), S.CHASE)
	equal("once chasing, 8 m is still chased", _see(decider, 8.0), S.CHASE)
	equal("past 10 m it gives up", _see(decider, 11.0) != S.CHASE, true)


func _attacking() -> void:
	var decider := ActionDecider.new(_brain())
	_see(decider, 5.0)
	equal("at 3 m only the lunge reaches", [_see(decider, 3.0), decider.chosen], [S.ATTACK, _lunge])
	equal("it finishes the move before anything else", decider.think(0.1, 9.0, 0.0, 1.0, true, false, false, _rng), S.ATTACK)
	equal("the move over, it cools down and keeps after the target", _see(decider, 1.0), S.CHASE)
	equal("a second later, cooled down, up close it jabs", [_see(decider, 1.0, 1.0), decider.chosen], [S.ATTACK, _jab])
	var flurries: int = 0
	for i: int in 50:
		if decider.pick(1.0, 0.2, _rng) == _flurry:
			flurries += 1
	equal("below a quarter hp, the heavy-weighted flurry is nearly always picked", flurries > 45, true)
	equal("nothing reaches 5 m away", decider.pick(5.0, 1.0, _rng), null)


func _retreat_leash_and_ends() -> void:
	var decider := ActionDecider.new(_brain())
	equal("hurt below 30% with the target close, it backs away",
		decider.think(0.1, 2.0, 0.0, 0.2, false, false, false, _rng), S.RETREAT)
	equal("dragged past its leash, it walks home",
		decider.think(0.1, 1.0, 15.0, 1.0, false, false, false, _rng), S.RETURN)
	equal("ignoring a target in reach on the way",
		decider.think(0.1, 1.0, 5.0, 1.0, false, false, false, _rng), S.RETURN)
	equal("home again, it fights", decider.think(0.1, 1.0, 0.2, 1.0, false, false, false, _rng), S.ATTACK)
	equal("stunned, it staggers", decider.think(0.1, 1.0, 0.0, 1.0, false, true, false, _rng), S.STAGGERED)
	decider.think(0.1, 1.0, 0.0, 0.0, false, false, true, _rng)
	equal("defeated, it stays down whatever follows", _see(decider, 1.0), S.DEFEATED)


func _problems() -> void:
	var bad := ActionBrain.new()
	bad.give_up_radius = 2.0
	equal("no moves and giving up nearer than it notices are two problems", bad.problems("fixture").size(), 2)
	equal("the test brain has none", _brain().problems("fixture"), PackedStringArray())
