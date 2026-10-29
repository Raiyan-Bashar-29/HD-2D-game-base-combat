class_name WorldMap
extends Node
## What the player knows of the world, and the one way anything asks to fast travel.
##
## DISCOVERY IS A FLAG, AND IT OWNS NO STORE. A known area is:
##     map/<area id>          -> true
## which is `PersistentState`'s `obj/<area>/<object>/<field>`, `Standing`'s `standing/<who>` and
## `Equipment`'s `equip/<wearer>/<item>` applied to a FOURTH case. The same three consequences
## fall out, and together they are the whole argument against a discovery store with a save
## section of its own:
##
##   1. IT IS ALREADY SAVED. No `SaveSystem.register`, no save version, no migration — and a
##      new game clears it for free, because `Director.start_new_game()` clears flags. That is
##      what makes "discovery survives a save and a reload, from the far side of an area that
##      is no longer loaded" true without a line of code here: the flag never lived in the area.
##   2. ANYTHING CAN REVEAL AN AREA WITH NO CODE. A `DialogueChoice` effect, a `TriggerVolume`,
##      a `Lever`, a `QuestStep`'s consequence — anything that writes `map/<id>` puts a place on
##      the map, and none of them has heard of this file. A rumour in a conversation and walking
##      through the door are the same mechanism. Equally, a `Gate` may require `map/<id>`.
##   3. IT IS ANNOUNCED ALREADY. `flag_changed` fires, so a quest that tests "have you found the
##      orchard" progresses with no code at all.
##
## The cost is stated rather than hidden: the key contains an area id, so renaming an area's
## folder makes an existing save forget it was found. That is the same price `Equipment` pays
## for an item id, and it is smaller than the alternative, which writes the same id into a save
## section of its own anyway.
##
## `area_discovered` EXISTS FOR A UI, NOT FOR A RULE. Nothing needs it to gate anything, for
## reason 3 above. It is here so a screen can redraw a dot — gotcha 34, which is the rule that a
## UI subscribes to the FACT and never only to its own input.
##
## A NODE, NOT AN AUTOLOAD. Adding an autoload requires an ADR and this would buy nothing: no
## init-order requirement, no interface the boot scene cannot give it. It sits under `GameRoot`
## beside `QuestTracker`, so it outlives every area, and it is found by GROUP the way `UiRoot`
## and `QuestTracker` are, so a tool or a test can run without one.
##
## THE SAVE HEADER'S "WHERE" IS SET HERE, through `SaveSystem.header_provider`. `core` cannot ask
## `Director` where the player is, and `director.gd` is at its line budget; this node already
## reads `Director.current_area_id` and is the one that knows an area's NAME, so both halves of
## the header's shape — the id written, the name key read back — live in one file.
##
## OWNS: the discovery key shape, turning arrival into discovery, the fast-travel ask, and the
## save header's area field.
## MUST NOT: keep a copy of what is discovered, load an area, fade anything, move the player, or
## decide what an area contains.

## The group this node joins, so a screen finds it without a hard path. Same mechanism, and the
## same reason, as `UiRoot.GROUP` and `QuestTracker.GROUP`.
const GROUP: StringName = &"world_map"
const CATEGORY: String = "map"
const PREFIX: String = "map/"

## Engine-owned, so it lives here rather than in any area's .tres: a game that wants different
## wording edits the CSV row, not every area it has authored.
const DISCOVERED_KEY: String = "notify.map.discovered"
## The save header's field. The area ID, not its name: the name is localized when it is DRAWN, so
## a save written in one language reads in another.
const HEADER_AREA: String = "area"


func _ready() -> void:
	add_to_group(GROUP)
	SaveSystem.header_provider = _save_header
	# ARRIVING IS THE ORDINARY WAY TO FIND SOMEWHERE, and it belongs here rather than in
	# `AreaRoot`: an area root is instanced per area and must stay generic, while this is one
	# node that outlives all of them. `area_entered` rather than `area_change_requested`,
	# because a transition that fails must not put a place on the map.
	Events.area_entered.connect(_on_area_entered)
	Events.game_started.connect(_on_game_started)
	Log.info(CATEGORY, "World map ready over %d mapped area(s)" % AreaDb.count())


func _exit_tree() -> void:
	if Events.area_entered.is_connected(_on_area_entered):
		Events.area_entered.disconnect(_on_area_entered)
	if Events.game_started.is_connected(_on_game_started):
		Events.game_started.disconnect(_on_game_started)
	# Only if it is still ours: a later map replaced it, and clearing that one would blank it.
	if SaveSystem.header_provider == Callable(_save_header):
		SaveSystem.header_provider = Callable()


