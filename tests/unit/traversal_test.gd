extends TestCase
## Triggers and traversal: a volume that fires on entry, a rest that skips hours, and an
## authored climb. Driven by direct fire()/attempt()/climb_step() calls, never by simulated
## input and never by waiting on real frames.
##
## OWNS: assertions about entry triggers, time skipping and vertical movement.
## MUST NOT: re-assert clock arithmetic that world_test already covers, or inventory anything.

const SLOT: int = 3

var _mover: PlayerController = null


func run() -> void:
	plan(56)
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Flags.clear_all()
	SaveSystem.unregister(&"world")
	_trigger_fires_once()
	_trigger_survives_a_reload()
	_repeating_trigger()
	_resting()
	_climbing()
	_tear_down()


func _trigger_fires_once() -> void:
	var trigger: TriggerVolume = _make_trigger(&"t_gate_trip", true)
	# An Array, not an int: a GDScript lambda captures locals BY VALUE, so a counter kept in
	# an int would be incremented on a copy and the assertion would always read zero.
	var heard: Array[StringName] = []
	var listener: Callable = func(id: StringName, _who: Node3D) -> void: heard.append(id)
	Events.trigger_fired.connect(listener)

	equal("it sits on the trigger layer", trigger.collision_layer, Layers.TRIGGER)
	equal("and watches for the player", trigger.collision_mask, Layers.PLAYER)
	equal("and is wired to body_entered", trigger.body_entered.get_connections().size(), 1)
	equal("a fresh trigger has not fired", trigger.has_fired(), false)
	equal("entering fires it", trigger.fire(null), true)
	equal("it knows it fired", trigger.has_fired(), true)
	equal("it announced itself once", heard.size(), 1)
	equal("and named itself", heard[0], &"t_gate_trip")
	equal("its flag is set", Flags.get_bool(&"area/test/tripped"), true)

	equal("entering again does nothing", trigger.fire(null), false)
	equal("and announced nothing more", heard.size(), 1)
	equal("state landed under its object id", Flags.get_bool(&"obj/global/t_gate_trip/fired"), true)
	Events.trigger_fired.disconnect(listener)
	trigger.free()


func _trigger_survives_a_reload() -> void:
	equal("save", SaveSystem.save_to_slot(SLOT), OK)
	Flags.set_flag(&"obj/global/t_gate_trip/fired", false)
	equal("load", SaveSystem.load_from_slot(SLOT), OK)
	equal("the world still knows it fired", Flags.get_bool(&"obj/global/t_gate_trip/fired"), true)

	# A rebuilt trigger is what an area reload produces. It must not fire a second time.
	var rebuilt: TriggerVolume = _make_trigger(&"t_gate_trip", true)
	equal("a rebuilt trigger is already fired", rebuilt.has_fired(), true)
	equal("and is disarmed, so nothing can walk into it", rebuilt.is_disarmed(), true)
	equal("and refuses to fire again", rebuilt.fire(null), false)
	rebuilt.free()


func _repeating_trigger() -> void:
	var trigger: TriggerVolume = _make_trigger(&"t_ambience", false)
	equal("a repeating trigger fires", trigger.fire(null), true)
	equal("and fires again", trigger.fire(null), true)
	equal("and stays armed", trigger.is_disarmed(), false)
	trigger.free()


func _resting() -> void:
	var bench: RestPoint = _make_bench()
	Clock.set_time(1, 6, 30)
	equal("the bench offers a rest", bench.refusal(null), GameEnums.RefusalReason.NONE)
	equal("resting succeeds", bench.attempt(null), true)
	equal("the hour is the target", Clock.hour, 20)
	equal("on the minute", Clock.minute, 0)
	equal("still the same day", Clock.day, 1)

	# The whole reason skip_to_hour exists: a thirteen-hour rest is ONE event, not 780 of them.
	var ticks: Array[int] = [0]
	var counter: Callable = func(_d: int, _h: int, _m: int) -> void: ticks[0] += 1
	Events.minute_passed.connect(counter)
	Clock.set_time(1, 23, 0)
	ticks[0] = 0
	equal("resting past midnight succeeds", bench.attempt(null), true)
	equal("it rolled into tomorrow", Clock.day, 2)
	equal("and emitted one minute_passed, not 1260", ticks[0], 1)
	Events.minute_passed.disconnect(counter)

	bench.night_only = true
	Clock.set_time(2, 12, 0)
	equal("a night-only bed refuses at noon", bench.refusal(null), GameEnums.RefusalReason.WRONG_TIME)
	equal("and the attempt fails", bench.attempt(null), false)
	equal("leaving the clock where it was", Clock.hour, 12)
	bench.free()


