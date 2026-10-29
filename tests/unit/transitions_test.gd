extends TestCase
## Areas, the door between them, and the shape every area scene has to have.
##
## WHAT IS DELIBERATELY NOT HERE: the transition itself. `TestCase.run()` is synchronous and a
## threaded load needs frames, so twenty round trips are a RUN — `--round-trips=20` in
## `dev_capture.gd` — and not an assertion. What IS here is everything decidable without a
## frame: the door's contract, the guard's inputs, and the structural contract that makes
## `Director` free of per-area special cases.
##
## THE STRUCTURAL CASE EARNS ITS KEEP. `area_root.gd`'s header lists ten required children
## and, until this file, nothing checked them. A missing `Spawns` node means the player lands
## at the origin with one warning in a log nobody reads; a missing `Interactables` means an
## area that silently contains nothing to do.
##
## AREAS ARE DISCOVERED, NOT LISTED. The contract holds for whatever areas a game has authored,
## so scanning `scenes/areas/` covers area three the day it appears and covers nothing at all in
## a stripped template — which is correct, and reported as a skip rather than as a pass. The
## door blocks name abstract ids and need no content whatsoever.
##
## OWNS: assertions about area scenes, `AreaDoor`, and area id/path resolution.
## MUST NOT: drive a transition, or assert anything about lighting.

const REQUIRED_CHILDREN: Array[String] = [
	"Environment", "Terrain", "Props", "Interactables", "Actors", "Spawns", "Triggers", "Camera",
	"Navigation", "Waypoints",
]
const PER_AREA_ASSERTIONS: int = 20
const FIXED_ASSERTIONS: int = 17
const SKIPS_WITHOUT_AREAS: int = 3
const TARGET_AREA: StringName = &"fixture_destination"
const TARGET_SPAWN: StringName = &"fixture_arrival"

var _areas: Array[StringName] = []
var _requests: Array[Array] = []


func run() -> void:
	_areas = Fixtures.area_ids()
	# Three blocks need authored areas and skip together when there are none, so the plan is one
	# number either way and a stripped run reports exactly what it gave up.
	var with_areas: int = PER_AREA_ASSERTIONS * _areas.size() + 1
	plan(FIXED_ASSERTIONS + (SKIPS_WITHOUT_AREAS if _areas.is_empty() else with_areas))
	_ids_resolve_to_paths()
	_every_area_has_the_required_shape()
	_an_interior_does_not_follow_the_sun()
	_the_door_asks_and_nothing_more()
	_a_door_with_no_destination_refuses()
	_flag_prefixes_do_not_collide()
	_the_saved_area_id_survives_dict_read()


## The path template is the one place an area id becomes a file, so a typo here is a door onto
## nothing. Both directions are asserted: every real id resolves, an invented one does not.
func _ids_resolve_to_paths() -> void:
	for area_id: StringName in _areas:
		var path: String = Director.area_path(area_id)
		equal("%s resolves to its own folder" % area_id, path,
			"res://scenes/areas/%s/%s.tscn" % [area_id, area_id])
		equal("and the scene is really there", Director.area_exists(area_id), true)
	equal("an invented area does not exist", Director.area_exists(&"no_such_place"), false)
	equal("and neither does the empty id", Director.area_exists(&""), false)


## The contract in area_root.gd's header, asserted rather than merely documented. Every area
## has the same shape, which is what lets Director carry no per-area special case at all.
func _every_area_has_the_required_shape() -> void:
	if _areas.is_empty():
		skip("every area has the required shape", "no areas in scenes/areas", 1)
		return
	for area_id: StringName in _areas:
		var area: AreaRoot = _load_area(area_id)
		if area == null:
			continue
		equal("%s declares its own id" % area_id, area.area_id, area_id)
		equal("%s has a display name key" % area_id, area.display_name_key != "", true)
		for child_name: String in REQUIRED_CHILDREN:
			equal("%s has %s" % [area_id, child_name],
				area.get_node_or_null(NodePath(child_name)) != null, true)
		var spawns: Node = area.get_node_or_null(^"Spawns")
		equal("%s offers somewhere to arrive" % area_id, spawns.get_child_count() > 0, true)
		area.free()


## An interior must not be lit by the outdoor sun, and an outdoor area must be. Asserted on the
## scenes as authored, because this is exactly the kind of thing a stray editor click flips back
## and nobody notices until a capture looks wrong at midnight. Which areas are sheltered is a
## GAME's decision, so this asks the areas themselves rather than naming one.
func _an_interior_does_not_follow_the_sun() -> void:
	if _areas.is_empty():
		skip("sheltering and the clock agree", "no areas in scenes/areas", 1)
		return
	var mismatched: PackedStringArray = PackedStringArray()
	for area_id: StringName in _areas:
		var area: AreaRoot = _load_area(area_id)
		if area == null:
			continue
		var driver: EnvironmentDriver = area.get_node_or_null(
			^"Environment/EnvironmentDriver") as EnvironmentDriver
		if driver == null:
			mismatched.append("%s has no EnvironmentDriver" % area_id)
		elif driver.follow_clock == area.sheltered:
			mismatched.append("%s is sheltered=%s but follow_clock=%s" % [
				area_id, area.sheltered, driver.follow_clock,
			])
		area.free()
	equal("every area's sheltering matches its driver: %s" % str(mismatched),
		mismatched.size(), 0)


