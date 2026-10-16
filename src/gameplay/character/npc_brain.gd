class_name NpcBrain
extends CharacterBody3D
## One non-player character: where it should be, how it gets there, and what it does on arrival.
##
## THE SCHEDULE DECIDES WHERE, THE NAVMESH DECIDES HOW, AND THIS FILE DECIDES NEITHER. It reads
## an `NpcSchedule` for a waypoint name, resolves that name against the area's `Waypoints/` node,
## and hands the position to a `NavigationAgent3D`. Nothing here knows what a market is, and
## nothing here contains a route. That is what makes the fiftieth NPC a `.tscn` override and a
## `.tres` file rather than code.
##
## IT LISTENS TO `hour_passed`, NOT TO `minute_passed`. A schedule changes at most twenty-four
## times a day, so re-deciding sixty times an hour would be sixty times the work for the same
## answer. It also re-decides once on spawn, because an NPC loaded at 14:00 must not stand at
## its midnight post until 15:00.
##
## ARRIVAL IS THE AGENT'S ANSWER, NOT A DISTANCE CHECK. `is_navigation_finished()` accounts for
## a target that is unreachable or partially reachable; a hand-rolled `distance < 0.5` reports
## "not there yet" forever when a waypoint ends up inside a wall, and the NPC pushes at it until
## someone notices months later.
##
## OWNS: its state, its current waypoint, its movement, and its saved position.
## MUST NOT: know what any waypoint means, contain a route, read player input, draw itself, or
## decide what time it is. `CharacterVisual` draws it, unchanged from the player.

## Which schedule to follow. Empty means this NPC stands where it was placed, which is a valid
## thing to be - a shopkeeper behind a counter needs no route.
@export var schedule_id: StringName = &""
@export var walk_speed: float = 1.8
## How far from its post an NPC may drift while wandering.
@export var wander_radius: float = 2.2
## Seconds between wander destinations. Randomised by up to half this again, so a crowd of NPCs
## sharing a schedule does not move in lockstep.
@export var wander_interval: float = 4.0
## Gravity. NPCs are not expected to fall far, but a body with none floats off a slope.
@export var gravity: float = 18.0

var _visual: CharacterVisual = null
var _agent: NavigationAgent3D = null
var _state: PersistentState = null
var _schedule: NpcSchedule = null
var _waypoint: StringName = &""
var _activity: GameEnums.NpcActivity = GameEnums.NpcActivity.STAND
var _wander_left: float = 0.0
var _rng := RandomNumberGenerator.new()
## Whether the current target has already been reported as unreachable. Logged ONCE per target,
## not once per frame, or one badly placed marker fills the log at sixty lines a second.
var _unreachable_reported: bool = false
## Consecutive physics frames the current target has looked unreachable. A SINGLE frame means
## nothing: the agent recomputes its path asynchronously, so the frame after a target moves -
## which for a wandering NPC is every few seconds - it legitimately has no path yet and answers
## "unreachable" to a question it has not finished thinking about. Only a sustained answer is
## a real one.
var _unreachable_frames: int = 0
## Set once the two-physics-frame settle has run. Nothing may ask the navigation map a question
## before this, because an unsynchronised map answers "unreachable" to everything.
var _decided: bool = false


func _ready() -> void:
	collision_layer = Layers.NPC
	collision_mask = Layers.WORLD
	_visual = get_node_or_null(^"Visual") as CharacterVisual
	_agent = get_node_or_null(^"Agent") as NavigationAgent3D
	_state = get_node_or_null(^"PersistentState") as PersistentState
	if _agent == null:
		Log.error("npc", "%s has no NavigationAgent3D child called Agent" % name)
		return
	_agent.path_desired_distance = 0.4
	_agent.target_desired_distance = 0.5
	_rng.randomize()

	if schedule_id != &"":
		_schedule = ScheduleDb.schedule(schedule_id)
		if _schedule == null:
			Log.error("npc", "%s follows '%s', which does not exist" % [name, schedule_id])
	Events.hour_passed.connect(_on_hour_passed)
	# Deferred by two frames for the same reason TriggerVolume arms late: the navigation map is
	# not synchronised on the frame a region is baked, so a path requested now comes back empty
	# and the NPC decides it has already arrived.
	_settle_then_decide()


func _exit_tree() -> void:
	_remember()


