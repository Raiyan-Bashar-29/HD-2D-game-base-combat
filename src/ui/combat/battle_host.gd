class_name BattleHost
extends Node
## Answers `Events.encounter_requested`: builds the battle and opens `BattleScreen` over the
## field. It sits beside `ScreenKeys` under the UI layer, and is the only listener of that signal.
##
## THE ROSTER IS EVERY FIGHTER THAT COULD JOIN: `roster` if set on the node, else the
## `PartyRoster` file `[combat] party/roster` names, loaded on ready. `Party` picks the active
## line-up from it and builds each member at its level. ITEM commands spend from the player's
## `Inventory`, and loot goes there too. An empty line-up, or an unknown encounter, is refused
## with a log line and no screen.
##
## MUSIC: an encounter with its own `music` plays it when the screen opens, and the area's music
## comes back when the screen closes. An encounter without music leaves the field's playing.
##
## IN PLAIN WORDS: when something in the field says "start fight X", this node builds the fight
## and opens the battle menu on top of the frozen world.
##
## OWNS: turning a request into an open battle screen, and the fight's music.
## MUST NOT: decide what a command does, what winning gives, or change areas.

const CATEGORY: StringName = &"combat"
const ROSTER_SETTING: String = "combat/party/roster"

@export var roster: Array[CombatantDef] = []

var _seed: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_seed.randomize()
	if roster.is_empty():
		roster = roster_from(str(ProjectSettings.get_setting(ROSTER_SETTING, "")))
	Events.encounter_requested.connect(open_encounter)


func _exit_tree() -> void:
	if Events.encounter_requested.is_connected(open_encounter):
		Events.encounter_requested.disconnect(open_encounter)


## The members of the `PartyRoster` at `path`, or none when there is no such file: the
## stripped template's case, which is not an error.
static func roster_from(path: String) -> Array[CombatantDef]:
	var members: Array[CombatantDef] = []
	if path == "" or not ResourceLoader.exists(path):
		return members
	var found: PartyRoster = ResourceLoader.load(path) as PartyRoster
	if found != null:
		members = found.members
	return members


## Builds `encounter_id` against the party and opens the screen. False, with nothing opened,
## when there is no such encounter, no party, or no stack to open it on.
func open_encounter(encounter_id: StringName) -> bool:
	var encounter: Encounter = EncounterDb.encounter(encounter_id)
	var stack: UiRoot = UiRoot.find(self)
	var party: Array[CombatantDef] = []
	for def: CombatantDef in Party.active(roster):
		party.append(Party.at_level(def))
	if encounter == null or party.is_empty() or stack == null:
		Log.warn(CATEGORY, "cannot start '%s': encounter %s, party of %d, stack %s" % [
				encounter_id, encounter != null, party.size(), stack != null])
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed.randi()
	# The fighters live under this node, which is in the tree: a fighter's sheet and pools are
	# set up in its `_ready`, and a screen not yet opened has not had one.
	var battle: Battle = BattleSetup.build(encounter, party, self, rng)
	battle.inventory = Inventory.of(Director.player)
	var screen: BattleScreen = BattleScreen.for_battle(battle)
	if encounter.music != null:
		# Swap to the fight's music now, and put the area's back when the screen goes away.
		Audio.play_music(encounter.music)
		screen.tree_exited.connect(_restore_music)
	return stack.open(screen)


## The music of the area the player is in, found by walking down from `root`. Null when no
## area is loaded (a test, or the title screen).
static func area_music(root: Node) -> AudioStream:
	var area: AreaRoot = _find_area(root)
	return area.music if area != null else null


func _restore_music() -> void:
	# Fades back to the field's track. A null stream (no area music) fades to silence.
	Audio.play_music(area_music(get_tree().root) if is_inside_tree() else null)


## Areas sit a few levels under the root (GameRoot / WorldRoot / area), so a breadth-first walk
## finds the live one quickly. The first AreaRoot found is the live one: only one is loaded.
static func _find_area(root: Node) -> AreaRoot:
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is AreaRoot:
			return node as AreaRoot
		queue.append_array(node.get_children())
	return null
