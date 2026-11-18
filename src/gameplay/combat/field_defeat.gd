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
## AND EVERY AREA ENTRY STANDS A FALLEN FIGHTER UP (C5.2), unless they are still lying out their
## `delay`. That is how a reload or a re-entry ends the wait, and it is also the safety net for a
## save written while the player lay at 0 hp (by a build before `CombatSaveGuard`): such a load
## fires no defeat edge, so without this nothing would ever get them up.
##
## A PETRIFIED PLAYER (C8.18) is treated as fallen: a held status that `counts_as_fallen` starts the
## same wait and rule, and getting up cures it.
##
## A FALL INSIDE A TURN-BASED BATTLE IS NOT A FIELD FALL (C10.2). The lead's battle fighter shares
## the field body's id, so its defeat is heard here, and is ignored while it is in `Battle.running`. A lost
## battle runs its encounter's own rule through `after_battle`. And with the rule's `switch_first`,
## a lead who falls while a party member stands hands the body over (`FieldParty.switch`) on the
## next tick instead of waiting out the rule.
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
	Events.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	tick(delta)


## Counts down the time on the ground, and carries out the rule when it runs out. It counts
## real time, not `CombatClock` time (C4.1): with the fight stopped, a fallen player would
## otherwise lie there forever.
func tick(delta: float) -> void:
	if _waiting < 0.0:
		var statuses: StatusSet = StatusSet.of(get_parent())
		if statuses != null and statuses.fallen() and not Vitals.of(get_parent()).is_defeated():
			_lie_down()
		return
	if rule.switch_first and get_parent() is Node3D and FieldParty.switch(get_parent() as Node3D):
		_waiting = -1.0
		_release()
		return
	_waiting -= delta
	if _waiting <= 0.0:
		_waiting = -1.0
		_carry_out()


func _on_defeated(who: StringName) -> void:
	var mine: Combatant = Combatant.of(get_parent())
	if mine == null or who != mine.combatant_id or _waiting >= 0.0 or _in_battle(who):
		return
	_lie_down()


func _lie_down() -> void:
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
	# Get up only once the area is entered again (`_on_area_entered`). Getting up first would
	# leave the player standing among the same enemies for the whole fade, and they would fall
	# again.
	_leave(rule.kind)


## A lost turn-based battle's `rule` (C10.2), once its screen has closed and its members are up:
## in place, play goes on; otherwise the area is entered again, or the latest save loaded, as for
## a fall in the field. `player`'s own `FieldDefeat`, when it has one, records it in `applied`.
static func after_battle(battle_rule: DefeatRule, player: Node) -> void:
	for child: Node in player.get_children() if player != null else []:
		if child is FieldDefeat:
			(child as FieldDefeat).applied = battle_rule.kind
	Log.info("combat", "The party lost a battle: %s" % DefeatRule.Kind.keys()[battle_rule.kind])
	if battle_rule.kind != DefeatRule.Kind.REVIVE_IN_PLACE and Director.current_area_id != &"":
		_leave(battle_rule.kind)


# True when `who` is fighting in the running turn-based battle, so the fall is that battle's.
static func _in_battle(who: StringName) -> bool:
	if Battle.running == null:
		return false
	for fighter: Combatant in Battle.running.party + Battle.running.reserve:
		if is_instance_valid(fighter) and fighter.combatant_id == who:
			return true
	return false


# The area entered again, or the latest save loaded; with no save, the area entered again.
static func _leave(kind: DefeatRule.Kind) -> void:
	var slot: int = SaveSystem.latest_slot() if kind == DefeatRule.Kind.RELOAD_SAVE else -1
	if slot < 0 or SaveSystem.load_from_slot(slot) != OK:
		Director.reload_current_area()


func _on_area_entered(_area_id: StringName) -> void:
	if _waiting < 0.0:
		_get_up()


## Stands the fighter up with `revive_fraction` of their hp, if they are still down (a loaded
## save may already have them standing), and lets go of the body.
func _get_up() -> void:
	var vitals: Vitals = Vitals.of(get_parent())
	if vitals != null and vitals.is_defeated():
		vitals.revive(roundi(vitals.maximum(vitals.defeat_pool) * rule.revive_fraction))
	var statuses: StatusSet = StatusSet.of(get_parent())
	for effect: StatusEffect in statuses.held() if statuses != null else []:
		if effect.counts_as_fallen:
			statuses.cure(effect.id)
	_release()


func _release() -> void:
	var player: PlayerController = get_parent() as PlayerController
	if player != null:
		player.release_input(LOCK)