func _physics_process(delta: float) -> void:
	if _agent == null:
		return
	_tick_wander(delta)
	_check_reachable()
	var step: Vector3 = Vector3.ZERO
	if not _agent.is_navigation_finished():
		var to_next: Vector3 = _agent.get_next_path_position() - global_position
		to_next.y = 0.0
		if to_next.length() > 0.001:
			step = to_next.normalized() * walk_speed
	velocity.x = step.x
	velocity.z = step.z
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	move_and_slide()
	if _visual != null:
		# AN NPC HAS NO `MoveState` OF ITS OWN, and inventing a field for one would be a second
		# state machine to keep in step with the brain. It walks or it stands, which is the honest
		# extent of what a schedule-driven actor does - and it means an NPC picks up a game's walk
		# block for free, without `NpcBrain` knowing that animation blocks exist.
		var gait: GameEnums.MoveState = GameEnums.MoveState.WALK if step.length() > 0.001 else GameEnums.MoveState.IDLE
		_visual.update_from_velocity(Vector3(velocity.x, 0.0, velocity.z), delta, gait)


## Consecutive frames an answer must hold before it is believed. Half a second at 60Hz, which
## is far longer than a path query takes and far shorter than a player would notice.
const UNREACHABLE_FRAMES: int = 30


## An unreachable target is the failure this whole file is most likely to hit, because a
## waypoint is authored by hand and a navmesh is baked from geometry: put a marker inside a
## wall, or on a ledge a step too high, and the agent paths as close as it can and then reports
## "not finished" forever while the NPC leans on the obstacle. It has to SAY so.
func _check_reachable() -> void:
	if not _decided or _agent.is_navigation_finished() or _unreachable_reported:
		return
	# A path of zero length means the query has not resolved yet, NOT that the target is
	# unreachable. Asking before the map has synchronised gets "unreachable" for everything,
	# and acting on that answer strands the NPC at get_final_position(), which is the origin.
	if _agent.get_current_navigation_path().is_empty():
		_unreachable_frames = 0
		return
	if _agent.is_target_reachable():
		_unreachable_frames = 0
		return
	_unreachable_frames += 1
	if _unreachable_frames < UNREACHABLE_FRAMES:
		return
	_unreachable_reported = true
	Log.error("npc", "%s cannot reach '%s'; it will stop where the path ends" % [name, _waypoint])
	# Settle for the closest reachable point rather than pushing at the obstacle forever.
	_agent.target_position = _agent.get_final_position()


## Where this NPC believes it should be right now. Public so a test can ask without waiting for
## an hour to pass, and so a debug tool can print a whole town's intentions.
func current_waypoint() -> StringName:
	return _waypoint


func current_activity() -> GameEnums.NpcActivity:
	return _activity


## The activity as its enum name, for logs and debug output.
func activity_name() -> String:
	var names: Array = GameEnums.NpcActivity.keys()
	var raw: String = names[current_activity()]
	return raw


func is_travelling() -> bool:
	return _agent != null and not _agent.is_navigation_finished()


## Re-read the schedule for an hour and go. Public so the suite can drive a whole day in a loop
## rather than waiting twenty-four real minutes for one.
##
## THE DAY OF THE CYCLE IS READ HERE RATHER THAN TAKEN AS AN ARGUMENT, and that is deliberate:
## the hour is something a caller legitimately hypothesises about — the suite drives a whole day,
## `--npc-day` steps one — while WHICH day of the cycle it is is a fact about the world that
## `Clock` owns. A second parameter would let two call sites disagree about the calendar.
func decide_for_hour(hour: int) -> void:
	if _schedule == null:
		return
	var entry: ScheduleEntry = _schedule.entry_for_hour(hour, Clock.day_of_cycle())
	if entry == null:
		return
	_activity = entry.activity
	if entry.waypoint == _waypoint:
		return
	_waypoint = entry.waypoint
	_remember()
	_go_to_waypoint(entry.waypoint)


## Put the NPC exactly where it belongs for an hour, with no walking. Used on load and on area
## entry: an NPC that has to WALK to its post from a save would be visibly out of place for the
## first ten seconds of every session.
func snap_to_hour(hour: int) -> void:
	if _schedule == null:
		return
	var entry: ScheduleEntry = _schedule.entry_for_hour(hour, Clock.day_of_cycle())
	if entry == null:
		return
	_activity = entry.activity
	_waypoint = entry.waypoint
	var marker: Node3D = _find_waypoint(entry.waypoint)
	if marker != null:
		global_position = marker.global_position
	_remember()
	_go_to_waypoint(entry.waypoint)


