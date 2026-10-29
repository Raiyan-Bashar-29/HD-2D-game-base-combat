extends TestCase
## The world map: where a place sits, how it becomes known, and the one ask that travels.
##
## WHAT IS DELIBERATELY NOT HERE: the travel itself. `TestCase.run()` is synchronous and a
## threaded load needs frames, so what is asserted is `WorldMap.travel_to`'s SEAM — that it emits
## exactly the request an `AreaDoor` emits, naming the area and the authored arrival spawn, and
## does nothing else at all. Driving a transition is a RUN, not an assertion, for the reason
## `transitions_test.gd` gives at length. Pressing `M` is a windowed probe, gotcha 15.
##
## DISCOVERY IS ASSERTED AS A FLAG, WHICH IS THE PACKAGE. There is no save section to test,
## because there is no store: `map/<area id>` goes through `Flags`, so the reload block below
## asserts that a flag coming back through `SaveSystem` makes the map report the place known
## again. That is a smaller claim than "the discovery system persists" and it is the true one.
##
## AREAS ARE DISCOVERED, NOT LISTED, in the demo block at the foot — `Fixtures.area_ids()` scans
## `scenes/areas/`, so the contract covers area three the day it appears and covers nothing at
## all in a stripped template, reported as a skip rather than as a pass. Every other block runs
## on `FixtureContent.area_defs()`, which has no scenes behind it on purpose: the map is provable
## in a checkout with no game in it.
##
## OWNS: assertions about `AreaDef`, `AreaDb` and `WorldMap`, and about the authored map agreeing
## with the authored areas.
## MUST NOT: drive a transition, assert what the map LOOKS like, or name demo content.

const SLOT: int = 4
const PLACE_A: StringName = FixtureContent.PLACE_A
const PLACE_B: StringName = FixtureContent.PLACE_B
const UNMAPPED: StringName = &"fixture_nowhere"

const FIXED_ASSERTIONS: int = 48
const PER_AREA: int = 4
const PER_DEF: int = 1

var _map: WorldMap = null
var _requests: Array[Array] = []
var _discoveries: Array[StringName] = []
var _toasts: int = 0
## Gathered BEFORE the fixtures redirect `AreaDb`, because after that the registry is looking at
## a temp folder and the demo is invisible to it.
var _areas: Array[StringName] = []
var _demo_defs: Array[StringName] = []


func run() -> void:
	_areas = Fixtures.area_ids()
	_demo_defs = AreaDb.ids()
	plan(FIXED_ASSERTIONS + 1 + PER_AREA * _areas.size() + PER_DEF * _demo_defs.size())
	# This case writes or deletes slots; redirected so they are not the developer's own. The
	# runner deactivates after every case.
	SaveFixture.activate()
	Fixtures.activate()
	Flags.clear_all()
	SaveSystem.unregister(&"world")
	_listen()
	_map = WorldMap.new()
	attach(_map)

	_the_key_is_a_flag_namespace()
	_a_def_reports_its_own_problems()
	_the_registry_finds_defs_by_id()
	_discovery_is_a_flag_and_nothing_else()
	_anything_that_writes_the_flag_reveals_a_place()
	_a_new_game_puts_the_known_places_on_the_map()
	_arriving_discovers_and_announces()
	_an_unmapped_area_never_reaches_the_map()
	_travel_asks_and_nothing_more()
	_travel_refuses_and_says_so()
	_discovery_survives_a_save_and_a_reload()
	_tear_down()
	_the_authored_map_agrees_with_the_authored_areas()


## The shape an AUTHOR writes into a dialogue effect or a gate's `requires_flag`. Asserted
## because it is a published identifier the moment anything outside this file uses it.
func _the_key_is_a_flag_namespace() -> void:
	equal("a key is the prefix and the id", WorldMap.key(PLACE_A),
		StringName(WorldMap.PREFIX + PLACE_A))
	equal("it lives under the map namespace",
		String(WorldMap.key(PLACE_B)).begins_with(WorldMap.PREFIX), true)
	equal("two places do not share a key", WorldMap.key(PLACE_A) != WorldMap.key(PLACE_B), true)


