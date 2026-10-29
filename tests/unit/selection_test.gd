extends TestCase
## SELECTION, WITH REAL GEOMETRY: which of several overlapping objects the sensor decides the
## player means, and the override that lets them disagree.
##
## WHY THIS FILE EXISTS, IN ANOTHER FILE'S WORDS. `interaction_test.gd`'s MUST NOT line has said
## since WP-02 that the ranking "needs real geometry and belongs in a scene-level test", and
## that test was never written. So the rule EVERY interactable rests on — the one the sensor's
## own header calls the actual problem it solves, because "detection is trivial; selection is
## not" — was asserted nowhere, in a suite of two thousand assertions. This is gotcha 54's shape
## at the top of the interaction stack: `interaction_test.gd` proves what an object DOES once it
## is chosen, `turn_test.gd` proves the turn once it is, and between them sits the decision
## neither one makes.
##
## THE SENSOR IS DRIVEN BY HAND, on `turn_test.gd`'s precedent: the suite is synchronous, so
## `_physics_process` is called with a delta and candidates arrive by emitting
## `Area3D.area_entered`. Both are public engine surfaces. Nothing here awaits a frame, and the
## cycle goes through `InteractionSensor.cycle()` rather than through a faked keypress — see
## that method's own header for why a faked one cannot work inside this suite.
##
## EVERY DISTANCE IS A FRACTION OF THE SENSOR'S OWN REACH, never a metre count. `max_distance`
## is exported, so a consuming game that gives the player longer arms must not fail this file —
## and a case that wrote 1.0 would. The same discipline `interaction_test.gd` applies to a
## gate's shake amplitude.
##
## OWNS: the ranking — priority, then proximity, then facing, then the name tie-break — what
##   falls out of the candidate set, the cycle override, and that `Readable` and `Speaker` reach
##   the bus through a real selection.
## MUST NOT: assert what any object DOES once chosen (interaction_test), re-assert the turn or
##   its occasions (turn_test), or name demo content.

## One physics step at 60Hz. The value is irrelevant to every assertion here; the CALL is not.
const STEP: float = 1.0 / 60.0
## Fast enough to re-aim `_track_facing`, whose own threshold is well below this.
const WALK_SPEED: float = 2.0

## Fractions of the sensor's reach, so nothing here hard-codes a metre.
const CLOSE: float = 0.4
const MIDDLE: float = 0.6
const FAR: float = 0.8
## Past the reach, so the score is -INF and the object leaves the RANKING without leaving the
## candidate set — which is the distinction this case exists to be able to tell apart.
const UNREACHABLE: float = 1.5

const SIGN_SCENE: String = "res://scenes/objects/sign.tscn"
const SPEAKER_SCENE: String = "res://scenes/objects/speaker.tscn"
## Deliberately not in strings.csv: tr() returns a missing key unchanged, so the assertion
## compares against the key itself and cannot pass by translation.
const SIGN_TEXT: String = "fixture.sign.text"

var _body: CharacterBody3D = null
var _sensor: InteractionSensor = null
var _reach: float = 0.0


func run() -> void:
	plan(24)
	_priority_beats_proximity()
	_proximity_decides_between_equal_priorities()
	_facing_decides_between_equidistant_objects()
	_a_tie_is_broken_by_name_not_by_arrival_order()
	_out_of_reach_and_unavailable_leave_the_ranking()
	_the_cycle_walks_the_ranking_and_wraps()
	_a_lone_candidate_has_nothing_to_cycle_to()
	_the_two_unasserted_prefabs_reach_the_bus_through_a_real_selection()


## THE RULE THE SENSOR WAS BUILT FOR, quoted from its own header: "a player facing a lever with
## a sign fractionally closer will press the button and read the sign, which reads as a bug."
##
## BOTH DIRECTIONS, because the first assertion alone would pass on a ranking that had simply
## preferred the farther object. Dropping the priority to zero and re-ranking is what says the
## AUTHORED INTENT was the cause: no geometry changed between these two frames.
func _priority_beats_proximity() -> void:
	_a_sensor()
	var near: Interactable = _a_target("A_near", CLOSE)
	var far: Interactable = _a_target("B_far", FAR)
	far.interact_priority = 1
	_sensor._physics_process(STEP)
	equal("an authored priority takes the prompt from a nearer object",
		_sensor.current() == far, true)

	far.interact_priority = 0
	_sensor._physics_process(STEP)
	equal("and with the priority gone the nearer object takes it back, same geometry",
		_sensor.current() == near, true)
	_tear_down()


## Equal priority, so the second term decides. Both sit on the same axis, which holds the facing
## term identical between them and leaves distance as the only difference.
func _proximity_decides_between_equal_priorities() -> void:
	_a_sensor()
	var near: Interactable = _a_target("A_near", CLOSE)
	var far: Interactable = _a_target("B_far", FAR)
	_sensor._physics_process(STEP)
	equal("between equals the nearer object is the one meant", _sensor.current() == near, true)

	# Move the world rather than the ranking: the object that WAS far is now the close one.
	near.global_position = _ahead(FAR)
	far.global_position = _ahead(CLOSE)
	_sensor._physics_process(STEP)
	equal("and the selection follows the geometry when the objects move",
		_sensor.current() == far, true)
	_tear_down()


