class_name SymbolEncounter
extends Node
## A foe you can see in the field that opens a TURN-BASED battle when it touches the party (C5.1):
## the "symbol encounter" of Chrono Trigger, Octopath or Persona. Make it a child of an
## `ActionEnemy` (or any body with a `Combatant`), and name the `Encounter` it starts.
##
## WHICH FORMULA A FIGHT USES IS DECIDED BY WHAT THE AREA PLACES, not by a mode setting:
## - an `ActionEnemy` alone fights in real time (the hybrid, when the player's loadout has `atb`);
## - an `ActionEnemy` with this child starts a turn-based battle when it touches the party;
## - an `EncounterPoint` starts a turn-based battle when the player talks to it.
## So one area can hold all three, and a boss can be turn-based in a field that is not.
##
## IN PLAIN WORDS: when the nearest member of the party comes within `touch_radius` (checked each
## physics frame by `watch`), or the moment a party member's strike lands on it, it asks for its
## encounter once, through `Events.encounter_requested`, the same request an `EncounterPoint`
## makes. A strike that fells it outright ends it in the field instead. Then it waits for that
## battle to end:
## - WON: the body's hp drops to 0, so the `ActionEnemy` falls its own way (lingers, is removed,
##   is remembered if `remember_defeat`). The rewards are the encounter's, so give the field body
##   `experience` 0 and no `loot`, or the player is paid twice.
## - FLED or LOST: it ignores the party for `grace` seconds, so the fight does not start again
##   the moment the screen closes.
## A request nobody answers (no battle host, no party, an unknown id) is logged and also gives
## `grace`: it is never left waiting.
##
## A FOE THAT SHOULD NEVER SWING gets a brain with no `moves` and `chase_only` set: it then only
## chases, and the brain's problems accept the empty list. A foe with
## moves both swings in real time and starts the battle on touch, which is a game's choice.
##
## OWNS: when the touch happens, and what the body does when that battle ends.
## MUST NOT: build the battle (`BattleHost` does), or grant rewards (`Rewards` does).

const CATEGORY: StringName = &"combat"

## The encounter it starts, `encounter/<name>`.
@export var encounter_id: StringName = &""
## How close, in metres, a party member must come for the fight to start.
@export var touch_radius: float = 1.2
## Seconds of fight time it leaves the party alone after a flee, a loss or a refused request.
@export var grace: float = 3.0

var _grace_left: float = 0.0
var _waiting: bool = false
var _started: bool = false


func _ready() -> void:
	Events.combatant_damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	watch(delta)


## One frame of watching. Public so a test can step it without a physics frame.
func watch(delta: float) -> void:
	_grace_left = maxf(0.0, _grace_left - CombatClock.scaled(delta))
	if not _ready_to_challenge():
		return
	var body: Node3D = get_parent() as Node3D
	var nearest: Hurtbox = Hurtbox.nearest_hostile(body)
	if nearest != null and body.global_position.distance_to(nearest.global_position) <= touch_radius:
		_challenge()


## A strike from the party starts the battle too, the "first strike" of symbol encounters, so a
## follower with a field brain cannot quietly beat the foe in real time. The hit itself lands.
func _on_damaged(who: StringName, _by: StringName, _amount: int, _critical: bool) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine != null and who == mine.combatant_id and _ready_to_challenge():
		_challenge()


## Not already waiting, not in grace, named an encounter, and the body still stands.
func _ready_to_challenge() -> bool:
	var body: Node3D = get_parent() as Node3D
	if _waiting or _grace_left > 0.0 or encounter_id == &"" or body == null:
		return false
	var vitals: Vitals = Vitals.of(body)
	return vitals == null or not vitals.is_defeated()


## True while the battle it asked for is open.
func waiting() -> bool:
	return _waiting


func problems(context: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if encounter_id == &"":
		found.append("%s names no encounter" % context)
	if touch_radius <= 0.0:
		found.append("%s has a touch radius of %s" % [context, touch_radius])
	if grace < 0.0:
		found.append("%s has a negative grace" % context)
	return found


## Asks for the encounter once. `Battle` announces `battle_started` while the request is still
## being answered, so by the time `emit` returns we know whether a fight opened.
func _challenge() -> void:
	_waiting = true
	_started = false
	Events.battle_started.connect(_on_battle_started, CONNECT_ONE_SHOT)
	Events.battle_ended.connect(_on_battle_ended)
	Events.encounter_requested.emit(encounter_id)
	if _started:
		return
	Log.warn(CATEGORY, "%s asked for '%s' and no battle opened" % [get_parent().name, encounter_id])
	if Events.battle_started.is_connected(_on_battle_started):
		Events.battle_started.disconnect(_on_battle_started)
	_stop_waiting()


func _on_battle_started(_enemy_ids: Array[StringName]) -> void:
	_started = true


func _on_battle_ended(outcome: int) -> void:
	if outcome == Battle.Outcome.WON:
		var vitals: Vitals = Vitals.of(get_parent())
		if vitals != null:
			vitals.set_to(&"hp", 0)
		_waiting = false
		Events.battle_ended.disconnect(_on_battle_ended)
		return
	_stop_waiting()


func _stop_waiting() -> void:
	_waiting = false
	_grace_left = grace
	if Events.battle_ended.is_connected(_on_battle_ended):
		Events.battle_ended.disconnect(_on_battle_ended)


func _exit_tree() -> void:
	if Events.combatant_damaged.is_connected(_on_damaged):
		Events.combatant_damaged.disconnect(_on_damaged)
	if Events.battle_ended.is_connected(_on_battle_ended):
		Events.battle_ended.disconnect(_on_battle_ended)
	if Events.battle_started.is_connected(_on_battle_started):
		Events.battle_started.disconnect(_on_battle_started)