## The same treatment every other content resource gets: problems are DATA, so the game, the
## suite and the headless validator all read the identical answer.
func _a_def_reports_its_own_problems() -> void:
	var good: AreaDef = FixtureContent.area_def(PLACE_A, Vector2(0.5, 0.5), false, &"")
	equal("a complete def has nothing wrong with it", good.problems().size(), 0)
	equal("the corner of the plate is a legal place to be",
		FixtureContent.area_def(PLACE_A, Vector2.ZERO, false, &"").problems().size(), 0)
	var nameless: AreaDef = FixtureContent.area_def(PLACE_A, Vector2(0.5, 0.5), false, &"")
	nameless.name_key = ""
	equal("a def with no name_key is a problem", nameless.problems().size(), 1)
	var anonymous: AreaDef = FixtureContent.area_def(&"", Vector2(0.5, 0.5), false, &"")
	equal("so is one with no id", anonymous.problems().size(), 1)
	equal("and so is a dot off the plate",
		FixtureContent.area_def(PLACE_A, Vector2(1.4, 0.5), false, &"").problems().size(), 1)


## The fifth directory-scan registry, proved the way the other four are: out through
## `ResourceSaver` in the fixtures and back through the registry's own scan.
func _the_registry_finds_defs_by_id() -> void:
	equal("every fixture def was found", AreaDb.count(), FixtureContent.area_defs().size())
	equal("by id", AreaDb.has(PLACE_A), true)
	equal("carrying its authored position", AreaDb.area(PLACE_B).map_position, Vector2(0.75, 0.5))
	equal("an area nobody mapped is not there", AreaDb.has(UNMAPPED), false)
	equal("and asking for it yields null, not a crash", AreaDb.area(UNMAPPED), null)
	# Through String, never Array[StringName].sort() — gotcha 33.
	equal("ids come back in a stable alphabetical order", ",".join(AreaDb.ids()),
		"%s,%s" % [PLACE_A, PLACE_B])


## THE HEADLINE OF THE DESIGN. There is no store, so everything below is a statement about
## `Flags` — which is exactly why none of it needed a save section, a version or a migration.
func _discovery_is_a_flag_and_nothing_else() -> void:
	equal("nothing is known before anything happens", _map.is_discovered(PLACE_B), false)
	equal("discovering it changes something", _map.discover(PLACE_B), true)
	equal("it is known now", _map.is_discovered(PLACE_B), true)
	equal("and the whole of that is one flag", Flags.get_bool(WorldMap.key(PLACE_B)), true)
	equal("discovering it twice changes nothing", _map.discover(PLACE_B), false)
	equal("one place is on the map", ",".join(_map.discovered_ids()), String(PLACE_B))


## THE SEAM, and the reason this is a flag rather than a store: a conversation effect, a trigger
## volume or a lever writes the key and a place appears on the map, with no code in any of them
## and none in this file either. Written here the way a `DialogueNode` effect writes it.
func _anything_that_writes_the_flag_reveals_a_place() -> void:
	Flags.set_flag(WorldMap.key(PLACE_A), true)
	equal("a place revealed by hearsay is on the map", _map.is_discovered(PLACE_A), true)
	equal("both places now, in order", ",".join(_map.discovered_ids()),
		"%s,%s" % [PLACE_A, PLACE_B])
	equal("and WorldMap never had to be told", _map.discover(PLACE_A), false)


## A new game clears every flag, so what is on the map at that point is exactly what a def says
## is known from the start — and no toast, because the player has not found anything yet.
func _a_new_game_puts_the_known_places_on_the_map() -> void:
	Flags.clear_all()
	_toasts = 0
	Events.game_started.emit()
	equal("somewhere known from the start is on the map", _map.is_discovered(PLACE_A), true)
	equal("somewhere else is not", _map.is_discovered(PLACE_B), false)
	equal("only the one place", _map.discovered_ids().size(), 1)
	equal("and nothing was announced", _toasts, 0)


## Arriving is the ordinary way to find somewhere, and it is one signal. Emitted directly
## because a real transition needs frames this case does not have.
func _arriving_discovers_and_announces() -> void:
	_toasts = 0
	_discoveries.clear()
	Events.area_entered.emit(PLACE_B)
	equal("arriving put it on the map", _map.is_discovered(PLACE_B), true)
	equal("exactly one discovery was announced", _discoveries.size(), 1)
	equal("naming the place", _discoveries[0], PLACE_B)
	equal("and the player was told once", _toasts, 1)


## An area with no def is a side room a game chose not to draw, not an error. It must not become
## a flag, or a save would carry keys for places that can never be shown.
func _an_unmapped_area_never_reaches_the_map() -> void:
	_discoveries.clear()
	Events.area_entered.emit(UNMAPPED)
	equal("an unmapped area is not discovered", _map.is_discovered(UNMAPPED), false)
	equal("and nothing was announced", _discoveries.size(), 0)


