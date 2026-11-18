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
## OPENINGS AND ONE BLOW (C10.21). A party strike that lands on its back opens the battle with
## the party first: every foe loses its first turn (`OFF_GUARD`). The foe touching a member from
## behind gives the foes the first round the same way. A strike that fells it outright gives the
## encounter's experience and loot in the field (`ActionHost.reward`), once, instead of a battle.
##
## A FOE THAT SHOULD NEVER SWING gets a brain with no `moves` and `chase_only` set: it then only
## chases, and the brain's problems accept the empty list. A foe with
## moves both swings in real time and starts the battle on touch, which is a game's choice.
##
## OWNS: when the touch happens, and what the body does when that battle ends.
## MUST NOT: build the battle (`BattleHost` does), or grant rewards (`Rewards` does).

const CATEGORY: StringName = &"combat"
## Who acts first when the battle opens (C10.21).
enum Opening { EVEN, PARTY_FIRST, FOES_FIRST }

## The encounter it starts, `encounter/<name>`.
@export var encounter_id: StringName = &""
## How close, in metres, a party member must come for the fight to start.
@export var touch_radius: float = 1.2
## Seconds of fight time it leaves the party alone after a flee, a loss or a refused request.
@export var grace: float = 3.0

var _grace_left: float = 0.0
var _opening: Opening = Opening.EVEN
var _paid: bool = false
static var _off_guard: StatusEffect
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
		# Come on from behind the member, the foes have the first round.
		var member: Node3D = nearest.get_parent() as Node3D
		_challenge(Opening.FOES_FIRST if member != null and behind(member, body) else Opening.EVEN)


## A strike from the party starts the battle too, the "first strike" of symbol encounters, so a
## follower with a field brain cannot quietly beat the foe in real time. The hit itself lands.
func _on_damaged(who: StringName, by: StringName, _amount: int, _critical: bool) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id:
		return
	if _ready_to_challenge():
		var striker: Combatant = Combatant.find(get_tree(), by)
		var from: Node3D = striker.get_parent() as Node3D if striker != null else null
		_challenge(Opening.PARTY_FIRST if from != null and behind(get_parent() as Node3D, from) else Opening.EVEN)
	elif not _waiting and not _paid and Vitals.of(get_parent()) != null and Vitals.of(get_parent()).is_defeated():
		_felled()


## True when `other` stands behind `body`: on the far side of the way `body` faces (C10.21).
static func behind(body: Node3D, other: Node3D) -> bool:
	var to: Vector3 = other.global_position - body.global_position
	return Vector3(to.x, 0.0, to.z).dot(BarrageRun.facing_of(body)) < 0.0


# Felled in one blow, before any battle: the encounter's rewards are given here, once (C10.21).
func _felled() -> void:
	_paid = true
	var encounter: Encounter = EncounterDb.encounter(encounter_id)
	if encounter == null:
		return
	var loot: Array[StringName] = encounter.loot.duplicate()
	loot.append_array(LootRoll.roll(encounter.loot_table, RandomNumberGenerator.new()))
	var player: Node3D = Director.player
	ActionHost.reward(encounter.experience, loot, player, FieldParty.lead(player) if player != null else null)


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
func _challenge(opening: Opening = Opening.EVEN) -> void:
	_opening = opening
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
	# The side caught off guard loses its first turn (C10.21).
	var battle: Battle = Battle.running
	if battle == null or _opening == Opening.EVEN:
		return
	for fighter: Combatant in (battle.enemies if _opening == Opening.PARTY_FIRST else battle.party):
		var statuses: StatusSet = StatusSet.of(fighter.get_parent()) if is_instance_valid(fighter) else null
		if statuses != null:
			statuses.apply(off_guard())


## The status a side caught off guard holds: its first turn lost.
static func off_guard() -> StatusEffect:
	if _off_guard == null:
		_off_guard = StatusEffect.new()
		_off_guard.id = &"status/off_guard"
		_off_guard.name_key = "ui.combat_status.off_guard"
		_off_guard.unit = StatusEffect.Unit.TURNS
		_off_guard.duration = 1.0
		_off_guard.blocks = [StatusEffect.Block.SKIP_TURN]
	return _off_guard


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