## The localization key naming where a slot was saved, read out of `SaveSystem.slot_info`'s
## `"header"`, or "" when it cannot be named: a save from before the header had a place, or one
## made in an area with no `AreaDef`. Static, so a screen asks it with no map in the tree.
static func place_key(header: Dictionary) -> String:
	var def: AreaDef = AreaDb.area(StringName(DictRead.get_string(header, HEADER_AREA, "")))
	return "" if def == null else def.name_key


func _save_header() -> Dictionary:
	return {HEADER_AREA: String(Director.current_area_id)}


## The map, found by group rather than by path. Returns null before the tree is built, which
## callers must handle: a dev tool or a test may run without one.
static func find(from: Node) -> WorldMap:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as WorldMap


## The discovery flag for an area. Public and STATIC because it is the thing an AUTHOR writes
## into a dialogue effect or a gate, and a shape nobody should have to reconstruct from a
## header. `Standing.key` is the precedent.
static func key(area_id: StringName) -> StringName:
	return StringName(PREFIX + area_id)


func is_discovered(area_id: StringName) -> bool:
	return Flags.get_bool(key(area_id))


## Put a place on the map. Returns whether anything CHANGED, so a caller that arrives twice can
## tell that the second arrival did nothing.
##
## announce = false is what `known_from_start` uses: a new game must not open with a toast for
## every place the player is supposed to have grown up knowing.
func discover(area_id: StringName, announce: bool = true) -> bool:
	var def: AreaDef = AreaDb.area(area_id)
	if def == null:
		# AN UNMAPPED AREA IS NOT AN ERROR, it is a side room a game chose not to draw. Said at
		# info level rather than as a warning, because the boot rung counts warnings and a
		# template with no map at all is a legal state — but said, because "the .tres is
		# authored and the dot never appeared" must not be a silent outcome.
		Log.info(CATEGORY, "'%s' has no AreaDef, so it is not on the map" % area_id)
		return false
	if is_discovered(area_id):
		return false
	Flags.set_flag(key(area_id), true)
	Log.info(CATEGORY, "Discovered '%s'" % area_id)
	Events.area_discovered.emit(area_id)
	if announce:
		Events.notify_requested.emit(DISCOVERED_KEY, 3.0, {"area": tr(def.name_key)})
	return true


## Every discovered area that is also ON the map, sorted. Derived from `Flags` rather than kept
## in a list — `flags.gd` says derive what can be derived, and a list would be a second truth
## that a save restoring only the flags would leave stale.
##
## Filtered through `AreaDb` on purpose: a flag naming an area whose .tres a game has since
## deleted must not become a dot with no name and no position.
func discovered_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for area_id: StringName in AreaDb.ids():
		if is_discovered(area_id):
			out.append(area_id)
	return out


## THE ONE WAY ANYTHING ASKS TO FAST TRAVEL, and it does exactly what an `AreaDoor` does: it
## emits `Events.area_change_requested` and stops. It does not load, does not fade and does not
## place the player. `Director` owns the sequence and the guard, and a travel point that ran its
## own transition would be a second, unguarded path — which is how two doors firing at once
## leaves two areas in the tree.
##
## The four refusals are refusals rather than silence, and each is logged, because a fast travel
## that does nothing is maddening to debug.
func travel_to(area_id: StringName) -> bool:
	var def: AreaDef = AreaDb.area(area_id)
	if def == null:
		Log.info(CATEGORY, "Cannot travel to '%s': it is not on the map" % area_id)
		return false
	if not is_discovered(area_id):
		Log.info(CATEGORY, "Cannot travel to '%s': it has not been found" % area_id)
		return false
	if area_id == Director.current_area_id:
		Log.info(CATEGORY, "Already in '%s'" % area_id)
		return false
	if Director.is_transitioning():
		Log.info(CATEGORY, "Cannot travel to '%s': already moving" % area_id)
		return false
	Log.info(CATEGORY, "Travelling to '%s' (spawn '%s')" % [area_id, def.arrival_spawn])
	Events.area_change_requested.emit(area_id, def.arrival_spawn)
	return true


func _on_area_entered(area_id: StringName) -> void:
	discover(area_id)


## Flags are already cleared when this fires, so this is what puts the starting place — and
## anywhere a game says is known by reputation — on a new game's map. Silently: a toast per
## known place on the first frame of a new game would be noise.
func _on_game_started() -> void:
	for area_id: StringName in AreaDb.ids():
		var def: AreaDef = AreaDb.area(area_id)
		if def != null and def.known_from_start:
			discover(area_id, false)