## THE POINT OF THE PACKAGE, and the same assertion `transitions_test` makes about a door: fast
## travel ASKS and does nothing else. If it ever grows a second path to a transition, the guard
## that stops two of them firing at once stops being the only one.
func _travel_asks_and_nothing_more() -> void:
	_requests.clear()
	equal("travelling to a known place is allowed", _map.travel_to(PLACE_A), true)
	equal("exactly one request was made", _requests.size(), 1)
	equal("naming the area", _requests[0][0], PLACE_A)
	equal("and the spawn its own .tres authored", _requests[0][1], FixtureContent.PLACE_A_SPAWN)
	equal("the map did not move the player", Director.player, null)
	equal("and did not load anything", Director.current_area_id, &"")


## Three refusals, and each is a refusal rather than a silent no-op. `current_area_id` is set by
## hand here — reaching into Director rather than driving a transition, which this case cannot do
## — and put back, because every later case reads it.
func _travel_refuses_and_says_so() -> void:
	_requests.clear()
	Flags.erase_flag(WorldMap.key(PLACE_B))
	equal("somewhere never found is refused", _map.travel_to(PLACE_B), false)
	equal("somewhere not on the map at all is refused", _map.travel_to(UNMAPPED), false)
	Director.current_area_id = PLACE_A
	equal("and so is the place you are standing in", _map.travel_to(PLACE_A), false)
	Director.current_area_id = &""
	equal("no request escaped any of them", _requests.size(), 0)


## NOT A SAVE-SECTION TEST — there is no save section. What is asserted is that a flag coming
## back through `Flags` makes the map report the place known again, which is the whole of what
## "discovery persists across a save and a reload" means here.
func _discovery_survives_a_save_and_a_reload() -> void:
	equal("discover it before saving", _map.discover(PLACE_B), true)
	equal("save", SaveSystem.save_to_slot(SLOT), OK)
	Flags.clear_all()
	equal("scrambled", _map.is_discovered(PLACE_B), false)
	equal("load", SaveSystem.load_from_slot(SLOT), OK)
	equal("it is on the map again", ",".join(_map.discovered_ids()),
		"%s,%s" % [PLACE_A, PLACE_B])


## Every area a game has authored is on its map, its two names agree, and the spawn a fast
## traveller lands on really exists. None of that is checked anywhere else: `check_content`
## cannot resolve an area id to a scene without `Director`, which is an autoload it has no
## access to under `--script`.
func _the_authored_map_agrees_with_the_authored_areas() -> void:
	if _areas.is_empty():
		skip("the authored map agrees with the authored areas", "no areas in scenes/areas", 1)
		return
	equal("every authored area is on the map", _demo_defs.size(), _areas.size())
	for area_id: StringName in _areas:
		_area_matches_its_def(area_id)
	for area_id: StringName in _demo_defs:
		equal("%s is on the map and has a scene" % area_id, Director.area_exists(area_id), true)


## Instantiated WITHOUT entering the tree, exactly as transitions_test does: _ready would start
## audio, force weather and bake a navmesh, none of which this file is asserting.
func _area_matches_its_def(area_id: StringName) -> void:
	var packed: PackedScene = load(Director.area_path(area_id)) as PackedScene
	var area: AreaRoot = null
	if packed != null:
		area = packed.instantiate() as AreaRoot
	equal("%s root is an AreaRoot" % area_id, area != null, true)
	var def: AreaDef = AreaDb.area(area_id)
	equal("%s has an AreaDef" % area_id, def != null, true)
	if area == null or def == null:
		equal("%s name keys agree" % area_id, false, true)
		equal("%s arrival spawn exists" % area_id, false, true)
		return
	equal("%s name keys agree" % area_id, def.name_key, area.display_name_key)
	var spawns: Node = area.get_node_or_null(^"Spawns")
	equal("%s arrival spawn exists" % area_id,
		spawns != null and spawns.get_node_or_null(NodePath(String(def.arrival_spawn))) != null,
		true)
	area.free()


func _listen() -> void:
	Events.area_change_requested.connect(_on_change_requested)
	Events.area_discovered.connect(_on_discovered)
	Events.notify_requested.connect(_on_notified)


## The registries go back to the game's own content here rather than in the runner, because the
## demo block below has to ask `AreaDb` about the real `data/areas`.
func _tear_down() -> void:
	Events.area_change_requested.disconnect(_on_change_requested)
	Events.area_discovered.disconnect(_on_discovered)
	Events.notify_requested.disconnect(_on_notified)
	SaveSystem.delete_slot(SLOT)
	Flags.clear_all()
	_map.queue_free()
	_map = null
	Fixtures.deactivate()


func _on_change_requested(area_id: StringName, spawn_id: StringName) -> void:
	_requests.append([area_id, spawn_id])


func _on_discovered(area_id: StringName) -> void:
	_discoveries.append(area_id)


func _on_notified(_key: String, _seconds: float, _args: Dictionary) -> void:
	_toasts += 1