func _settle_then_decide() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	# A remembered waypoint wins over the clock: the player may have watched this NPC walk
	# somewhere unusual, and snapping it back to its timetable on load would undo that.
	var remembered: StringName = _recall()
	if remembered != &"":
		_waypoint = remembered
		_go_to_waypoint(remembered)
		_decided = true
		return
	snap_to_hour(Clock.hour)
	_decided = true


func _on_hour_passed(_day: int, hour: int) -> void:
	decide_for_hour(hour)


func _go_to_waypoint(waypoint: StringName) -> void:
	var marker: Node3D = _find_waypoint(waypoint)
	if marker == null:
		Log.warn("npc", "%s wants '%s', which this area has no marker for" % [name, waypoint])
		return
	_agent.target_position = marker.global_position
	_unreachable_reported = false
	_unreachable_frames = 0
	_wander_left = _next_wander_delay()


## Waypoints live under the AREA, not under the NPC, so two NPCs sharing a destination share
## one marker and moving it moves both.
func _find_waypoint(waypoint: StringName) -> Node3D:
	var area: Node = _area_root()
	if area == null:
		return null
	var markers: Node = area.get_node_or_null(^"Waypoints")
	if markers == null:
		return null
	return markers.get_node_or_null(NodePath(String(waypoint))) as Node3D


func _area_root() -> Node:
	var walker: Node = get_parent()
	while walker != null:
		if walker is AreaRoot:
			return walker
		walker = walker.get_parent()
	return null


## Wander is a small random offset from the post, re-picked on a timer. It is not a behaviour
## tree and is not trying to be: an NPC that shifts its weight occasionally reads as alive, and
## anything more belongs to WP-09.
func _tick_wander(delta: float) -> void:
	if _activity != GameEnums.NpcActivity.WANDER or _waypoint == &"":
		return
	if not _agent.is_navigation_finished():
		return
	_wander_left -= delta
	if _wander_left > 0.0:
		return
	_wander_left = _next_wander_delay()
	var marker: Node3D = _find_waypoint(_waypoint)
	if marker == null:
		return
	var angle: float = _rng.randf() * TAU
	var reach: float = _rng.randf() * wander_radius
	# A new target invalidates any accumulated unreachable evidence: the old answer was about a
	# different destination.
	_unreachable_reported = false
	_unreachable_frames = 0
	var wish: Vector3 = marker.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
	_agent.target_position = reachable_point(_agent.get_navigation_map(), global_position, wish,
			_agent.navigation_layers)


## The nearest point to `wish` that a walk from `from` can actually end on.
##
## A WANDER TARGET IS INVENTED, NOT AUTHORED, SO IT IS CLAMPED BEFORE IT IS HANDED OUT. A random
## offset from a post can land on a riser the body cannot climb, inside a prop, or in the strip
## the bake erodes by `agent_radius` beside a wall, and `_check_reachable()` then logs an ERROR
## for a destination nobody wrote. Only an authored waypoint may be reported unreachable: that
## is a content defect, and this is not. The query is synchronous, which is fine at one per NPC
## every few seconds. With no path at all (no region, or a map not yet synchronised) the answer
## is `from`, so the NPC stands still rather than pushing at nothing.
static func reachable_point(map: RID, from: Vector3, wish: Vector3, layers: int) -> Vector3:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, wish, true, layers)
	if path.is_empty():
		return from
	return path[path.size() - 1]


func _next_wander_delay() -> float:
	return wander_interval + _rng.randf() * wander_interval * 0.5


## Persisted through PersistentState, so an NPC's whereabouts ride the save machinery that
## already exists rather than inventing a second one. Only the WAYPOINT is stored, not the
## position: a stored position would be a coordinate authored against today's geometry, and the
## marker is the thing that means something.
func _remember() -> void:
	if _state != null and _state.is_valid_state() and _waypoint != &"":
		_state.store(&"waypoint", String(_waypoint))


func _recall() -> StringName:
	if _state == null or not _state.is_valid_state():
		return &""
	return StringName(_state.fetch_string(&"waypoint", ""))
