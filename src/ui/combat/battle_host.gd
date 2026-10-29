class_name BattleHost
extends Node
## Answers `Events.encounter_requested`: builds the battle and opens `BattleScreen` over the
## field. It sits beside `ScreenKeys` under the UI layer, and is the only listener of that signal.
##
## THE PARTY IS A LIST OF DEFINITIONS here until C2.8's roster replaces it, so a game can fight
## today by filling `party` in the scene. An empty party, or an unknown encounter, is refused
## with a log line and no screen.
##
## OWNS: turning a request into an open battle screen.
## MUST NOT: decide what a command does, what winning gives, or change areas.

const CATEGORY: StringName = &"combat"

@export var party: Array[CombatantDef] = []

var _seed: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_seed.randomize()
	Events.encounter_requested.connect(open_encounter)


func _exit_tree() -> void:
	if Events.encounter_requested.is_connected(open_encounter):
		Events.encounter_requested.disconnect(open_encounter)


## Builds `encounter_id` against the party and opens the screen. False, with nothing opened,
## when there is no such encounter, no party, or no stack to open it on.
func open_encounter(encounter_id: StringName) -> bool:
	var encounter: Encounter = EncounterDb.encounter(encounter_id)
	var stack: UiRoot = UiRoot.find(self)
	if encounter == null or party.is_empty() or stack == null:
		Log.warn(CATEGORY, "cannot start '%s': encounter %s, party of %d, stack %s" % [
				encounter_id, encounter != null, party.size(), stack != null])
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed.randi()
	# The fighters live under this node, which is in the tree: a fighter's sheet and pools are
	# set up in its `_ready`, and a screen not yet opened has not had one.
	return stack.open(BattleScreen.for_battle(BattleSetup.build(encounter, party, self, rng)))
