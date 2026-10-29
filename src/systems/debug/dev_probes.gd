extends Node
## Scenario probes: the verification that no assertion can perform. Lives in the game root,
## beside `dev_capture.gd`.
##
## WHY THIS FILE HAS TO EXIST AT ALL
## `TestCase.run()` is SYNCHRONOUS — the runner calls it and does not await it — so no assertion
## in this project can wait on a physics frame. That rules out testing, by assertion, every
## behaviour that needs frames to happen: a threaded area load, a navmesh path, a typewriter
## reveal, a key press. Those are not untestable, they are testable by a different means, and
## this is the means. Each probe drives the REAL game through the REAL bus and prints what
## actually happened, so a claim in `DEVLOG.md` is a quotation rather than an assurance.
##
## THREE DEBUG FILES, AND THE BUDGET CHECKER FOUND EVERY SEAM. `dev_capture.gd` answers "what
## does the game LOOK like under condition X" and owns the shutter; this file answers "does
## sequence Y actually work" and owns the measurements; `dev_stage.gd` answers "put the player
## THERE, holding THAT" and owns the posing. All three were one file until the checker refused
## it at 310 and then at 320 of the 250 allowed code lines, and both times the seam it exposed
## was already there in the reasoning.
##
## EVERYTHING AFTER THE BARE `--` IS PASSED TO THE GAME:
##
##   --round-trips=<n>    travel courtyard -> lantern_hall -> courtyard n times, reporting node
##                        count and static memory. This is how the leak criterion is measured,
##                        and each trip also fires a second request in the same frame, so the
##                        re-entrancy guard is exercised twice per trip.
##   --cross-area-save    empty a chest in the hall, take an item in the courtyard, save,
##                        reload, and report whether BOTH survived. Proves world state on the
##                        far side of an area that is no longer loaded.
##   --npc-day            walk the clock through a whole day an hour at a time and report where
##                        each NPC actually ends up. This is how the schedule criterion is
##                        measured: no assertion can drive a navmesh.
##   --npc-storm=<n>      spawn n extra NPCs and report frame time with and without them.
##
## A TEMPORARY PROBE IS THE APPROVED WAY TO TEST AN INPUT PATH. Add one here, run it windowed,
## read the log, quote it in `DEVLOG.md`, then REMOVE it. Two facts that have each cost an hour:
## a synthetic `InputEventAction` must be fed through `Input.parse_input_event`, and a `Button`
## acts on RELEASE by default, so a press alone never fires one.
##
## THE PROBE THAT HAS TO PHOTOGRAPH ITS RESULT IS NEXT DOOR, in dev_scenario_shots.gd, and three
## closed rows named THIS file before that one existed. The line between them is what the probe
## produces: a measurement printed to the log belongs here, and a moment that has to be
## PHOTOGRAPHED — a 0.6-second screen shake, a world that came back off disk — belongs there,
## because it needs a shutter timed to an event rather than to a frame number and this file owns
## no shutter at all. See T5.12.
##
## OWNS: scripted scenarios and the measurements they print.
## MUST NOT: be depended upon by gameplay, or reimplement anything it verifies. A debug path
## that reimplements the thing it is checking checks nothing — every probe here goes through
## the same signals and methods the game uses. Deleting this file must not break the game.

const NPC_SCENE: String = "res://scenes/characters/npc.tscn"
## Save slot used by --cross-area-save. High, so it cannot collide with a real playthrough.
const PROBE_SLOT: int = 5
## Frames to let an NPC walk before reporting. The clock is frozen during a probe, so this is
## real frames, not game time.
const WALK_FRAMES: int = 260

func _ready() -> void:
	# A probe has to keep running while the game is paused: half of what they verify is what
	# happens with a screen open. Pause table: src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE DEBUG SURFACE DOES NOT EXIST IN A SHIPPED BUILD. Same guard, same reason, as
	# dev_capture.gd: until T1.2 a release export still answered these flags.
	if not OS.is_debug_build():
		return
	_parse_arguments()


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--round-trips="):
			_round_trips(maxi(1, argument.trim_prefix("--round-trips=").to_int()))
		elif argument == "--cross-area-save":
			_cross_area_save()
		elif argument == "--npc-day":
			_npc_day()
		elif argument.begins_with("--npc-storm="):
			_npc_storm(maxi(1, argument.trim_prefix("--npc-storm=").to_int()))
		elif argument.begins_with("--save-state="):
			_save_state(argument.trim_prefix("--save-state="))
		elif argument.begins_with("--load-state="):
			_load_state(argument.trim_prefix("--load-state="))


