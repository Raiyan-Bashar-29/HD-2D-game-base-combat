extends Node
## Area loading and transitions. Autoload `Director`.
##
## WHY IT EXISTS
## Changing area is the single most failure-prone operation in an exploration game: it has to
## unload a live scene, load another off the main thread, place the player on the right spot,
## restore world state, and hide all of it behind a fade. Done ad hoc from a door script it
## goes wrong in a dozen ways, the worst being two doors firing at once and leaving two areas
## in the tree. One owner, one guarded path.
##
## OWNS: which area is loaded, the transition sequence, the world root, and the reference to
## the current player.
## MUST NOT: know what is inside an area, or contain per-area special cases. If an area needs
## something special on entry, that belongs in the area's own script.
##
## HOW TO TRAVEL, from anywhere:
##     Events.area_change_requested.emit(&"orchard", &"south_gate")
## Nothing calls change_area() directly except this file, so every transition is logged in
## one place and the guard cannot be bypassed.

const AREA_PATH_TEMPLATE: String = "res://scenes/areas/%s/%s.tscn"
## WHERE A NEW GAME BEGINS IS NOT THIS FILE'S BUSINESS. It lived in `game_root.gd` as
## `const FIRST_AREA := &"courtyard"` until WP-12 and then here until T1.2, and both times it
## was engine code naming demo content. It is now a project setting, read through `GameConfig`.
## The menu names an intention, this file knows what areas are, and project.godot knows which
## game this is.
const FADE_OUT: float = 0.35
const FADE_IN: float = 0.45
## Frames the curtain is held after the new area enters the tree, before the fade in. The
## first frame an area is drawn is where its shaders compile, and a compile hitch behind black
## is invisible while the same hitch on the first visible frame is a lurch.
const WARM_UP_FRAMES: int = 3

## The area currently in the tree. Empty before the first load.
var current_area_id: StringName = &""
## The live player node, or null between areas. Set from the player_spawned signal rather
## than by searching the tree, so there is never a stale path to chase.
var player: Node3D = null

var _world_root: Node3D = null
var _current_area: Node3D = null
var _transitioning: bool = false
## Where the transition in flight is headed. Only so the guard can name the destination it is
## busy with; naming the CURRENT area instead reads as "already moving to where I am".
var _pending_area: StringName = &""
## Set when loading a save, so the player lands where they were rather than at a spawn point.
var _position_override: Variant = null
## Same, for facing. Saved since the first commit but never applied until now.
var _yaw_override: Variant = null
## The path of a threaded load in flight, empty when there is none. Read only by _exit_tree(),
## which has to know whether a loader thread is still owed a wait.
var _in_flight: String = ""


func _ready() -> void:
	# A transition already in flight must be allowed to finish. If this paused, a menu opened
	# during a fade would strand the game on a black screen with the load never completing.
	# Part of the pause table in src/ui/root/ui_root.gd.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.area_change_requested.connect(_on_area_change_requested)
	Events.player_spawned.connect(_on_player_spawned)
	Events.player_despawned.connect(_on_player_despawned)
	SaveSystem.register(&"world", _collect_save, _apply_save)


## The persistent node that areas are parented under. The game root calls this once on boot.
func attach_world_root(node: Node3D) -> void:
	_world_root = node
	Log.info("world", "World root attached: %s" % node.name)


func has_world_root() -> bool:
	return _world_root != null and is_instance_valid(_world_root)


func area_path(area_id: StringName) -> String:
	return AREA_PATH_TEMPLATE % [area_id, area_id]


func area_exists(area_id: StringName) -> bool:
	return ResourceLoader.exists(area_path(area_id))


func is_transitioning() -> bool:
	return _transitioning


## Begin a fresh run: no flags, no playtime, first area. The main menu and the dev capture flag
## both call this, so "what a new game is" is written down once. It does NOT load the area
## itself - it asks, through the same guarded signal every door uses, so a new game started
## during a transition in flight is refused with a log line like any other travel.
func start_new_game() -> void:
	# Refused BEFORE anything is cleared. A template with no game in it yet is a real state, and
	# wiping the flags and then failing to load would be worse than not starting at all.
	var first: StringName = GameConfig.first_area()
	if first == &"":
		Log.error("world", "No first area — set %s in project.godot" % GameConfig.FIRST_AREA_SETTING)
		return
	Flags.clear_all()
	SaveSystem.reset_playtime()
	Events.game_started.emit()
	Events.area_change_requested.emit(first, GameConfig.first_spawn())


