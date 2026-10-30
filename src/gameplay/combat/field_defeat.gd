class_name FieldDefeat
extends Node
## Carries out a `DefeatRule` when its body's fighter falls in the field (C3.8). `ActionHost`
## puts one under the player.
##
## IN PLAIN WORDS: when this body's `Combatant` is defeated, the body is held still (the
## `&"defeated"` input lock) and a clock starts. After `rule.delay` seconds, by the rule, the
## fighter gets up where they are, or the area is entered again, or the latest save is loaded.
## For the last two they get up, with part of their hp, only once the area has been entered,
## so the enemies that felled them are gone first. Then the hold is let go.
##
## The clock runs in `tick`, which `_physics_process` calls, so a test can step it by hand.
##
## OWNS: the wait on the ground and carrying out the rule.
## MUST NOT: choose the rule (the loadout does) or decide what an enemy's defeat means.

const LOCK: StringName = &"defeated"

var rule: DefeatRule = DefeatRule.new()
## The kind last carried out, for the log and for tests; -1 before any.
var applied: int = -1

var _waiting: float = -1.0


func _ready() -> void:
	Events.combatant_defeated.connect(_on_defeated)


func _physics_process(delta: float) -> void:
	tick(delta)


## Counts down the time on the ground, and carries out the rule when it runs out. It counts
## real time, not `CombatClock` time (C4.1): with the fight stopped, a fallen player would
## otherwise lie there forever.
func tick(delta: float) -> void:
	if _waiting < 0.0:
		return
	_waiting -= delta
	if _waiting <= 0.0:
		_waiting = -1.0
		_carry_out()


func _on_defeated(who: StringName) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id or _waiting >= 0.0:
		return
	_waiting = maxf(0.0, rule.delay)
	var player: PlayerController = get_parent() as PlayerController
	if player != null:
		player.lock_input(LOCK)


func _carry_out() -> void:
	applied = rule.kind
	Log.info("combat", "The player fell: %s" % DefeatRule.Kind.keys()[rule.kind])
	if rule.kind == DefeatRule.Kind.REVIVE_IN_PLACE or Director.current_area_id == &"":
		_get_up()
		return
	# Get up only once the area is entered again. Getting up first would leave the player
	# standing among the same enemies for the whole fade, and they would fall again.
	Events.area_entered.connect(_on_back, CONNECT_ONE_SHOT)
	var slot: int = SaveSystem.latest_slot() if rule.kind == DefeatRule.Kind.RELOAD_SAVE else -1
	if slot < 0 or SaveSystem.load_from_slot(slot) != OK:
		Director.reload_current_area()


func _on_back(_area_id: StringName) -> void:
	_get_up()


## Stands the fighter up with `revive_fraction` of their hp, if they are still down (a loaded
## save may already have them standing), and lets go of the body.
func _get_up() -> void:
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals != null and vitals.is_defeated():
		vitals.revive(roundi(vitals.maximum(vitals.defeat_pool) * rule.revive_fraction))
	var player: PlayerController = get_parent() as PlayerController
	if player != null:
		player.release_input(LOCK)