func _round_trips(count: int) -> void:
	# Wait for the FIRST area, not merely for the tree to settle. Arguments are read in _ready,
	# before GameRoot has even requested the boot transition, so is_transitioning() is still
	# false here — settling on it alone reads an empty home and sends every return trip to "".
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	var home: StringName = Director.current_area_id
	var nodes_before: int = _node_count()
	var memory_before: int = _static_memory()
	Log.info("test", "--round-trips %d from '%s': %d nodes, %d KiB" % [
		count, home, nodes_before, memory_before / 1024,
	])

	for trip: int in count:
		await _travel(&"lantern_hall", &"from_courtyard")
		await _travel(home, &"north_arch")
		Log.info("test", "  trip %d/%d: %d nodes, %d KiB" % [
			trip + 1, count, _node_count(), _static_memory() / 1024,
		])

	var nodes_after: int = _node_count()
	var memory_after: int = _static_memory()
	Log.info("test", "--round-trips done: nodes %d -> %d (%+d), memory %d -> %d KiB (%+d)" % [
		nodes_before, nodes_after, nodes_after - nodes_before,
		memory_before / 1024, memory_after / 1024, (memory_after - memory_before) / 1024,
	])


func _travel(area_id: StringName, spawn_id: StringName) -> void:
	Events.area_change_requested.emit(area_id, spawn_id)
	# A SECOND request in the same frame, which the guard must refuse. Asserted here rather
	# than in the suite because only a live transition can be interrupted.
	Events.area_change_requested.emit(area_id, spawn_id)
	await _settled()


## Wait for the transition to end, then let the freed area actually leave the tree —
## queue_free() takes effect at the end of a frame, so sampling immediately after arrival
## counts the old area as still present and reports a leak that is not there.
func _settled() -> void:
	while Director.is_transitioning():
		await get_tree().process_frame
	for _i: int in 4:
		await get_tree().process_frame


func _node_count() -> int:
	return DictRead.to_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) as int


func _static_memory() -> int:
	return DictRead.to_float(Performance.get_monitor(Performance.MEMORY_STATIC)) as int


## The criterion no assertion can reach: state in an area that is no longer loaded.
##
## Empty the hall's coffer, come back, take the courtyard's key, save, reload, and go and look
## at the coffer again. Per-object persistence is already covered by the suite, but only

func _cross_area_save() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	await _travel(&"lantern_hall", &"from_courtyard")
	Log.info("test", "--cross-area-save hall coffer emptied: %s" % str(_empty_the_coffer()))
	var bag: Inventory = Inventory.of(Director.player)
	bag.add(&"item/rose_key", 1)
	# Saved IN THE HALL and reloaded from the courtyard, deliberately. A save taken where the
	# reload already is cannot tell "the area was restored" from "the area never changed" —
	# which is exactly how a broken DictRead.get_name hid in Director for three packages.
	Log.info("test", "--cross-area-save saved in '%s': %s" % [
		Director.current_area_id, error_string(SaveSystem.save_to_slot(PROBE_SLOT)),
	])
	await _travel(&"courtyard", &"north_arch")

	# Wipe what a fresh session would not have, so a survival that is really just a value
	# nobody cleared cannot pass for a value that was restored.
	bag.clear_all()
	Flags.set_flag(&"obj/lantern_hall/hall_chest/emptied", false)
	Log.info("test", "--cross-area-save wiped: carrying %d, coffer emptied=%s" % [
		bag.total_count(), str(Flags.get_bool(&"obj/lantern_hall/hall_chest/emptied")),
	])

	Log.info("test", "--cross-area-save loaded: %s" % error_string(SaveSystem.load_from_slot(PROBE_SLOT)))
	await _settled()
	Log.info("test", "--cross-area-save after reload: area='%s', carrying %d" % [
		Director.current_area_id, Inventory.of(Director.player).total_count(),
	])
	await _travel(&"lantern_hall", &"from_courtyard")
	Log.info("test", "--cross-area-save coffer still empty: %s" % str(_coffer_is_empty()))
	SaveSystem.delete_slot(PROBE_SLOT)