## THE FACING TERM, AND `_track_facing` WITH IT. Two objects the same distance away on opposite
## sides: the one the player is pointing at wins, and walking the other way hands it over. That
## second frame is the whole path rather than the arithmetic — it fails if velocity stops
## reaching `_facing`, which no assertion anywhere else would notice.
func _facing_decides_between_equidistant_objects() -> void:
	_a_sensor()
	var ahead: Interactable = _a_target("A_ahead", CLOSE)
	var behind: Interactable = _a_target("B_behind", CLOSE)
	behind.global_position = _ahead(-CLOSE)

	_body.velocity = _forward() * WALK_SPEED
	_sensor._physics_process(STEP)
	equal("of two objects equally close, the one being faced is the one meant",
		_sensor.current() == ahead, true)

	_body.velocity = _forward() * -WALK_SPEED
	_sensor._physics_process(STEP)
	equal("and turning round hands the prompt to the other one, nothing having moved",
		_sensor.current() == behind, true)
	_tear_down()


## THE TIE-BREAK, which the sensor's header justifies as stability: "ties are broken by node name
## so the order is stable frame to frame rather than dependent on physics callback order."
##
## THE TWO OBJECTS ARE AT THE SAME POINT, so every scored term is identical and the name is the
## only thing left. AND THEY ARE HANDED OVER IN REVERSE NAME ORDER, which is the half that can
## actually fail: a sort that had quietly become a no-op would return the first CANDIDATE, and
## with the candidates arriving in name order that is the same answer the rule gives.
func _a_tie_is_broken_by_name_not_by_arrival_order() -> void:
	_a_sensor()
	var later: Interactable = _a_target("Z_later", CLOSE)
	var earlier: Interactable = _a_target("A_earlier", CLOSE)
	_sensor._physics_process(STEP)
	equal("the earlier name wins a dead tie", _sensor.current() == earlier, true)
	equal("and not the one that was handed over first", _sensor.current() == later, false)

	_sensor._physics_process(STEP)
	equal("and it is the same object on the next frame, which is what stable means",
		_sensor.current() == earlier, true)
	_tear_down()


## WHAT IS IN THE CANDIDATE SET AND NOT IN THE RANKING. Both exclusions are reversed in place, so
## neither assertion can be satisfied by a sensor that simply never selected anything — which a
## bare "it is null" would be.
func _out_of_reach_and_unavailable_leave_the_ranking() -> void:
	_a_sensor()
	var target: Interactable = _a_target("A_only", UNREACHABLE)
	_sensor._physics_process(STEP)
	equal("an object past the sensor's reach is a candidate and not a choice",
		_sensor.current() == null, true)

	target.global_position = _ahead(CLOSE)
	_sensor._physics_process(STEP)
	equal("and it becomes the choice the moment it is in reach",
		_sensor.current() == target, true)

	# set_available, not the field: it emits availability_changed, which is the path the game
	# takes when a gate unlocks beside a player already standing there.
	target.set_available(false)
	_sensor._physics_process(STEP)
	equal("an object present but inert is not offered", _sensor.current() == null, true)
	_tear_down()


## THE OVERRIDE. Three objects at three distances, so the ranking is total and known, and the
## cycle walks it in order and comes back round.
##
## THE LAST ASSERTION IS THE ONE WITH TEETH. `_physics_process` re-selects every frame, so if the
## cycle offset were reset there — which is exactly what happens when the ranking's best changes
## — the player's deliberate choice would be silently taken back one frame later, and the four
## assertions above it would every one still pass.
func _the_cycle_walks_the_ranking_and_wraps() -> void:
	_a_sensor()
	var first: Interactable = _a_target("A_first", CLOSE)
	var second: Interactable = _a_target("B_second", MIDDLE)
	var third: Interactable = _a_target("C_third", FAR)
	_sensor._physics_process(STEP)
	equal("the ranking's own best is what the player is offered first",
		_sensor.current() == first, true)

	equal("cycling once offers the second in the ranking", _cycled() == second, true)
	equal("cycling again offers the third", _cycled() == third, true)
	equal("and cycling past the end comes back round to the first", _cycled() == first, true)

	var chosen: Interactable = _cycled()
	_sensor._physics_process(STEP)
	equal("a cycled choice survives the next frame rather than being re-ranked away",
		_sensor.current() == chosen, true)
	_tear_down()


## A PLAYER BESIDE ONE OBJECT, which is most of the game. The cycle must report that it did
## nothing, because its caller falls through to the interact key on a false — so a `cycle()` that
## returned true here would swallow the button beside every solitary object in the world.
func _a_lone_candidate_has_nothing_to_cycle_to() -> void:
	_a_sensor()
	var only: Interactable = _a_target("A_only", CLOSE)
	_sensor._physics_process(STEP)
	equal("a lone candidate reports that there was nowhere to cycle", _sensor.cycle(), false)
	equal("and leaves the player holding the object they already had",
		_sensor.current() == only, true)
	_tear_down()