## Reload the area in place. NO CALLER — the debug tools drive the Director through
## `Events.area_change_requested` like everything else, and no shipped screen offers a reload.
## It stays because it names an occasion rather than duplicating a spelling: it is the only
## caller that has to read `current_area_id` off the Director to know where "here" is.
func reload_current_area() -> void:
	if current_area_id != &"":
		_begin_transition(current_area_id, &"")


func _on_area_change_requested(area_id: StringName, spawn_id: StringName) -> void:
	_begin_transition(area_id, spawn_id)


## The guard. Every rejection is logged, because a silently ignored door is maddening to debug.
func _begin_transition(area_id: StringName, spawn_id: StringName) -> void:
	if _transitioning:
		Log.warn("world", "Ignoring travel to '%s': already moving to '%s'" % [area_id, _pending_area])
		return
	if not has_world_root():
		Log.error("world", "Cannot load '%s': no world root attached" % area_id)
		return
	if not area_exists(area_id):
		Log.error("world", "Area '%s' has no scene at %s" % [area_id, area_path(area_id)])
		# A refused transition must not leave a save's position override armed for the next one.
		_position_override = null
		_yaw_override = null
		return
	_transitioning = true
	_pending_area = area_id
	_run_transition(area_id, spawn_id)


func _run_transition(area_id: StringName, spawn_id: StringName) -> void:
	var from: StringName = current_area_id
	Log.info("world", "Transition %s -> %s (spawn '%s')" % [
		from if from != &"" else &"(none)", area_id, spawn_id,
	])

	if from != &"":
		Events.screen_fade_requested.emit(true, FADE_OUT)
		await get_tree().create_timer(FADE_OUT).timeout
		Events.area_unloading.emit(from)
		_free_current_area()

	var scene: PackedScene = await _load_area_scene(area_id)
	if scene == null:
		_abandon()
		return

	var instance: Node = scene.instantiate()
	var area: Node3D = instance as Node3D
	if area == null:
		Log.error("world", "Area '%s' root is %s, expected Node3D" % [area_id, instance.get_class()])
		instance.free()
		_abandon()
		return

	_current_area = area
	current_area_id = area_id
	_world_root.add_child(area)

	# The area is in the tree and its _ready has run, so its spawn markers exist.
	_place_player(area, spawn_id)
	await _warm_up()

	Events.area_entered.emit(area_id)
	Events.screen_fade_requested.emit(false, FADE_IN)
	_transitioning = false
	_pending_area = &""
	Log.info("world", "Entered '%s'" % area_id)


## Give up on a transition, and LIFT THE CURTAIN on the way out.
##
## Every failure path has to come through here. One of them used to return without the fade,
## which left the screen permanently black with the previous area already freed and
## current_area_id empty, so not even reload_current_area() could recover - the exact failure
## mode game_root.gd was fixed for in the WP-00 audit, reintroduced one layer down.
##
## The overrides are cleared too. A save whose area no longer exists sets them and then fails,
## and they would otherwise survive to the NEXT transition and teleport the player to a
## position authored for a different area.
func _abandon() -> void:
	_transitioning = false
	_pending_area = &""
	_position_override = null
	_yaw_override = null
	Events.screen_fade_requested.emit(false, FADE_IN)


## Draw the new area a few times while the curtain is still opaque, so shader compilation
## happens behind black. There is no API in 4.7 that compiles a scene's materials on demand;
## rendering it is the mechanism, and doing that unseen is the whole trick.
func _warm_up() -> void:
	for _i: int in WARM_UP_FRAMES:
		await get_tree().process_frame


## Threaded load so a large area does not freeze the frame behind the fade.
##
## `_in_flight` is set and cleared HERE and nowhere else, so the invariant reads off one place
## rather than one per exit path: _await_load() may return however it likes and the flag still
## tells _exit_tree() the truth.
func _load_area_scene(area_id: StringName) -> PackedScene:
	var path: String = area_path(area_id)
	var request: Error = ResourceLoader.load_threaded_request(path)
	if request != OK:
		Log.error("world", "Load request for %s failed: %s" % [path, error_string(request)])
		return null
	_in_flight = path
	var scene: PackedScene = await _await_load(area_id, path)
	_in_flight = ""
	return scene