func _empty_the_coffer() -> bool:
	var coffer: ItemContainer = _coffer()
	return coffer != null and coffer.attempt(Director.player)


func _coffer_is_empty() -> bool:
	var coffer: ItemContainer = _coffer()
	return coffer != null and coffer.is_emptied()


func _coffer() -> ItemContainer:
	var tree: SceneTree = get_tree()
	var found: Node = tree.root.find_child("HallChest", true, false)
	if found == null:
		Log.error("test", "--cross-area-save found no HallChest in the tree")
	return found as ItemContainer


## Travel somewhere for a capture. Waits for the boot load first: a request made before the
## first area exists is refused by the guard, which would look like the flag not working.
func _npc_day() -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	Clock.paused = true
	for hour: int in [6, 9, 12, 15, 20, 23, 2]:
		Clock.set_time(Clock.day, hour, 0)
		for _i: int in WALK_FRAMES:
			await get_tree().physics_frame
		for npc: Node in _all_npcs():
			var brain: NpcBrain = npc as NpcBrain
			Log.info("test", "  %02d:00  %-8s wants %-10s %-8s %.2fm away  %s" % [
				hour, npc.name, brain.current_waypoint(), brain.activity_name(),
				_distance_to_intent(brain),
				"travelling" if brain.is_travelling() else "arrived",
			])


## How far the NPC actually is from the waypoint it INTENDS to be at, measured from its position
## rather than taken from its intention. Reporting the intention alone would say "at the bench"
## of an NPC stuck in a wall on the other side of the courtyard.
##
## A DISTANCE, not a nearest-waypoint name: a wandering NPC is legitimately up to wander_radius
## from its post, and a name-with-a-threshold reports that correct behaviour as "nowhere".
func _distance_to_intent(brain: NpcBrain) -> float:
	var markers: Node = _waypoints_node()
	if markers == null:
		return -1.0
	var marker: Node3D = markers.get_node_or_null(
		NodePath(String(brain.current_waypoint()))) as Node3D
	if marker == null:
		return -1.0
	return marker.global_position.distance_to(brain.global_position)


func _waypoints_node() -> Node:
	var area: Node = get_tree().root.find_child("Waypoints", true, false)
	return area


func _all_npcs() -> Array[Node]:
	var out: Array[Node] = []
	var actors: Node = get_tree().root.find_child("Actors", true, false)
	if actors == null:
		return out
	for child: Node in actors.get_children():
		if child is NpcBrain:
			out.append(child)
	return out


## Spawn a crowd and measure. The criterion is that thirty NPCs do not MEASURABLY cost frame
## time, so both numbers are reported and the comparison is left visible rather than asserted
## against a threshold that would be meaningless on another machine.
func _npc_storm(count: int) -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	Clock.paused = true
	var before: float = await _average_frame_ms()
	var actors: Node = get_tree().root.find_child("Actors", true, false)
	var packed: PackedScene = load(NPC_SCENE)
	var spawned: Array[Node] = []
	for index: int in count:
		var npc: NpcBrain = packed.instantiate() as NpcBrain
		npc.name = "Storm%d" % index
		npc.schedule_id = &"schedule/keeper"
		# Configure BEFORE add_child. PersistentState reads object_id in _enter_tree, and the Talk
		# component refuses at _ready, so anything set afterwards is too late and the console fills
		# with sixty errors that are the probe's fault rather than the game's.
		_dress_storm_npc(npc, index)
		actors.add_child(npc)
		npc.global_position = Vector3(-8.0 + float(index % 8) * 2.0, 0.2, 1.0 + float(index / 8) * 2.0)
		spawned.append(npc)
	for _i: int in 120:
		await get_tree().physics_frame
	var after: float = await _average_frame_ms()
	Log.info("test", "--npc-storm %d: %.3f ms/frame with 1 NPC, %.3f with %d (+%.3f)" % [
		count, before, after, count + 1, after - before,
	])
	for npc: Node in spawned:
		npc.queue_free()