func _climbing() -> void:
	var ladder: ClimbPoint = _make_ladder()
	_mover = build("res://scenes/characters/player.tscn") as PlayerController
	attach(_mover)
	_mover.global_position = Vector3.ZERO

	# A body that has never touched a floor is, by is_on_floor()'s definition, mid-air.
	equal("mid-air cannot climb", _mover.can_climb(), false)
	equal("so the ladder refuses", ladder.refusal(_mover), GameEnums.RefusalReason.NOT_GROUNDED)
	equal("and the attempt fails", ladder.attempt(_mover), false)
	equal("nobody moved", _mover.global_position, Vector3.ZERO)
	equal("a non-climber lacks the skill", ladder.refusal(null), GameEnums.RefusalReason.MISSING_SKILL)

	var top: Vector3 = ladder.top_point.global_position
	var foot: Vector3 = ladder.bottom_point.global_position
	equal("the far end from the foot is the top", ladder.far_end_from(foot), top)
	equal("the far end from the top is the foot", ladder.far_end_from(top), foot)

	_drive_climb(top)
	equal("the climb ended high up", _mover.global_position.is_equal_approx(top), true)
	equal("and handed control back", _mover.state, GameEnums.MoveState.IDLE)
	_drive_climb(foot)
	equal("and it comes back down", _mover.global_position.is_equal_approx(foot), true)
	ladder.free()


## Drives a climb to completion without waiting on real frames, one fixed step at a time.
## Bounded, so a climb that never converges fails an assertion instead of hanging the suite.
func _drive_climb(destination: Vector3) -> void:
	equal("the climb starts", _mover.begin_climb(destination), true)
	equal("a climb in progress refuses a second", _mover.begin_climb(destination), false)
	equal("the body is climbing", _mover.state, GameEnums.MoveState.CLIMB)
	# THE ASSERTION THAT WAS MISSING. `_mover.state` above and `animation_for(CLIMB)` in
	# art_contract_test each proved one END of the seam, and nothing proved the WIRE: while a
	# climb owns the body `_physics_process` returns early, so the visual never heard about a
	# climb at all and `climb_row` could not be drawn. Assert the drawn BLOCK, not the state.
	var visual: CharacterVisual = _mover.visual
	var idle_block: int = _block_drawn(visual)
	_mover.climb_step(1.0 / 60.0)
	equal("a climb draws the climb block", _block_drawn(visual), _climb_block(visual))
	var first: int = visual.sprite.frame
	var steps: int = 0
	while _mover.is_climbing() and steps < 600:
		_mover.climb_step(1.0 / 60.0)
		steps += 1
	equal("the climb finished within its budget", _mover.is_climbing(), false)
	equal("and its cycle actually advanced", visual.sprite.frame != first, true)
	equal("standing still went back to the idle block", _block_drawn(visual), idle_block)


## Which animation BLOCK the sprite is drawing, decoded from the one number the sheet exposes.
## `frame_index` is `(animation * frames + frame) * facings + column`, so the block is the
## frame index divided by a row of facings and then by the cycle length.
func _block_drawn(visual: CharacterVisual) -> int:
	var layout: SpriteSheetLayout = visual.layout
	return (visual.sprite.frame / layout.facings) / layout.frames


## The block a climb SHOULD draw for this sheet. The shipped placeholder leaves `climb_row` at
## -1, so this is the walk block - which is the point: the fallback is what most sheets use, and
## it still has to be reached. A sheet that draws its own climb cycle is asserted separately.
func _climb_block(visual: CharacterVisual) -> int:
	return visual.layout.animation_for(GameEnums.MoveState.CLIMB)


func _make_trigger(object_id: StringName, once: bool) -> TriggerVolume:
	var trigger: TriggerVolume = build("res://scenes/objects/trigger_volume.tscn") as TriggerVolume
	trigger.object_id = object_id
	trigger.fires_once = once
	trigger.world_flag = &"area/test/tripped"
	attach(trigger)
	return trigger


func _make_bench() -> RestPoint:
	var bench: RestPoint = build("res://scenes/objects/rest_point.tscn") as RestPoint
	bench.label_key = "fixture.rest_point.label"
	bench.target_hour = 20
	attach(bench)
	return bench


func _make_ladder() -> ClimbPoint:
	var ladder: ClimbPoint = build("res://scenes/objects/climb_point.tscn") as ClimbPoint
	ladder.label_key = "fixture.climb_point.label"
	attach(ladder)
	return ladder


func _tear_down() -> void:
	SaveSystem.delete_slot(SLOT)
	if _mover != null:
		_mover.free()
		_mover = null
	Flags.clear_all()