## THE HEADLINE. A door emits a request and does nothing else — no loading, no fading, no
## moving the player. If it ever grows a second path to a transition, the guard that stops two
## doors firing at once stops being the only one.
func _the_door_asks_and_nothing_more() -> void:
	Events.area_change_requested.connect(_on_change_requested)
	var door := AreaDoor.new()
	door.target_area = TARGET_AREA
	door.target_spawn = TARGET_SPAWN
	door.label_key = "fixture.door.label"
	attach(door)

	equal("the door offers ENTER", door.verb, GameEnums.InteractVerb.ENTER)
	equal("and refuses nothing while idle", door.refusal(null), GameEnums.RefusalReason.NONE)
	equal("the interaction succeeds", door.attempt(null), true)
	equal("exactly one request was made", _requests.size(), 1)
	equal("naming the area", _requests[0][0], TARGET_AREA)
	equal("and the spawn", _requests[0][1], TARGET_SPAWN)
	equal("the door did not move the player", Director.player, null)
	equal("and did not load anything", Director.current_area_id, &"")

	Events.area_change_requested.disconnect(_on_change_requested)
	door.queue_free()
	_requests.clear()


## A door onto nothing must REFUSE, with a reason, rather than emitting a request Director
## would only reject a moment later. The refusal is the message; silence would read as a wall.
func _a_door_with_no_destination_refuses() -> void:
	Events.area_change_requested.connect(_on_change_requested)
	var door := AreaDoor.new()
	door.label_key = "fixture.door.label"
	attach(door)
	equal("it refuses", door.refusal(null), GameEnums.RefusalReason.STORY_GATED)
	equal("so the attempt fails", door.attempt(null), false)
	equal("and nothing was requested", _requests.size(), 0)
	Events.area_change_requested.disconnect(_on_change_requested)
	door.queue_free()
	_requests.clear()


## Two areas sharing a flag namespace means one area's world state quietly overwrites the
## other's. Cheap to assert now, extremely expensive to discover at area fifteen.
func _flag_prefixes_do_not_collide() -> void:
	if _areas.is_empty():
		skip("flag prefixes do not collide", "no areas in scenes/areas", 1)
		return
	var seen: Dictionary[StringName, bool] = {}
	for area_id: StringName in _areas:
		var area: AreaRoot = _load_area(area_id)
		if area == null:
			continue
		var key: StringName = area.flag_key("probe")
		equal("%s namespaces its flags" % area_id, String(key).ends_with("/probe"), true)
		equal("and does so uniquely", seen.has(key), false)
		seen[key] = true
		area.free()


## Instantiated WITHOUT entering the tree: _ready would start audio, force weather and log an
## area as entered, none of which this file is asserting and all of which would leak into the
## next case.
func _load_area(area_id: StringName) -> AreaRoot:
	var packed: PackedScene = load(Director.area_path(area_id)) as PackedScene
	if packed == null:
		equal("area scene loads: %s" % area_id, false, true)
		return null
	var area: AreaRoot = packed.instantiate() as AreaRoot
	equal("%s root is an AreaRoot" % area_id, area != null, true)
	return area


func _on_change_requested(area_id: StringName, spawn_id: StringName) -> void:
	_requests.append([area_id, spawn_id])


## The bug WP-04 found, kept from coming back. `DictRead.get_name` COMPILED and then dispatched
## at runtime to `Resource.get_name()` — a GDScript is a Resource — so `Director` could never
## read the saved area id and a save made elsewhere silently reloaded you where you already
## were. Only a second area could expose it. Asserted here rather than in core_test because
## the value under test is the one Director reads.
func _the_saved_area_id_survives_dict_read() -> void:
	var section: Dictionary = {"area": "somewhere"}
	equal("a saved area id reads back", DictRead.get_string_name(section, "area", &""),
		&"somewhere")
	equal("and is a StringName, not a String",
		DictRead.get_string_name(section, "area", &"") is StringName, true)
	equal("a missing key falls back", DictRead.get_string_name({}, "area", &"fallback"),
		&"fallback")
	# The whole failure was a name colliding with a native member, so the guard is that this
	# call reaches OUR function at all. A native get_name() takes no arguments and throws.
	equal("the call reaches DictRead, not Resource",
		DictRead.get_string_name({"area": "x"}, "area", &"") != &"", true)