func _average_frame_ms() -> float:
	var samples: int = 180
	var started: int = Time.get_ticks_usec()
	for _i: int in samples:
		await get_tree().physics_frame
	return float(Time.get_ticks_usec() - started) / float(samples) / 1000.0


## Give a crowd NPC an id of its own and no conversation. Thirty copies of one scene otherwise
## share one blank object_id and one unconfigured Speaker, and each complains once at load.
func _dress_storm_npc(npc: Node, index: int) -> void:
	var store: PersistentState = npc.get_node_or_null(^"PersistentState") as PersistentState
	if store != null:
		store.object_id = StringName("storm_%d" % index)
	# A crowd member has nothing to say. Removing the component is more honest than leaving it
	# to log a refusal every time someone walks past.
	var talk: Node = npc.get_node_or_null(^"Talk")
	if talk != null:
		npc.remove_child(talk)
		talk.queue_free()


## Give the NPCs time to reach their posts before the shutter opens. A capture taken on the
## default frame catches them mid-stride between the spawn point and wherever the clock says
## they belong, which photographs the transition rather than the schedule.


## PHASE 1'S SAVE CRITERION NEEDS TWO PROCESSES, WHICH IS WHY IT IS A PAIR AND NOT A PROBE.
## `--cross-area-save` already reloads IN PROCESS, and that cannot tell a value that was written
## to disk and read back from one that was simply never cleared - the whole point of "quit and
## relaunch" is that nothing is left in memory to be right by accident. So: run once with
## `--save-state=<slot>`, which poses a state that is nothing like a fresh game and saves it,
## then run AGAIN with `--load-state=<slot>` and compare the two reports line for line.
func _save_state(slot_text: String) -> void:
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	# Somewhere a new game is not, carrying something a new game does not, at a time it is not.
	await _travel(&"lantern_hall", &"from_courtyard")
	Inventory.of(Director.player).add(&"item/rose_key", 1)
	Clock.set_time(3, 21, 45)
	# STORM, not CLEAR. Weather's default IS CLEAR, so saving a clear day and reading a clear
	# day back proves nothing at all - the control has to differ from the boot value.
	Weather.force(GameEnums.WeatherKind.STORM)
	Log.info("test", "--save-state %s" % DevCommands.save_to(slot_text))
	Log.info("test", "--save-state before: %s" % _state_report())


## The other half, run in a FRESH process. Boots to the main menu with no area loaded, so the
## report afterwards cannot be describing anything this session set up.
func _load_state(slot_text: String) -> void:
	await _settled()
	Log.info("test", "--load-state at boot: %s" % _state_report())
	Log.info("test", "--load-state %s" % DevCommands.load_from(slot_text))
	await _settled()
	while Director.current_area_id == &"":
		await get_tree().process_frame
	await _settled()
	Log.info("test", "--load-state after: %s" % _state_report())
	# The pair owns the slot it used, the way `--cross-area-save` owns PROBE_SLOT: a probe
	# that leaves a save behind turns the next `Continue` into somebody else's session.
	var slot: int = slot_text.strip_edges().to_int()
	if SaveSystem.has_slot(slot):
		Log.info("test", "--load-state cleaned slot %d: %s" % [
			slot, error_string(SaveSystem.delete_slot(slot)),
		])


## Everything the criterion names - position, time, weather and inventory - plus the area, since
## a restored position in the wrong area is not a restored position.
func _state_report() -> String:
	var body: PlayerController = Director.player
	var place: String = "none" if body == null else "%.2f,%.2f" % [
		body.global_position.x, body.global_position.z,
	]
	var carried: int = 0 if body == null or Inventory.of(body) == null else Inventory.of(body).total_count()
	return "area='%s' at=%s day=%d time=%02d:%02d weather=%d carrying=%d" % [
		Director.current_area_id, place, Clock.day, Clock.hour, Clock.minute,
		int(Weather.current()), carried,
	]