func _await_load(area_id: StringName, path: String) -> PackedScene:
	while true:
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
		if not progress.is_empty():
			Events.area_load_progress.emit(area_id, DictRead.to_float(progress[0]))
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED:
				Log.error("world", "Load of %s failed" % path)
				return null
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				Log.error("world", "%s is not a loadable resource" % path)
				return null
		await get_tree().process_frame
	return null


func _free_current_area() -> void:
	if _current_area != null and is_instance_valid(_current_area):
		_current_area.queue_free()
	_current_area = null
	current_area_id = &""


## Put the player on the named spawn marker. Falls back rather than failing, because being
## dropped at the origin is recoverable and being stuck on a black screen is not.
func _place_player(area: Node3D, spawn_id: StringName) -> void:
	if player == null or not is_instance_valid(player):
		return

	if _position_override is Vector3:
		player.global_position = _position_override
		_position_override = null
		if _yaw_override is float:
			player.global_rotation.y = _yaw_override
		_yaw_override = null
		return

	var marker: Node3D = _find_spawn(area, spawn_id)
	if marker == null:
		Log.warn("world", "No spawn '%s' in '%s' — using area origin" % [spawn_id, area.name])
		player.global_position = area.global_position
		return
	player.global_position = marker.global_position
	player.global_rotation = marker.global_rotation


func _find_spawn(area: Node3D, spawn_id: StringName) -> Node3D:
	var spawns: Node = area.get_node_or_null(^"Spawns")
	if spawns == null:
		return null
	if spawn_id != &"":
		var named: Node = spawns.get_node_or_null(NodePath(String(spawn_id)))
		var as_marker: Node3D = named as Node3D
		if as_marker != null:
			return as_marker
	for child: Node in spawns.get_children():
		var fallback: Node3D = child as Node3D
		if fallback != null:
			return fallback
	return null


func _on_player_spawned(spawned: Node3D) -> void:
	player = spawned


func _on_player_despawned() -> void:
	player = null


func _collect_save() -> Dictionary:
	var data: Dictionary = {"area": String(current_area_id)}
	if player != null and is_instance_valid(player):
		data["player_position"] = DictRead.put_vector3(player.global_position)
		data["player_yaw"] = player.global_rotation.y
	return data


func _apply_save(data: Dictionary, _from_version: int) -> void:
	var area_id: StringName = DictRead.get_string_name(data, "area", &"")
	if area_id == &"":
		Log.warn("world", "Save has no area to return to")
		return
	if data.has("player_position"):
		_position_override = DictRead.get_vector3(data, "player_position")
		_yaw_override = DictRead.get_float(data, "player_yaw", 0.0)
	Events.area_change_requested.emit(area_id, &"")


## WAIT FOR A LOADER THREAD BEFORE THE PROCESS TEARS DOWN.
##
## Quitting while a threaded load is in flight kills the loader thread inside the text parser,
## and the parser then prints `Parse Error` for files that parse perfectly — plus leaked RIDs
## and leaked ObjectDB instances — AFTER the run has already reported `0 warnings, 0 errors`.
## That is gotcha 22 with the polarity REVERSED: not an error the boot rung cannot see, but a
## FALSE error poisoning the `Parse Error` grep over `--headless --import` that rung 2 uses as
## the project's one real compile check. A gate that reports failures which are not there is
## worth as little as one that misses failures which are, and this one lied about the most
## load-bearing check on the ladder — which is why CI's rung 3 had to read only the last line
## of its log instead of the whole thing.
##
## THERE IS NO CANCEL, and that is checked rather than assumed: `--doctool` gives ResourceLoader
## load_threaded_request, load_threaded_get_status and load_threaded_get, and nothing that
## abandons a request. So the only clean end is to WAIT. load_threaded_get() BLOCKS until the
## loader thread finishes — undocumented in the dump, so measured: 118-197ms for the demo's
## larger area, paid once, on the way out.
##
## EXIT_TREE and not a quit handler, measured the same way: on `--headless --quit-after` with a
## load in flight this node receives NOTIFICATION_EXIT_TREE *before* the session's own closing
## log line, NOTIFICATION_PREDELETE after it, and NOTIFICATION_WM_CLOSE_REQUEST never — headless
## has no window whose closing could be requested.
func _exit_tree() -> void:
	if _in_flight == "":
		return
	ResourceLoader.load_threaded_get(_in_flight)
	_in_flight = ""
