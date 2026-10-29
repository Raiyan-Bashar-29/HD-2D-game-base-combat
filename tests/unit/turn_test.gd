extends TestCase
## A TURN IN PLACE: who may ask for one, who answers, and the two moments the player is asked.
##
## `facing_test.gd` owns the mapping from a direction to a facing and a column, and proves it
## camera-yaw independently. This file owns the SEAM ABOVE that mapping, which until T5.14 did
## not exist: `CharacterVisual.face_direction()` was correct, asserted and reached only from
## `tests/`, one of the 86 suite-only methods `check_methods.gd` reports. `Events.turn_requested`
## is the occasion it was missing, and every assertion here is about the wiring rather than the
## trigonometry - which is why not one of them names a sector, an angle or a column number.
##
## EVERY EXPECTED FACING IS COMPUTED, NEVER WRITTEN DOWN. `facing_from_direction` subtracts the
## active camera's yaw, so "the point at (2, 0, 0) is facing 6" is true for one camera and false
## for the next. Asking the same object what it would answer for the same direction is the only
## claim that survives an area framing its camera differently, and it still fails the moment the
## bus hands the listener the wrong vector - which is the defect this file exists to catch.
##
## THE SENSOR IS DRIVEN BY HAND. The suite is synchronous, so `_physics_process` is called
## directly with a delta and candidates are handed over by emitting `Area3D.area_entered` -
## both public engine surfaces. Nothing here awaits a frame, because nothing in `tests/` does.
##
## OWNS: that a turn request reaches exactly the character it names, that a turn survives a
##   standing frame and not a moving one, and both askers' occasions.
## MUST NOT: re-assert the direction-to-facing mapping (facing_test), assert what the sprite
##   looks like on screen, or name demo content.

const FACINGS: int = 8
const FRAMES: int = 4
const CELL: Vector2i = Vector2i(32, 48)
## A candidate close enough to be inside the sensor's default 2.4m reach.
const NEAR: Vector3 = Vector3(1.0, 0.0, 0.0)
## A point on the other side of the character from NEAR, so a turn towards it is unmistakable.
const FAR_SIDE: Vector3 = Vector3(-2.0, 0.0, -2.0)
## One physics step at 60Hz. The value is irrelevant to every assertion here; the CALL is not.
const STEP: float = 1.0 / 60.0
## Fast enough to be walking by any threshold either file uses.
const WALKING: Vector3 = Vector3(0.0, 0.0, 2.0)

## Every (character, towards) pair the bus carried during one case.
var _asks: Array[Array] = []


func run() -> void:
	plan(13)
	Events.turn_requested.connect(_on_turn_requested)
	_the_request_reaches_only_the_character_it_names()
	_a_turn_survives_standing_still_and_not_walking()
	_a_speaker_turns_the_person_it_hangs_under()
	_the_sensor_asks_only_while_the_player_is_still()
	Events.turn_requested.disconnect(_on_turn_requested)


## THE FILTER IS THE WHOLE DESIGN. Every `CharacterVisual` in the area hears every request, so
## a listener that skipped the check would turn a courtyard full of people as one man - and it
## would still pass any test that built only one character, which is why this builds two.
func _the_request_reaches_only_the_character_it_names() -> void:
	var me: CharacterBody3D = _a_character()
	var somebody_else: CharacterBody3D = _a_character()
	var mine: CharacterVisual = me.get_node(^"Visual")
	var theirs: CharacterVisual = somebody_else.get_node(^"Visual")
	var settled: int = int(theirs.facing())

	Events.turn_requested.emit(me, FAR_SIDE)
	equal("a turn request turns the character it names",
		int(mine.facing()), int(mine.facing_from_direction(Vector2(FAR_SIDE.x, FAR_SIDE.z))))
	equal("and leaves every character it does not name exactly where it was",
		int(theirs.facing()), settled)

	# A null character is not an error worth logging: an asker whose target was freed this frame
	# is the ordinary case, and turning nobody is the right answer to it.
	var was: int = int(mine.facing())
	Events.turn_requested.emit(null, NEAR)
	equal("a request naming nobody turns nobody", int(mine.facing()), was)
	me.free()
	somebody_else.free()


## THE CLAIM THAT MADE THIS PACKAGE CHEAP, and it is a claim about `update_from_velocity` rather
## than about the turn: it re-aims only while the character is actually moving, so a turn given
## to somebody standing persists with no hold flag, no timer and no listener to undo it. If that
## ever stops being true, an NPC will snap back to its old facing one frame after you speak to
## it, and this is the assertion that says so.
func _a_turn_survives_standing_still_and_not_walking() -> void:
	var body: CharacterBody3D = _a_character()
	var visual: CharacterVisual = body.get_node(^"Visual")
	Events.turn_requested.emit(body, FAR_SIDE)
	var turned: int = int(visual.facing())

	visual.update_from_velocity(Vector3.ZERO, STEP, GameEnums.MoveState.IDLE)
	equal("a turn survives a standing frame, so no hold flag is needed anywhere",
		int(visual.facing()), turned)

	visual.update_from_velocity(WALKING, STEP, GameEnums.MoveState.WALK)
	equal("and a walking frame overrides it, which is why the sensor asks only while still",
		int(visual.facing()), int(visual.facing_from_direction(Vector2(WALKING.x, WALKING.z))))
	body.free()