## `Readable` AND `Speaker`, THE TWO PREFABS `AUTHORING.md` TELLS A CONSUMER TO PLACE AND WHICH
## NOTHING ASSERTED. Both are reached the way the game reaches them — ranked out of a set of two
## overlapping objects, then attempted through whatever `current()` handed back — so what fails
## if the wire is cut is the ask on the bus, not a method call this file chose to make.
##
## THE SHIPPED PREFABS, not `Readable.new()`: an authored `.tscn` is what a consuming game
## instances, and its script, its verb and its reach shape are part of what is promised.
func _the_two_unasserted_prefabs_reach_the_bus_through_a_real_selection() -> void:
	# The fixture conversation must be on disk before a speaker naming it does anything but
	# refuse, and this case may run before whichever one installs it.
	Fixtures.activate()
	_a_sensor()
	var asks: Array[Array] = []
	var on_text: Callable = func(key: String, _seconds: float, _args: Dictionary) -> void:
		asks.append(["text", key])
	var on_talk: Callable = func(talk_id: StringName) -> void:
		asks.append(["talk", String(talk_id)])
	Events.notify_requested.connect(on_text)
	Events.dialogue_requested.connect(on_talk)

	# Configured BEFORE attaching, all three of them: `object_id` is forwarded in `_enter_tree`
	# (gotcha 8), and both prefabs' `_ready` complains about a key or an id it does not have yet.
	var board: Readable = build(SIGN_SCENE) as Readable
	board.object_id = &"t_sign"
	board.text_key = SIGN_TEXT
	board.label_key = "fixture.target.label"
	attach(board)
	_place(board, CLOSE)
	var mouth: Speaker = build(SPEAKER_SCENE) as Speaker
	mouth.conversation_id = FixtureContent.TALK
	mouth.label_key = "fixture.target.label"
	attach(mouth)
	_place(mouth, FAR)

	_sensor._physics_process(STEP)
	equal("the nearer of the two shipped prefabs is the one selected",
		_sensor.current() == board, true)
	equal("and attempting what the sensor selected succeeds", _attempt_current(), true)
	equal("the cycle reaches the speaker behind it", _cycled() == mouth, true)
	equal("and attempting that succeeds too", _attempt_current(), true)
	equal("each prefab asked the bus for its own thing, once, in that order",
		asks == [["text", SIGN_TEXT], ["talk", String(FixtureContent.TALK)]], true)

	Events.notify_requested.disconnect(on_text)
	Events.dialogue_requested.disconnect(on_talk)
	_tear_down()


## Attempt whatever is selected, through the sensor rather than through a saved reference, so a
## selection that had quietly become null fails here instead of asserting against the wrong node.
func _attempt_current() -> bool:
	var chosen: Interactable = _sensor.current()
	if chosen == null:
		return false
	return chosen.attempt(_body)


## Cycle, then report what the player now holds. One helper so a case reads as the sequence of
## presses it describes.
func _cycled() -> Interactable:
	_sensor.cycle()
	return _sensor.current()


## A body with a sensor under it, exactly as the shipped player is built. Built by hand rather
## than instantiated, so this file names no scene the demo owns and survives its deletion.
##
## THE BODY IS AT THE ORIGIN AND EVERY TARGET IS PLACED RELATIVE TO THE SENSOR, so no assertion
## here depends on where anything is in world space.
func _a_sensor() -> void:
	_body = CharacterBody3D.new()
	_sensor = InteractionSensor.new()
	_body.add_child(_sensor)
	attach(_body)
	_reach = _sensor.max_distance


## A bare interactable in the candidate set, handed over the way physics would hand it over.
## `Interactable` itself rather than a subclass: the sensor ranks the base class, and nothing
## about a ranking needs an object that DOES anything.
func _a_target(node_name: String, at: float) -> Interactable:
	var target := Interactable.new()
	target.name = node_name
	target.label_key = "fixture.target.label"
	attach(target)
	_place(target, at)
	return target


## Put an object where the case says, and tell the sensor it arrived.
func _place(target: Interactable, at: float) -> void:
	target.global_position = _ahead(at)
	_sensor.area_entered.emit(target)


## The direction the sensor's facing starts at, read from the node rather than written down.
func _forward() -> Vector3:
	return _sensor.global_transform.basis * Vector3.FORWARD


## A point the given fraction of the sensor's reach in front of it. Negative is behind.
func _ahead(fraction: float) -> Vector3:
	return _sensor.global_position + _forward() * _reach * fraction


## Free the body and every target with it — anything left alive at exit buries a real error in a
## wall of leaked-RID complaints.
func _tear_down() -> void:
	for child: Node in get_children():
		if child is Interactable:
			child.free()
	_body.free()
	_body = null
	_sensor = null