## `Speaker` knows it may hang under a `CharacterBody3D` and nothing more than that. Both halves
## matter: a speaker on a person asks, and a speaker on a plaque - which is the shipped case for
## a notice board - asks for nothing rather than for a turn nobody can perform.
func _a_speaker_turns_the_person_it_hangs_under() -> void:
	# The fixture conversation has to be ON DISK and loaded before a speaker naming it will
	# do anything but refuse, and this case may run before whichever one installs it.
	Fixtures.activate()
	var body: CharacterBody3D = _a_character()
	var mouth := Speaker.new()
	mouth.label_key = "fixture.speaker.label"
	# A real fixture conversation, so `_ready` does not log the refusal it logs for an empty id.
	mouth.conversation_id = FixtureContent.TALK
	body.add_child(mouth)
	var talker := Node3D.new()
	attach(talker)
	talker.global_position = FAR_SIDE

	_asks.clear()
	# `attempt()` and not `perform()`, because that is the entry the sensor uses and a test that
	# skips the refusal check is testing a path the game never takes.
	mouth.attempt(talker)
	equal("a speaker on a person asks that person to turn towards whoever spoke",
		_asks == [[body, FAR_SIDE]], true)

	var plaque := Speaker.new()
	plaque.label_key = "fixture.speaker.label"
	plaque.conversation_id = FixtureContent.TALK
	attach(plaque)
	_asks.clear()
	plaque.attempt(talker)
	equal("a speaker on scenery asks for no turn at all", _asks.size(), 0)
	plaque.free()
	talker.free()
	body.free()


## THE STILLNESS GATE, which is the only judgement in this package that could reasonably have
## gone the other way. Five frames: arrive standing, hold, walk on, have the SELECTION CHANGE
## mid-walk, and stop.
##
## THE FOURTH FRAME IS THE ONE THAT MATTERS, and a first draft of this case did not have it.
## Without a target that changes while the player is moving, dropping the stillness test
## changes nothing measurable - `just_stopped` already implies stillness - so the gate passed
## its own plant, green, and the assertion was decoration. Walking past a row of objects is
## precisely the situation the gate exists for, so it is precisely what has to be staged.
func _the_sensor_asks_only_while_the_player_is_still() -> void:
	var body: CharacterBody3D = _a_character()
	var sensor := InteractionSensor.new()
	body.add_child(sensor)
	var target: Interactable = _a_target(NEAR)
	var passed_on_the_way: Interactable = _a_target(NEAR)
	passed_on_the_way.interact_priority = 1

	sensor.area_entered.emit(target)
	_asks.clear()
	body.velocity = Vector3.ZERO
	sensor._physics_process(STEP)
	equal("a target selected while standing still asks for a turn", _asks.size(), 1)

	sensor._physics_process(STEP)
	equal("and the same target on the next frame asks for nothing more", _asks.size(), 1)

	body.velocity = WALKING
	sensor._physics_process(STEP)
	equal("a frame spent walking on the same target asks for nothing", _asks.size(), 1)

	sensor.area_entered.emit(passed_on_the_way)
	sensor._physics_process(STEP)
	equal("and a target that takes the prompt MID-WALK asks for nothing either",
		_asks.size(), 1)

	body.velocity = Vector3.ZERO
	sensor._physics_process(STEP)
	equal("but coming to rest asks for the turn every walking frame refused", _asks.size(), 2)
	equal("towards what is selected now, not what was selected when the walk began",
		_asks[1][1], passed_on_the_way.focus_point())
	passed_on_the_way.free()
	target.free()
	body.free()


## A bare interactable in reach. `Interactable` itself rather than any authored subclass: the
## sensor ranks the base class and nothing here needs an object that DOES anything.
func _a_target(where: Vector3) -> Interactable:
	var target := Interactable.new()
	target.label_key = "fixture.target.label"
	attach(target)
	target.global_position = where
	return target


func _on_turn_requested(character: Node3D, towards: Vector3) -> void:
	_asks.append([character, towards])


## A body with a visual under it, exactly as both shipped character scenes are built. Built by
## hand rather than instantiated, so this case names no scene and survives the demo's deletion.
func _a_character() -> CharacterBody3D:
	var layout := SpriteSheetLayout.new()
	layout.facings = FACINGS
	layout.frames = FRAMES
	layout.cell_size = CELL
	var body := CharacterBody3D.new()
	var visual := CharacterVisual.new()
	visual.name = "Visual"
	visual.layout = layout
	body.add_child(visual)
	attach(body)
	return body
